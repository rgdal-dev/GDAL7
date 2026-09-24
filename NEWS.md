# GDAL7 0.1.0

## Engine gaps for a downstream reader

Additions asked for by the lazy IO package being designed on top of
GDAL7, each of which it needs and none of which it can add for itself.

* `gdal_open()` takes `options` and `drivers`. Open options are how a source
  is told what its own metadata does not say, without wrapping it in anything:
  a CSV's `X_POSSIBLE_NAMES=lon`, a raster's `OVERVIEW_LEVEL=2`. `drivers`
  names the drivers that may try, so a second driver cannot claim a file the
  first should have had. `NULL` places no restriction and is the default;
  `character(0)` would allow nothing at all and is an error rather than a
  silent no-op.

* `read_raster()` takes `type`, one of `"double"` (the default, unchanged),
  `"integer"` or `"raw"`. A Byte band read as raw is an eighth of the memory
  of the same band read as double, which is the difference between a workable
  RGB image in memory and an unworkable one. GDAL reads straight into the R
  vector rather than converting afterwards. A band whose type will not fit is
  an error rather than a silent clamp, and for a dataset every band read has
  to fit.

* A layer has `fid_column` and `geometry_column` properties, the names those
  two columns have when it is read: the format's own where it stores them as
  named columns, and GDAL's `OGC_FID` and `wkb_geometry` where it does not.
  A reader that wants one name per column can rename from these rather than
  guessing per driver.

* `transform_extent()` moves an extent between coordinate reference systems.
  It samples the box twice and takes the envelope of the two: GDAL's own walk
  around the boundary, with `densify` extra points along each edge, and a
  `(mesh + 1)^2` grid over the interior. The walk alone is provably enough
  wherever the transform is well behaved, and provably not enough where it is
  not: a box surrounding the antipode of an azimuthal projection comes back
  365 km too narrow from the walk alone, because that extreme is interior.
  The mesh alone is not a replacement either, since it spends nearly all of
  its points inside the box and samples the edges more coarsely than the walk
  does. Taking both costs one coordinate transformation object and dominates
  either sampling by construction.

  Getting an extent wrong in the small direction is the dangerous failure,
  because a raster window picked from it clips data the caller asked for and
  nothing downstream can tell. So when part of the box has no image in the
  target, the result is the envelope of the part that does and an `"outside"`
  attribute gives the fraction of the mesh that failed; when nothing
  transforms at all, it is an error. A box given wrapped across the
  antimeridian, with `xmax` below `xmin`, is refused rather than answered in a
  form a minimum and a maximum cannot represent.

  Both sides are read in x, y order whatever their authority says. This is a
  transformation of four numbers, not a warp, and it reprojects no pixels.
  `inst/design/extent-transformation.md` records the argument, the measured
  failures and what is still unresolved.

## Stage 8: namespace hygiene

* What an object knows about itself is now a property rather than a verb:
  `band@nodata_value`, `ds@crs`, `ds@geotransform`, `arr@dimensions`,
  `drv@short_name`, `grp@mdarray_names`. Each is read from GDAL at the moment
  it is asked for, so none is a stale copy taken when the object was made.

* The ones GDAL lets you change are set by assignment:
  `band@nodata_value <- -999`, `ds@crs <- "EPSG:3857"`,
  `ds@geotransform <- c(...)`. This replaces `set_nodata_value()`,
  `set_scale()`, `set_offset()`, `set_unit_type()`,
  `set_color_interpretation()`, `set_crs()`, `set_geotransform()`,
  `set_projection()` and `set_description()`.

* The accessors they replace are gone: `get_raster_xsize()`, `get_xsize()`,
  `get_data_type_name()`, `get_block_size()`, `get_nodata_value()`,
  `get_scale()`, `get_offset()`, `get_unit_type()`,
  `get_color_interpretation()`, `get_overview_count()`,
  `get_overview_sizes()`, `get_geotransform()`, `get_description()`,
  `get_projection()`, `get_file_list()`, `get_layer_count()`,
  `get_short_name()`, `get_long_name()`, `get_help_topic()`, `get_name()`,
  `get_full_name()`, `get_dimensions()`, `get_attributes()`, `gdal_layers()`
  and the rest of that family. The namespace went from 141 exports to 93.

* `ds@crs` reads as WKT2 and takes anything GDAL understands when written.
  `ds@projection` beside it is GDAL's own `SetProjection`, which is WKT1.
  An array's `crs` is WKT2 now too.

* Accessors that take an argument are still functions, because they are not
  properties of anything: `get_raster_band()`, `get_overview()`,
  `get_metadata_item()`, `get_layer()`, `open_mdarray()`, `open_group()`.

* The generator derives the properties from GDAL's own methods, so a GDAL that
  adds a `GetX`/`SetX` pair gets a property without a change here.

* Eight exports that gdalraster already owns are renamed, so that attaching
  both packages no longer masks a function with one of a different shape. The
  virtual file system family is `vfs_list()`, `vfs_stat()`, `vfs_exists()`,
  `vfs_unlink()`, `vfs_mkdir()`, `vfs_rmdir()`, `vfs_rename()`, `vfs_copy()`,
  `vfs_read_file()` and `vfs_write_file()`; the whole family moved, not only
  the names that clashed, so that it stays one family.

* `gdal_version()` is now `gdal_release()`, which is what it returns.

* `apply_geotransform()` and `inv_geotransform()` are now `pixel_to_xy()` and
  `xy_to_pixel()`. The inversion happens inside `xy_to_pixel()`, so there is
  one call in each direction rather than a call and an inverse to compose, and
  it returns `pixel` and `line` rather than `x` and `y`. A geotransform that
  cannot be inverted is an error rather than a NULL to check for.

* `gdal_create()` keeps its name and masks sf's, since `gdal_create_copy()`
  beside it does not clash and the pair reads better together.

## Stage 7: write side and creation

* `gdal_create()` makes a dataset from nothing and `gdal_create_copy()` copies
  one through a driver, with a progress bar and Ctrl-C when it is worth one.
  `gdal_delete()` removes a dataset and its sidecars through the driver that
  knows about them.

* `write_raster()` writes into a band or into several bands of a dataset in one
  call, taking the same window and resampling arguments `read_raster()` takes.
  `gdal_flush()` pushes what is written down to the file.

* What a written raster needs is now settable rather than only readable:
  `set_crs()`, `set_nodata_value()`, `set_scale()`, `set_offset()`,
  `set_unit_type()` and `set_color_interpretation()`.

* Creation options are a table rather than a string of XML. `driver_options()`
  reports every option a driver takes with its type, default, range and the
  values a fixed-choice option allows, read out of GDAL's own metadata.
  `validate_creation_options()` asks GDAL whether a list would be accepted, and
  `gdal_create()` and `gdal_create_copy()` ask before anything is made, so a
  typo is an error rather than a file. This replaces `get_creation_options()`,
  which returned the raw XML.

* Options are written the way R writes things, `c(COMPRESS = "DEFLATE",
  BLOCKSIZE = "128")` or a list, and a logical arrives as GDAL's `YES` or `NO`.
  GDAL's own `"KEY=VALUE"` spelling still works.

* `gdal_drivers()` reports raster, vector, multidim, create, copy and virtual
  I/O capabilities and the extensions each driver claims, in one pass over the
  driver manager rather than a call per driver per capability.

* GDAL's virtual file systems are bound directly: `vsi_list()`, `vsi_stat()`,
  `vsi_exists()`, `vsi_unlink()`, `vsi_mkdir()`, `vsi_rmdir()`, `vsi_rename()`,
  `vsi_copy()`, `vsi_read_file()` and `vsi_write_file()`. A dataset can be built
  at a `/vsimem/` path and its bytes read back without ever reaching the disk.

* `gdal_config()`, `gdal_config_options()` and `with_gdal_config()` read, set
  and scope GDAL's configuration options, putting back exactly what was there,
  including leaving unset what was unset.

* `get_thread_safe_dataset()` hands back a view of a raster several threads may
  read at once, and `is_thread_safe()` says whether a dataset already is one.
  Both need GDAL 3.10; `gdal7_capabilities()` says whether this build has them.

* `crs_to_wkt()` exports a CRS as WKT2 by default, with `format` and `multiline`
  for the rest. GDAL's plain export is WKT1, which loses the projection's name.

## Stage 6: algorithms and pipelines

* `gdal_run()` runs any of GDAL's own algorithms, the ones its `gdal` command
  line is built from, with arguments given by name. Because it binds the
  registry rather than each utility, an algorithm or an argument GDAL adds
  arrives without a change here.

* An algorithm told to work in memory hands back a GDALDataset with nothing
  written to disk; one given a file name writes it, closes it and hands back
  the path, so the file can be opened straight away. Which of the two it is is
  decided by asking the output dataset whether it has files behind it.

* A dataset already open in R can be passed straight in, rather than named and
  reopened, and the algorithm takes its own reference to it.

* `gdal_algorithms()` walks the registry and `gdal_algorithm_info()` reports an
  algorithm's description, its help URL and every argument it takes with its
  type, whether it is required and what values it allows. Nothing about GDAL's
  algorithms is written down in this package.

* Pipelines work through the same call: `gdal_run("raster pipeline", list(
  pipeline = "read ... ! reproject ... ! write ..."))`.

* A long algorithm draws a progress bar and stops on Ctrl-C.

* `gdal_has_algorithms()` says whether this build has any algorithms to run.
  The registry arrived in GDAL 3.11; below that the functions still exist and
  raise an error naming the release, and the tests skip rather than fail.
  Having the API is not the same as having the algorithms: a GDAL can be built
  with them turned off, and before GDAL 3.12 each algorithm registered itself
  as a side effect of being loaded, which a static link leaves out. Both cases
  are an empty registry, which is what the Windows build here has, so
  `gdal_has_algorithms()` looks in it rather than only at the version.

* `data-raw/refresh_symbol_versions.R` now reads the symbols the hand-written
  bindings call out of the sources as well as those the generator emits, so a
  guard in a hand-written file rests on the same recorded table as a generated
  one. It also falls back to the vendored API model when there is no GDAL
  checkout to re-extract from.

## Stage 5: multidimensional read

* `read_mdarray()` reads a hyperslab of a multidimensional array: an origin, a
  count along each dimension, and a step, which may be negative to read a
  dimension backwards. With no arguments it reads the whole array. The result's
  `dim` is the reverse of the array's own dimension order and carries the
  dimension names, so a `(time, lat, lon)` array reads into an R array indexed
  `[lon, lat, time]`. That is the order ncdf4 and RNetCDF use, and it is also
  the order the values already arrive in, so nothing is rearranged to produce
  it. The array's nodata value becomes `NA` unless `nodata_as_na = FALSE`.

* `get_dimension_values()` reads the coordinate variable of every dimension at
  once: the times, latitudes and longitudes the values are placed at.
  `get_coordinate_variables()` gives the arrays a format names as coordinates,
  which is the different question a swath answers.

* `get_attributes()` returns a group's or an array's own annotations as a named
  list, all in one call. `get_scale()`, `get_offset()`, `get_unit_type()` and
  `get_projection()` now work on an array, and `mdarray_info()` fetches the
  whole description in one go.

* `get_view()` takes a slice, a transpose or a reordering in GDAL's own view
  syntax, evaluated lazily, and `as_classic_dataset()` presents a
  two-dimensional array as an ordinary GDAL raster, which is the bridge back to
  `read_raster()` and the band accessors. It picks the X and Y dimensions from
  the ones the format declares as horizontal.

* `open_mdarray()` now accepts a path from the root of the dataset, such as
  `"/weather/temperature"`, as well as a name within one group.

* `get_dimensions()` gained `type`, `direction` and `indexed` columns.

* The Zarr test fixture is replaced by `inst/extdata/multidim.zarr`, a 3 by 4 by
  5 array over time, latitude and longitude with a nodata cell, a scale and
  offset, attributes and a coordinate variable per dimension. It is Zarr V3, so
  it ships as a plain directory rather than the zip the V2 store needed.

* `data-raw/STATUS.md` and `data-raw/PARSER_STATUS.md` described the package as
  it was during the proof of concept and are replaced by `data-raw/README.md`.
  The duplicate lowercase copies of the two design documents are gone.

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
