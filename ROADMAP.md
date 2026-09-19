# GDAL7 Roadmap

A staged plan for making GDAL7 powerful and efficient, grounded in a read of the
code at commit `6297d1b`, plus the opportunities the original design did not take.

References below are `file:line` against that commit.

---

## 1. Where the package actually is

The rationale (`data-raw/GDAL7-rationale.md`) proposes a generator that parses GDAL's
`swig/include/*.i` files and emits cpp11 bindings plus S7 classes, so that GDAL7
tracks GDAL by regeneration rather than by hand. The parser is real and works
(`data-raw/parse_swig.R`, ~736 lines, extracts classes, inheritance, methods,
parameters, defaults, `%apply` typemaps, `%rename`, `%constant`).

But the shipped package is mostly not generated:

| Area | Generated | Hand written |
|---|---|---|
| R | `aaa-class-majorobject.R`, `aab-class-dataset.R` | `driver.R`, `raster-info.R`, `z-multidim.R`, `gdal-open.R`, `zzz.R` |
| src | `GDAL7_majorobject.cpp`, `GDAL7_dataset.cpp` | `GDAL7_open.cpp`, `GDAL7_info.cpp`, `GDAL7_driver.cpp`, `GDAL7_multidim.cpp` |
| NAMESPACE | no (header says "Auto-generated"; nothing generates it) | yes |

And the two generated R files have since been hand-edited, while
`data-raw/orchestrate.R:23-25` still deletes and regenerates them. Re-running the
pipeline today would silently revert working code. Three of the hand-written files
exist specifically to override generated methods that were wrong
(`R/raster-info.R:66`, `R/driver.R:26`).

Functionally, the honest summary is: **GDAL7 can describe a dataset but cannot read
one value out of it.** There is no `RasterIO`, no geotransform, no OGR beyond
`get_layer_count()`, no multidimensional read, no creation, no VSI, no SRS class.

That is fine for a proof of concept. It also means the sequencing decisions below
are still cheap to make.

---

## 2. The one architectural problem to fix first

The parser reads SWIG `.i` files, which describe GDAL's **C++ shadow API**
(`Dataset::GetProjection()`). The generator emits calls to GDAL's **C API**
(`GDALGetProjectionRef()`). Nothing connects the two automatically. The connection
is a hand-maintained lookup table of about 33 entries at
`data-raw/generate_cpp11.R:411-463`, with a `paste0("GDAL", base_name)` guess as the
fallback (`:462`).

Any GDAL method not in that table generates a call to a function that does not
exist, which is why there is a 35-entry skip list at
`data-raw/generate_cpp11.R:473-509`, duplicated at `data-raw/orchestrate.R:41-53`.
The skip list is not working around parser limitations; it is working around the
missing mapping. So the central claim, "regenerate when GDAL updates", is not yet
true, and it will not become true by adding more table entries.

**The mapping is already in the input data.** GDAL's `.i` files implement each
shadow method in a `%extend` block whose body is literally the C API call. The
parser already captures it: `method$body` is assigned at `data-raw/parse_swig.R:214`.
Neither generator ever reads `$body` (verified: no `$body` reference in
`generate_cpp11.R` or `generate_s7.R`).

Same story for constants: `%constant` directives are parsed into `result$constants`
at `data-raw/parse_swig.R:482` and never emitted. So `GDT_*`, `GA_*`, `GCI_*` are
absent, and `get_data_type()` (`R/raster-info.R:119`) hands back a bare integer with
nothing in the package to interpret it against.

Deriving the C call from the captured `%extend` body, rather than from a lookup
table, is the change that makes the rest of the generator thesis viable. It should
happen before the surface area grows.

---

## 3. Blocking defects

Ordered roughly by how much they cost.

### Cannot be installed from a clone

`.gitignore:14-15` excludes `src/cpp11.cpp` and `R/cpp11.R`. A fresh clone has no
registration code, so `remotes::install_github()` and `R CMD build` both fail. The
README works around this by telling the user to run `cpp11::cpp_register()` first
(`README.md:31`). This is the single largest adoption blocker: nobody can try the
package without reading the README and running a generator step by hand.

Commit the cpp11 output (it is generated but stable, and cpp11 packages normally
ship it), or add a `configure` step that produces it.

### No documentation, and print methods that never fire

Every file carries roxygen comments and `DESCRIPTION:14` sets `RoxygenNote: 7.3.3`,
but roxygen is never run, there is no `man/`, and `NAMESPACE` is hand-maintained
despite its own "Auto-generated - do not edit by hand" header (`NAMESPACE:1`).

The visible consequence: `NAMESPACE` contains no `S3method()` entries at all, so the
`S7::method(print, ...)` definitions at `R/raster-info.R:227`, `R/driver.R:223`,
`R/z-multidim.R:200` and `:226` are dead code. You can see this in the committed
README output, where a band prints as the S7 default rather than via the method that
exists (`README.md:87-88`, `README.md:109-110`), and drivers and groups likewise.
Running roxygen would emit the `S3method(print, "GDAL7::GDALRasterBand")` lines that
make them dispatch.

`R/GDAL7-package.R:5` also has a malformed tag, `#' @useDynLibGDAL7, .registration =FALSE`,
which is both unparseable and contradicts `useDynLib(GDAL7, .registration = TRUE)`
in the hand-written NAMESPACE.

### R CMD check cannot pass

- `DESCRIPTION:8` declares `MIT + file LICENSE`; there is no LICENSE file. That is a
  check ERROR.
- `tests/testthat.R:12` calls `test_check("GDAL7")` but `tests/testthat/` does not
  exist. The only executable tests are the scripts in `inst/examples/`, which
  hardcode `/perm_storage/home/mdsumner/gdal/autotest/...` and reach the network.
- No `man/` (above).

### Not buildable off Linux

`src/Makevars` shells out to `gdal-config` with no `configure`, no `Makevars.win` or
`Makevars.ucrt`, and no pkg-config fallback. Windows and most macOS setups will not
build.

### No CI

There is no `.github/`. For a package whose entire job is compiling against a fast
moving C++ library across three platforms, CI is not polish, it is the thing that
tells you the generator still works.

---

## 4. Memory and lifetime

This is the category that decides whether GDAL7 can ever be trusted as a foundation
for other packages, and it is currently the weakest.

**Datasets leak.** `src/GDAL7_open.cpp:31` wraps the handle in
`cpp11::external_pointer<GDALDatasetH>`. The default deleter `delete`s the heap box
holding the handle; it never calls `GDALClose`. Unless the user calls `gdal_close()`
by hand, the dataset, its file handle, and any `/vsicurl/` connection state stay
open for the life of the session.

**Child handles dangle.** Bands (`src/GDAL7_info.cpp:57`), drivers
(`src/GDAL7_driver.cpp:68`), groups and arrays all hold raw handles with no
reference to the dataset they came from. After `gdal_close(ds)`, a retained band is a
use after free. `README.md:83` documents this as a caveat to the user
("do not use this after ds has been gdal_close(ds)") rather than preventing it. An R
package that can segfault from ordinary use will not pass CRAN and will not be
adopted as a base layer.

The fix is mechanical and should be done once, in one place: allocate every handle
with `R_MakeExternalPtr(ptr, tag, prot)` where `prot` is the parent's external
pointer, so the parent cannot be collected while a child lives; register a finalizer
that performs the type-correct release; and have `gdal_close()` flip a shared
"closed" flag that every accessor checks, so a stale band errors instead of crashing.

**Multidim handles leak outright.** `GDAL7_group_release`
(`src/GDAL7_multidim.cpp:140`) and `GDAL7_mdarray_release` (`:252`) are written and
registered, but they are not exported in `NAMESPACE` and nothing in
`R/z-multidim.R` calls them. Every `get_root_group()`, `open_group()` and
`open_mdarray()` leaks a GDAL reference. The comment at
`src/GDAL7_multidim.cpp:25` even says the group needs releasing.

**CSL helper leaks on throw.** `list_to_csl` (`src/GDAL7_majorobject.cpp:31`,
duplicated at `src/GDAL7_dataset.cpp:31`) accumulates a `char**` and leaks it if
`cpp11::as_cpp<std::string>` throws. Both helpers are emitted once per generated
translation unit by `data-raw/generate_cpp11.R:205-225`; today they are identical, so
the `inline` keyword saves it, but the moment one generated copy diverges it becomes
an ODR violation. Use `CPLStringList` (RAII) from a single shared header under
`inst/include/`.

---

## 5. Correctness defects

*Status: items 1 through 8 are closed as of Stage 1.* Item 1 was fixed in the
tree during Stage 0 and at its source in Stage 1: `data-raw/generate_s7.R` was
naming every overload's binding after the first overload, so regenerating would
have put the wrong call back. Items 2, 4, 5, 6 and 8 are covered by
`tests/testthat/test-errors.R`; item 3 by the `gdal_dsn()` gate added in Stage 0;
item 7 by the explicit generic formals added in Stage 0.


1. `R/aaa-class-majorobject.R:131` - the `set_metadata_2` method calls
   `GDAL7_majorobject_set_metadata()`, the list variant, instead of
   `GDAL7_majorobject_set_metadata_2()`. The C++ function at
   `src/GDAL7_majorobject.cpp:99` takes a `cpp11::list`, so passing a character
   string cannot work. Note `data-raw/generate_s7.R:199` would have generated the
   correct name; this is drift from a hand edit.

2. `src/GDAL7_multidim.cpp:191` - `writable::list result(count)` allocates `count`
   slots, then `:203-204` `push_back` two more. The returned list has length
   `count + 2` with `count` leading NULLs. `get_dimensions()` (`R/z-multidim.R:176`)
   only indexes by name, so it looks fine from R, but the C level return is
   malformed. Should be `writable::list result;` or a fixed size 2.

3. `R/gdal-open.R:28` - `normalizePath()` is applied to every path, including
   connection strings such as `WMTS:https://...`, `NETCDF:"file.nc":var` and
   `/vsicurl/https://...`. On Linux a non-existent path passes through unchanged so
   this is invisible today; on Windows `normalizePath` rewrites separators to
   backslashes and will corrupt every `/vsi*/` and URL-bearing DSN. Gate on
   `file.exists()`, or drop it entirely and let GDAL resolve the string.

4. Stale error text. `stop("... failed: %s", CPLGetLastErrorMsg())` appears at
   `src/GDAL7_dataset.cpp:105` and `src/GDAL7_majorobject.cpp:105`, `:118`, `:134`
   with no preceding `CPLErrorReset()`, so an unrelated earlier error can be
   reported as the cause. More broadly there is no `CPLPushErrorHandler` anywhere, so
   GDAL warnings go to stderr and never reach R's condition system: they cannot be
   caught, suppressed, or tested against.

5. Missing versus empty is conflated. Every `const char*` getter returns `""` for
   NULL (`src/GDAL7_majorobject.cpp:47`, `src/GDAL7_dataset.cpp:67`, and so on), so
   `get_metadata_item()` cannot distinguish "not set" from "set to empty string".
   `NA_character_` is the right answer for absent.

6. `get_metadata_dict` and `get_metadata_list` are byte-identical implementations
   (`src/GDAL7_majorobject.cpp:71` and `:85`). SWIG's `GetMetadata_Dict` is meant to
   return a dict; both R methods return the same `KEY=VALUE` character vector.

7. Defaults from SWIG are parsed and documented but not applied. The generator
   records `p$default` and writes it into the roxygen `@param`
   (`data-raw/generate_s7.R:156`) but builds the R signature without it (`:210-227`).
   So `get_metadata_item(ds, "AREA_OR_POINT", "")` requires the domain argument that
   SWIG declares as optional, as the README example shows (`README.md:66`).

8. Encoding. ~~`std::string(s)` on a cpp11 string yields the native encoding.~~
   *Corrected:* this claim was wrong, and reading cpp11 0.4.7 settles it. Inbound,
   `as_cpp<std::string>` and `r_string::operator std::string()` both go through
   `Rf_translateCharUTF8` (`cpp11/as.hpp:188`, `cpp11/r_string.hpp:29`). Outbound,
   every string cpp11 builds is marked `CE_UTF8` (`cpp11/r_string.hpp:18-20`). So
   the boundary was already UTF-8 in both directions. There is now a round-trip
   test for it (`tests/testthat/test-errors.R`) so the guarantee is checked rather
   than assumed.

---

## 6. Efficiency

`gdal_drivers()` (`R/driver.R:164-186`) loops in R and makes 7 `.Call`s per driver;
on a typical 204-driver build that is about 1400 round trips to produce one small
data frame. It should be one C++ call returning the whole table. This is the
representative case, not an isolated one: the current design puts one `.Call` behind
every single scalar accessor.

The general principle worth adopting early, because it shapes the API: **batch at the
boundary.** A `gdal_info(dsn)` that returns size, band count, per band type, block
size, nodata, scale/offset, colour interpretation, geotransform, SRS and overview
levels in a single call is what makes interactive use over `/vsicurl/` feel
immediate. Per-accessor generics can stay, layered on top, for the cases that need
them.

Two related items already in reach and currently skipped:

- `GetThreadSafeDataset` / `IsThreadSafe` (GDAL 3.10) are in the skip list
  (`data-raw/orchestrate.R:45`). A thread-safe dataset handle is one of the more
  interesting things an R binding can expose, since it lets GDAL parallelise reads
  internally without R-level threading.
- `GDALRasterIOEx` with `GDALRasterIOExtraArg` gives overview-aware reads: read an
  arbitrary window at an arbitrary output size with a chosen resampling algorithm,
  including floating point windows. That single primitive is what makes huge remote
  rasters usable interactively. It is worth binding *before* plain `ReadRaster`, not
  after.

---

## 7. Opportunities the original design did not take

These are the items with the highest leverage, and none of them appear in the
five-phase scope at `data-raw/GDAL7-rationale.md:129-144`.

### 7.1 Arrow is the vector strategy, and it reorders the phases

The rationale puts vector at Phase 2 as "OGRLayer, OGRFeature, OGRGeometry", meaning
a class-by-class binding of feature and geometry objects. GDAL 3.6 added a
column-oriented read API (RFC 86): `OGR_L_GetArrowStream` fills an `ArrowArrayStream`
with whole record batches, and `OGR_L_WriteArrowBatch` covers the write direction.

Binding that one function plus nanoarrow gives whole-layer reads into a data frame
with WKB geometry, at C speed, with essentially no per-feature binding surface, and
it composes with the arrow and duckdb ecosystems for free. The `OLCFastGetArrowStream`
layer capability tells you when the driver has a native fast path.

The consequence for sequencing: vector reading becomes *cheaper* than raster I/O,
not more expensive. Phase 2 as originally scoped is largely unnecessary for reading.
OGRFeature and OGRGeometry classes become an optional convenience layer rather than
a prerequisite.

### 7.2 Bind GDAL's own algorithm registry instead of hand-wrapping utilities

GDAL 3.11 introduced the unified `gdal` command line interface, and **GDAL 3.12
added a C API for it** in `gdalalgorithm.h`: `GDALGetGlobalAlgorithmRegistry()`,
`GDALAlgorithmRegistryInstantiateAlgFromPath()`, `GDALAlgorithmGetArg()`,
`GDALAlgorithmArgSetAsString()` / `SetAsInteger()` / `SetAsDouble()` /
`SetAsDoubleList()`, `GDALAlgorithmRun()` with a progress callback,
`GDALAlgorithmFinalize()`, and `GDALAlgorithmArgGetAsDatasetValue()` /
`GDALArgDatasetValueGetDatasetRef()` to pull out an in-memory result.

This is much closer to the package's own thesis than the SWIG parser is. Instead of
hand-binding warp, translate, vector translate and the pipeline commands one at a
time, you instantiate an algorithm by path and set arguments by name. When GDAL adds
a command or an argument, GDAL7 gets it without a code change. It also gives raster
and vector pipelines, which have no equivalent in any existing R binding.

The rationale's Phase 5 ("Warp, Translate, VRT, VSI") should be re-scoped around
this. It is arguably the single most distinctive thing GDAL7 could offer.

Caveat worth checking against the target GDAL: the C API landed in 3.12, and
`DESCRIPTION:16` currently says `GDAL (>= 3.0.0)`, so this needs version guards
(see 7.4). Current stable is 3.13.3.

### 7.3 Use the `%extend` bodies, and emit the constants

Covered in section 2. Both are already parsed and thrown away. This is the cheapest
structural improvement available.

### 7.4 Version guards instead of an all-or-nothing skip list

Today a method that needs GDAL 3.9 is deleted from the build for everyone
(`data-raw/generate_cpp11.R:474-508` lists the version reasons in comments). Wrapping
generated bindings in `#if GDAL_VERSION_NUM >= ...` and exposing a
`gdal7_capabilities()` table lets one source tree serve a range of GDAL versions and
degrade honestly. The generator already knows enough to emit the guards; the version
notes are sitting in those comments.

Raising the declared floor does most of this work without any guards at all. The
floor is now GDAL 3.10 (`DESCRIPTION`), which is above every version named in those
skip comments: `ClearStatistics` (3.2), `GetFieldDomainNames` (3.3), the
relationship methods (3.6), `MarkSuppressOnClose` and friends (3.9),
`GetThreadSafeDataset` (3.10). Eleven of the thirty-five skipped methods are gated
on nothing else, so the floor alone unblocks them.

Unblocked is not the same as done. Each still needs a C API mapping, which is
section 2's problem, so un-skipping them belongs to Stage 3 rather than being a
quick win now. What the floor removes is the *reason* they were excluded. Guards
remain worth having only for things above the floor, which today means the GDAL
3.12 algorithm registry in 7.2.

There is also no `gdal_version()` / `GDALVersionInfo()` binding at all, which every
binding needs and which the capability story depends on.

### 7.5 Vendor the API model and diff it in CI

`data-raw/orchestrate.R:8` hardcodes `swig_dir <- "~/gdal/swig/include"`, and nothing
records which GDAL version produced the checked-in generated code. Generation is not
reproducible today.

Vendor the `.i` files, or better, the extracted API model as JSON, under
`inst/api/` with a version stamp. Then add a CI job that regenerates and diffs. Two
things fall out: "GDAL 3.14 added 12 methods" becomes a reviewable pull request
instead of a mystery, and the claim that the checked-in code matches the generator
becomes continuously verified rather than aspirational. That verification is exactly
what would let another package depend on GDAL7.

### 7.6 Actually use S7 properties

*Status: done in Stage 3.* `%immutable` members are parsed, and the generator
emits each as an S7 property with a getter: `ds@raster_xsize`, `ds@raster_ysize`
and `ds@raster_count`, which is every member GDAL's Dataset declares. The
paragraph below is what the position was before that.

"Properties with getters/setters" is reason number one for choosing S7
(`data-raw/GDAL7-rationale.md:89`), and the rationale's own example at `:104-108`
shows `raster_xsize` as a property. Zero properties exist in the package; everything
is a generic, and `%immutable` is unparsed.

Moving the accessor half of the API to properties (`ds@xsize`, `ds@bands`,
`band@nodata`, `band@block`) reads better, matches the stated design, and cuts the
exported symbol count sharply. Which matters, because:

### 7.7 Namespace hygiene

`NAMESPACE` currently exports bare generics named `get_name`, `get_description`,
`get_offset`, `get_scale`, `get_dimensions`, `test_capability`, `flush_cache`,
`open_group`. For a package intended as a foundation that coexists with sf, terra
and stars, those names will collide. Properties absorb most of them; the remainder
want a prefix or a smaller verb vocabulary. Easier to change now than after anyone
depends on it.

### 7.8 Progress callbacks and interruptibility

Nothing binds `GDALProgressFunc`, and nothing calls `R_CheckUserInterrupt()`. A slow
`/vsicurl/` read or a warp currently cannot be interrupted and reports no progress.
Both are table stakes for interactive use, and the algorithm API in 7.2 takes a
progress callback directly.

### 7.9 Test fixtures that need neither network nor a personal path

*Status: done.* `tests/testthat/` runs entirely against fixtures that ship in
`inst/extdata`: `test.tif`, `overviews.tif`, `test.gpkg` and `multidim.zarr`. No
test touches the network or a path outside the installed package, which is what
made the cross-platform CI matrix possible.

`inst/examples/*.R`, the scripts this item was written about, still hardcode
`/perm_storage/home/mdsumner/gdal/autotest/...` and remote URLs. They are no
longer shipped: `.Rbuildignore` excludes them, so nobody installs a script that
can only work on one machine. They stay in the repository as a record of what the
prototype was driven by, and everything they exercise is covered hermetically by
the test suite.

---

## 8. Staged plan

Each stage has an exit criterion that can be checked, not just a list of work.

### Stage 0 - Installable and checkable

Ship `src/cpp11.cpp` and `R/cpp11.R`. Add LICENSE. Run roxygen and generate
NAMESPACE from it, fixing `R/GDAL7-package.R:5` (this alone makes the print methods
work). Create `tests/testthat/` with real tests. Add `configure` plus
`Makevars.win`/`Makevars.ucrt` with a pkg-config fallback. Add CI across Linux,
macOS and Windows. Retire `data-raw/fix_cpp11.R`: verified against cpp11 0.4.7
that `cpp_register()` output is already clean and the fixer is a no-op, so the
bug it worked around is fixed upstream.

*Exit:* `remotes::install_github("rgdal-dev/GDAL7")` works on a clean machine, and
`R CMD check --as-cran` is clean on three platforms in CI.

*Status: done.* `R CMD check --as-cran` is at 0 errors, 0 warnings locally
against GDAL 3.8.4 and R 4.3.3; the remaining notes are environmental (no
network for the CRAN and timestamp checks, and a compiler flag that comes from
the distribution's own `Makeconf`). See `NEWS.md` for what changed. Two things
found along the way that this document had not: the package did not compile
against GDAL 3.8 at all, because `src/GDAL7_driver.cpp` called
`GDALDriverHasOpenOption()`, which is not in the GDAL C API; and `fix_cpp11.R`
was a no-op against current cpp11, so the bug it worked around is fixed
upstream rather than needing a root cause.

### Stage 1 - Safe object lifetimes

One shared header under `inst/include/` with the handle wrapper: parent protection
via `R_MakeExternalPtr` `prot`, type-correct finalizers, a shared closed flag,
`CPLStringList` for CSL. Wire `GDALGroupRelease` and `GDALMDArrayRelease` in. Install
a `CPLPushErrorHandler` that routes GDAL errors and warnings into R conditions, with
`CPLErrorReset()` before each fallible call. Fix the defects in section 5.

*Exit:* a test that opens a dataset, takes a band, closes the dataset and then
touches the band gives an R error, not a crash. A loop opening and dropping datasets
shows flat file-handle count.

*Status: done.* `inst/include/gdal7.h` holds the whole mechanism: a `Handle`
carrying the raw GDAL handle, the kind of object it is, and a `shared_ptr` to
the `Owner` record of whatever must stay alive for it to be valid. Owners chain
to their parent, so a band keeps its dataset open and an array keeps its group
and its dataset open; closing any of them marks the chain dead and every
accessor below it raises an R error instead of reading freed memory. The
external pointer's tag records the kind, so a band passed where a dataset is
expected is refused rather than cast. Both exit tests are in
`tests/testthat/test-lifetime.R`, with 500 open-and-drop cycles showing a flat
descriptor count.

Two departures from the plan as written. The `prot` slot is not what provides
the protection: it holds the parent for the R-level object graph, but the
`shared_ptr` chain is what actually keeps the parent open, because it also
survives an explicit `gdal_close()` on the parent rather than only a garbage
collection. And GDAL errors are collected per call by a scoped handler
(`gdal7::ErrorScope`) rather than raised from inside the GDAL callback: a
condition raised there could longjmp out of GDAL C++ code, so the messages are
gathered, the call returns, and only then do they become an R error or R
warnings.

### Stage 2 - Raster I/O, the missing core

Geotransform in both directions, plus `GDALApplyGeoTransform` / `GDALInvGeoTransform`.
`GDALRasterIOEx` with `GDALRasterIOExtraArg` first, so window-plus-output-size reads
with resampling exist from the start. Overview introspection. A batched
`gdal_info(dsn)` per section 6. The `GDT_*` / `GCI_*` constants from 7.3 so returned
type codes mean something.

*Exit:* reading a window of a remote COG at a reduced output size is one call, and
returns the same numbers as `gdalinfo` / `gdal_translate` on the same window.

*Status: done.* `read_raster()` is `GDALRasterIOEx` with a floating point
window, an independent output size and a chosen resampling algorithm, so a
large window at a small output size is served from whichever overview level
fits and costs only that level's bytes. The exit criterion is a test: against
`inst/extdata/overviews.tif`, a 512x256 to 4x2 average read and an 8x8 to 2x2
average read both return exactly what `gdal_translate -r average` writes for
the same windows, and those numbers are in `tests/testthat/test-rasterio.R`
with the command that produced them.

On a dataset `read_raster()` takes several bands through
`GDALDatasetRasterIOEx`, which is one pass over the data rather than one per
band. `gdal_info()` is the batched summary section 6 asked for: driver, size,
projection, geotransform, files, metadata and a per-band data frame in a single
call. Geotransforms go both ways, `apply_geotransform()` and
`inv_geotransform()` are vectorised over whole coordinate vectors, overviews
can be counted, sized and opened, and `gdal_data_types()` and
`gdal_color_interpretations()` are read out of the running GDAL rather than
hard coded, so the integer codes elsewhere in the package can be looked up.

One thing found on the way, which the README had been showing all along:
`get_data_type_name()` on a multidimensional array returned "" for every plain
numeric array, because `GDALExtendedDataTypeGetName()` names only types the
format itself named. It now falls back to the ordinary GDAL type underneath.

### Stage 3 - Make the generator true

Derive the C call from the captured `%extend` body (section 2). Emit constants. Emit
version guards (7.4). Parse `%immutable` and emit S7 properties (7.6). Vendor the API
model and add the regenerate-and-diff CI job (7.5). Retire the skip lists, or reduce
them to genuinely hard cases with recorded reasons.

*Exit:* a clean regenerate reproduces the checked-in generated files byte for byte,
CI proves it on every commit, and the skip list is short enough to read.

*Status: done.* The C call now comes out of the `%extend` body
(`derive_c_call()` in `data-raw/parse_swig.R`), so the 33-entry lookup table at
`generate_cpp11.R:411-463` and the `paste0("GDAL", name)` guess beneath it are
both gone. With the mapping derived rather than guessed, the skip list stops
being a list: a method is generated when the generator can express it, and when
it cannot, the reason is written into the generated file. Fifteen Dataset
methods are left out, each with its reason, and the two duplicated 35-entry
skip lists are replaced by five names that are hand-written elsewhere in the
package.

Three things the derivation found that the lookup table had hidden.
`GetSpatialRef` was being generated and could never have worked: its SWIG body
clones the reference rather than making one call, and the R side returned an S7
class that does not exist. `AddBand` and `BuildOverviews` were being skipped for
"complex params" when the real cause was a parser bug, which dropped the
pointer off `char **options` and left the type reading as a single `char`. And
the R defaults for string-list parameters were being emitted as SWIG's `0`,
which would have reached the binding as a number where it wanted strings.

Version guards are per binding rather than per package. `GDAL7_dataset.cpp`
wraps a binding whose C function is newer than the oldest release the symbol
table covers in `#if GDAL_VERSION_NUM >= ...`, and the `#else` branch raises an
R error naming the release it needs. So the source tree compiles against GDAL
3.8 through 3.14 and says honestly what it cannot do, rather than failing to
link. `gdal7_capabilities()` reports the same thing at run time, and
`gdal_version()` says what GDAL7 is running against.

The versions themselves are read, not remembered: `data-raw/refresh_symbol_versions.R`
fetches GDAL's public headers at each release tag and records the first release
each symbol appears in, into `data-raw/gdal-symbol-versions.csv`. That table
also decides which of GDAL's 281 constants are emitted, and which get a guard.
It contradicted this document twice: `GDALDatasetMarkSuppressOnClose` is a GDAL
3.12 C function, not 3.9, and `GDALDatasetGetCloseReportsProgress` is 3.13.

`%immutable` members are parsed, and each becomes an S7 property with a getter,
which is the first use S7's properties have had in this package:
`ds@raster_xsize`, `ds@raster_ysize`, `ds@raster_count`. Reading one calls
GDAL, so it cannot go stale, and the three hand-written bindings that used to
answer the same question are gone.

The model is vendored at `inst/api/gdal-api.json` with the GDAL version it came
out of, so `data-raw/orchestrate.R` runs from a clone with no GDAL checkout.
`.github/workflows/regenerate.yaml` regenerates on every commit and fails if
anything moved.

### Stage 4 - Vector via Arrow

`OGR_L_GetArrowStream` plus nanoarrow. Layer listing, SQL execution, spatial and
attribute filters, `OLCFastGetArrowStream` capability reporting. `OGR_L_WriteArrowBatch`
for the write direction.

*Exit:* a GeoPackage layer reads to a data frame with WKB geometry in one call, and
round-trips.

*Status: done.* `read_vector()` is the one call, and `write_vector()` is the
other direction of the same path. The round trip is a test and a README line:
`identical(read_vector(path), read_vector(original))` after writing the second
from the first, values, field types, feature ids and WKB alike.

What 7.1 predicted held. The whole vector read surface is one C function,
`OGR_L_GetArrowStream`, plus a few accessors: no OGRFeature class, no
OGRGeometry class, no per-feature R work at any point. `src/GDAL7_vector.cpp`
is 395 lines, and that covers reading, filtering, SQL and the write direction
together; `src/GDAL7_rasterio.cpp` takes 352 for raster reading alone. Vector
did turn out cheaper per unit of API reached, as 7.1 said it would.

The stream is handed to R as an external pointer of class
`nanoarrow_array_stream`, which is the Arrow interchange contract, so
`arrow_stream()` composes with nanoarrow, arrow and duckdb without GDAL7
touching a value. `OLCFastGetArrowStream` is reported as the `fast_arrow`
column of `gdal_layers()`.

Two things that only showed up against a real driver. A layer allows one Arrow
stream at a time, so a stream has to be given back before the layer can be read
again; waiting for the garbage collector makes an innocent second read fail, so
`read_vector()` releases its stream and `release_arrow_stream()` is exported for
anyone taking one directly. And the feature id is not a field: GPKG refuses to
create a field called `fid`, so the FID and geometry columns are named to GDAL
through options and skipped when the fields are created.

A layer is borrowed from its dataset and a result set is owned, so `Kind::Layer`
and `Kind::SQLResult` are separate kinds in `inst/include/gdal7.h`. A result set
goes back through `GDALDatasetReleaseResultSet`, and only if the dataset is
still open, which the ownership chain from stage 1 already knew how to answer.

### Stage 5 - Multidimensional read

*Status: done.* `read_mdarray()` is `GDALMDArrayRead` with a start, a count and a
step, the step signed so a dimension can be read backwards. The result's `dim`
is the reverse of the array's own dimension order, named, which is both the
order ncdf4 and RNetCDF use and the order the values already arrive in, so
nothing is moved to produce it. Nodata becomes `NA` unless asked otherwise.
Around it: `get_attributes()` for a group or an array, `get_dimension_values()`
and `get_coordinate_variables()` for where the values sit, `get_view()` for
GDAL's own lazy slicing syntax, `as_classic_dataset()` for the bridge back to
the raster side, and `mdarray_info()` as the one-call summary. `get_dimensions()`
now also reports each dimension's type and direction, which is how
`as_classic_dataset()` knows which dimension is X and which is Y without being
told.

`GDALMDArrayRead` with start/count/step/stride, attributes, coordinate variables,
`GetView` for slicing, `AsClassicDataset` for the bridge back to raster. This is the
stage the existing multidim skeleton was pointed at; before it, the skeleton could
navigate groups and arrays but not read a value.

*Exit:* met. `tests/testthat/test-multidim.R` slices `inst/extdata/multidim.zarr`,
a 3 by 4 by 5 Zarr store holding 1 to 60 in reading order, and checks the values,
the dimension order, the reversed read, the strided read and the nodata cell
against that. The fixture is Zarr V3, whose layout has no dot-prefixed files, so
it ships as an ordinary directory; GDAL writes Zarr itself, so no external
library is needed to rebuild it.

### Stage 6 - Algorithms and pipelines

The `gdalalgorithm.h` C API from 7.2: registry, instantiate by path, set arguments by
name, run with a progress callback, retrieve in-memory results. Guarded on GDAL 3.12.
Progress and interrupt handling from 7.8 lands here.

*Exit:* `gdal raster reproject` and a raster pipeline run from R with named
arguments, an interruptible progress bar, and a MEM dataset handed back without
touching disk.

### Stage 7 - Write side and creation

`GDALCreate` / `CreateCopy` with creation options parsed from the driver XML
(`src/GDAL7_driver.cpp:118` currently returns the raw XML string), `WriteRaster`,
VSI, `CPLSetConfigOption`, thread-safe datasets from section 6.

*Exit:* create a COG from R, validate it with the driver's own checks.

---

## 9. Housekeeping

*Closed in Stage 5.* The duplicate design documents are gone: `data-raw/` carried
two copies of each (`GDAL7-rationale.md` / `gdal7-rationale.md`,
`GDAL7-dev-guide.md` / `gdal7-dev-guide.md`) which had already drifted, the
lowercase copies saying S7 v0.2.0 Nov 2024 against the uppercase v0.2.1 Nov 2025.
The uppercase copies were kept, being the ones whose code matches the package's
own `GDAL7_` naming.

`data-raw/STATUS.md` and `data-raw/PARSER_STATUS.md` were snapshots of the
proof-of-concept era and described the driver, band and multidim classes as
unimplemented long after they existed. They are replaced by `data-raw/README.md`,
which says what the scripts are and how to run them and leaves the plan to this
document.

---

## 10. Positioning

Worth stating explicitly somewhere public, because it affects what to build.

The differentiator against gdalraster, vapour and sf is not "more of the API".
gdalraster already covers a lot of it, and with more polish. The differentiator is
**the API, reflectively, from a generator anyone can audit**, plus the two things no
existing R binding has: Arrow-native vector reads as the primary path, and GDAL's own
algorithm registry exposed directly so the CLI's capabilities arrive without a
release cycle.

Stages 0 through 3 buy the credibility. Stages 4 and 6 are the reasons for someone to
switch.
