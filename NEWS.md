# GDAL7 (development version)

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
