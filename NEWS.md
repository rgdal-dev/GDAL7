# GDAL7 (development version)

## Stage 0: the package installs and checks

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
