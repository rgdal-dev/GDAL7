# GDAL7 (development version)

## Stage 4: vector via Arrow

* `read_vector()` reads a whole vector layer into a data frame in one call,
  through GDAL's column-oriented Arrow API rather than feature by feature.
  Geometry arrives as WKB, in a list column of raw vectors. It takes a layer, a
  dataset, or a path.

* `write_vector()` is the same path in the other direction: the data frame
  becomes one Arrow record batch, GDAL creates the fields from its schema, and
  `OGR_L_WriteArrowBatch` writes it. A GeoPackage round-trips exactly, feature
  ids and WKB included.

* `arrow_stream()` hands the layer out as a `nanoarrow_array_stream`, which is
  the Arrow interchange contract, so it composes with nanoarrow, arrow and
  duckdb directly. A layer allows one stream at a time;
  `release_arrow_stream()` gives one back, and `read_vector()` does that for
  you.

* `gdal_layers()` lists a dataset's layers with their geometry type, feature
  count, and whether the driver has a native Arrow fast path
  (`OLCFastGetArrowStream`).

* `get_layer()` takes a layer by name or by position, and `execute_sql()` runs
  a statement and returns its result set as a layer, or `NULL` for a statement
  that has none. A result set is released when it is collected, or when its
  dataset is closed.

* `set_filter()` sets a layer's attribute filter, spatial filter, or both.
  Both apply to everything read afterwards, `feature_count()` included. A
  spatial filter is what makes a large layer cheap, because a driver with a
  spatial index uses it rather than reading every feature.

* `feature_count()` and `get_extent()` ask the driver first and only scan the
  layer when asked to, returning `NA` rather than a number it would have had to
  invent.

* A layer belongs to its dataset and a result set belongs to the query, so both
  are tracked by the ownership chain: touching a layer after its dataset is
  closed is an R error, not a crash.

* `nanoarrow` is a new dependency, and `inst/extdata/test.gpkg` is a new
  five-feature fixture.

## Stage 3: the generator

* The C function a binding calls is now derived from the `%extend` body in
  GDAL's own SWIG file, which is where GDAL writes that mapping down. The
  hand-maintained table of about 33 method-to-function pairs, and the
  `paste0("GDAL", name)` guess it fell back on, are gone.

* The skip list is gone with it. A method is generated when the generator can
  express it; when it cannot, the generated file records which method and why.
  Fifteen of GDAL's Dataset methods are recorded that way. Five more are named
  as hand-written elsewhere in the package, which is a different thing and is
  now labelled as one.

* Twelve Dataset methods that the skip list had been hiding are bound:
  `reset_reading()`, `abort_sql()`, `start_transaction()`,
  `commit_transaction()`, `rollback_transaction()`, `clear_statistics()`,
  `get_field_domain_names()`, `delete_field_domain()`,
  `get_relationship_names()`, `delete_relationship()`, `set_projection()`,
  `add_band()` and `create_mask_band()`.

* `gdal_constants()` and `gdal_string_constants()` return GDAL's own
  enumerators and metadata keys, which the package had none of: `GDT_*`, `GA_*`,
  `GCI_*`, `GRA_*`, `OF_*`, `CE_*`, `DMD_*`, `DCAP_*` and the rest. They are two
  named vectors rather than two hundred exported names.

* A binding whose GDAL function is newer than the GDAL in use still exists and
  still dispatches; calling it raises an error naming the release it needs.
  `gdal7_capabilities()` says which bindings those are and whether this build
  has them, and `gdal_version()` reports the GDAL being run against. One source
  tree now builds against GDAL 3.8 through 3.14.

* A dataset's dimensions are S7 properties: `ds@raster_xsize`,
  `ds@raster_ysize`, `ds@raster_count`. GDAL declares them with `%immutable`,
  and the generator now reads that. `get_raster_xsize()` and its two companions
  still work and read the same properties.

* `get_spatial_ref()` is removed. It could not have worked: GDAL's SWIG body
  clones the reference rather than making a single call, and the generated R
  returned an S7 class the package does not define. `get_projection()` gives
  the WKT.

* The API model extracted from GDAL's SWIG files is vendored at
  `inst/api/gdal-api.json`, stamped with the GDAL version it came from, so the
  generators run from a clone with no GDAL checkout. A CI job regenerates on
  every commit and fails if the checked-in generated code differs.

* Fixed: the SWIG parser dropped the pointer from `char **options`, leaving the
  parameter reading as a single `char`. That is what "complex params" meant in
  the old skip list for `AddBand` and `BuildOverviews`.

* Fixed: a `#if !defined(SWIGJAVA)` block was being skipped as if it selected
  another language, so every constant behind one was invisible, along with the
  `GDALAsyncReader` class.

## Stage 2: raster I/O

* `read_raster()` reads a window of a band at a chosen output size, through
  `GDALRasterIOEx`. The window and the output size are independent and the
  window may be fractional, so a large window at a small output size is served
  from an overview and costs only that level's bytes. That is what makes a
  large raster over `/vsicurl/` usable interactively. Resampling is chosen by
  the caller.

* `read_raster()` on a dataset reads several bands in one pass rather than one
  pass per band.

* `gdal_info()` returns the whole dataset summary in a single call: driver,
  size, projection, geotransform, files, metadata, and a data frame with one
  row per band. The same summary reached one accessor at a time is seven calls
  per band plus a handful for the dataset.

* Geotransforms in both directions: `get_geotransform()`,
  `set_geotransform()`, and `apply_geotransform()` / `inv_geotransform()`,
  which are vectorised over whole coordinate vectors. A dataset with no
  geotransform returns NULL rather than the identity GDAL reports for it.

* Overview introspection: `get_overview_count()`, `get_overview_sizes()` and
  `get_overview()`. An overview band belongs to the same dataset as the band it
  came from and keeps it open.

* `gdal_data_types()` and `gdal_color_interpretations()` give the `GDT_*` and
  `GCI_*` codes as named integer vectors, read out of the running GDAL rather
  than hard coded.

* Fixed `get_data_type_name()` on a multidimensional array, which returned an
  empty string for every plain numeric array.

* The README example now runs against fixtures that ship with the package, so
  it knits with no network and stops going stale. The remote example uses a
  GEBCO COG on source.coop in place of a link that had gone.

## configure fixes

* A development build of GDAL is no longer refused. `gdal-config --version`
  reports something like `3.14.0dev` for those, which `package_version()`
  rejects outright, and `configure` was treating a version it could not parse
  as a version that was too old. Only the leading numeric part is compared now,
  and a comparison that cannot be made is reported and stepped over rather than
  being fatal.

* A libgdal with undefined symbols of its own no longer blocks the build.
  `configure` linked its test program as an executable, which makes the linker
  resolve every symbol of every library on the link line, libgdal's own
  dependencies included. R links `GDAL7.so` as a shared object, which does not,
  so the check was stricter than the build it was checking. It now retries with
  `gdal-config --dep-libs`, and then as a shared object, before giving up, and
  says which of the three worked. A GDAL built against a newer GEOS than the
  one installed is the usual way this comes up; GDAL7 itself calls no GEOS
  functions.

## Stage 1: safe object lifetimes

* GDAL objects now have real lifetimes. Every handle reaching R carries a
  record of what must stay alive for it to be valid, and that record chains to
  the object it came from. A band keeps its dataset open, an array keeps its
  group and its dataset open, and dropping the last R reference to any of them
  closes them in the right order. The shared header is
  `inst/include/gdal7.h`.

* Using an object after the dataset it belongs to has been closed is now an R
  error rather than a read of freed memory. Before this, `gdal_close(ds)`
  followed by `get_xsize(band)` was undefined behaviour.

* Datasets are now actually closed. There was no finalizer calling
  `GDALClose()`, so every dataset opened in a session stayed open until R
  exited. A loop opening and dropping 500 datasets now shows a flat file
  descriptor count.

* `GDALGroupRelease()` and `GDALMDArrayRelease()` are now called. Both bindings
  existed but nothing ever reached them, so multidimensional groups and arrays
  leaked.

* External pointers are tagged with the kind of object they hold, so passing a
  band where a dataset is expected gives "Expected a GDALDataset object"
  instead of a crash. Groups and arrays are no longer accepted by the
  `GDALMajorObject` bindings, which they are not in the GDAL C API.

* GDAL errors and warnings now arrive as R conditions. They are collected for
  the duration of each fallible call, so a failure reports what GDAL said about
  that call rather than whatever was left over from an earlier one, and a
  warning can be caught, muffled or tested like any other. Previously they went
  to stderr, out of reach of R.

* Metadata that is absent now reads as `NA` rather than `""`, so
  `get_metadata_item()` can tell "not set" from "set to the empty string".

* `get_metadata_dict()` returns a named character vector, split on `=`.
  It and `get_metadata_list()` were byte-identical implementations.

* `get_dimensions()` no longer returns a malformed list. The C level result had
  `n` leading NULLs in front of its two columns.

* String list conversions use `CPLStringList`, which frees itself if the
  conversion throws part way through.

* Fixed the generator naming every overload's C++ binding after the first
  overload, which is how `set_metadata_2()` came to call the list variant. The
  fix in Stage 0 was in the generated file only, so regenerating would have put
  the fault back.

## Stage 0: the package installs and checks

* The declared GDAL floor is now 3.10, up from 3.0.0, which was wrong in any case:
  the multidimensional bindings are RFC 75 and need at least 3.1. `configure`
  reads the floor from `DESCRIPTION` and refuses an older GDAL with a clear
  message. Linux CI moved to `ubuntu-26.04`, whose `libgdal-dev` is 3.12.2;
  `ubuntu-latest` is still 24.04 with GDAL 3.8.4, and migrates to 26.04 in
  October 2026.

* The package can be installed from a clone or with `remotes::install_github()`.
  `src/cpp11.cpp` and `R/cpp11.R` are now committed rather than gitignored, so
  no generator step is needed before installing.

* Added a `configure` script that finds GDAL through `gdal-config` or
  pkg-config, checks the version, and compiles a test program before building.
  Added `src/Makevars.ucrt` and `src/Makevars.win` for Windows.

* Added `R CMD check` on Linux, macOS and Windows via GitHub Actions.

* Documentation is now generated: roxygen2 owns `NAMESPACE` and `man/`.

* Fixed print methods, which were defined but never dispatched. S7 registers
  methods for other packages' generics at load time, so `.onLoad()` now calls
  `S7::methods_register()`. `print()` on a dataset, band, driver, group or
  array now shows a summary instead of the raw external pointer.

* Fixed `has_open_option()`, which called `GDALDriverHasOpenOption()`. There is
  no such function in the GDAL C API, so the package did not compile at all
  against GDAL 3.8. It now reads the driver's `DMD_OPENOPTIONLIST` metadata.

* Fixed `set_metadata_2()`, which called the list-taking binding and so could
  never accept the single string it documents.

* SWIG's default arguments now reach R. Generics carry real formals, so
  `get_metadata_item(ds, "AREA_OR_POINT")` works without naming the domain.

* Connection strings are no longer passed through `normalizePath()`. That
  rewrites separators on Windows and would corrupt every `/vsi*/`, `WMTS:` and
  `NETCDF:` string. Only real files on disk are resolved now.

* Added a testthat suite with fixtures that ship in the package, so the tests
  need no network and no paths outside the installed package.

* Removed `data-raw/fix_cpp11.R`. Verified against cpp11 0.4.7 that
  `cpp_register()` output is clean and the fixer changed nothing.

* Added `ROADMAP.md`.


* Added raster info and band access. 

* Added driver info and multidim. 


## GDAL7 0.0.1 (2026-01-30)

Initial proof-of-concept release. This package provides S7 bindings to the GDAL C API, generated from GDAL's SWIG interface files.

### Features

**Code Generation Pipeline**

* `parse_swig.R` - Parser extracts method signatures from GDAL SWIG `.i` files
* `generate_cpp11.R` - Generates cpp11-annotated C++ bindings
* `generate_s7.R` - Generates S7 class definitions with generics and methods
* `fix_cpp11.R` - Post-processor to fix cpp11 registration issues
* `orchestrate.R` - Master script to run the full generation pipeline

**Classes**

* `GDALMajorObject` - Base class for GDAL objects with metadata methods
* `GDALDataset` - Raster/vector dataset class (inherits from GDALMajorObject)

**Functions**

* `gdal_open(path, update)` - Open a GDAL dataset
* `gdal_close(ds)` - Close a dataset

**GDALMajorObject Methods**

* `get_description()` / `set_description()` - Object description
* `get_metadata_domain_list()` - List available metadata domains
* `get_metadata_list()` / `get_metadata_dict()` - Retrieve metadata
* `get_metadata_item()` / `set_metadata_item()` - Single metadata items
* `set_metadata()` - Set metadata from list

**GDALDataset Methods**

* `get_projection()` / `get_projection_ref()` - WKT projection string
* `get_file_list()` - Files comprising the dataset
* `get_gcpcount()` / `get_gcpprojection()` - Ground control point info
* `get_layer_count()` - Number of vector layers
* `flush_cache()` - Flush pending writes

**GDALDataset Methods (return classes not yet implemented)**

* `get_spatial_ref()` - Returns OGRSpatialReference (errors until class implemented)
* `get_driver()` - Returns GDALDriver (errors until class implemented)
* `get_raster_band(n)` - Returns GDALRasterBand (errors until class implemented)

### Known Limitations

* GDALDriver, GDALRasterBand, OGRSpatialReference classes not yet implemented
* Methods returning these types (`get_driver`, `get_raster_band`, `get_spatial_ref`) will error
* `GetGeoTransform()` / `SetGeoTransform()` not yet supported (array parameters)
* Vector layer methods not yet supported
* No automatic memory management / destructor support

### Technical Notes

* Requires GDAL installed with development headers
* Uses cpp11 for C++ bindings and S7 for R class system
* Tested against GDAL autotest suite files
* Supports `/vsicurl/` and other GDAL virtual file systems
