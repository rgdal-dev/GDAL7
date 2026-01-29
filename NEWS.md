# GDAL7 (development version)

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
