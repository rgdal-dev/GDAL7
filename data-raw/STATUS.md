# GDAL7 Development Status

## Overview

GDAL7 is an R package providing S7 bindings to the GDAL C API, generated from GDAL's SWIG interface files.

**Current Status**: Proof of concept working with GDALMajorObject and GDALDataset classes.

## Architecture

```
SWIG .i files (GDAL source)
        │
        ▼
  parse_swig.R          # Extracts method signatures
        │
        ├──► generate_cpp11.R   # Creates C++ bindings
        │           │
        │           ▼
        │     src/GDAL7_*.cpp   # cpp11-annotated C++ files
        │
        └──► generate_s7.R      # Creates R S7 classes
                    │
                    ▼
              R/aaa-class-*.R   # S7 class definitions
```

### Key Files

| File | Purpose | Generated? |
|------|---------|------------|
| `data-raw/parse_swig.R` | Parser for SWIG .i files | No |
| `data-raw/generate_cpp11.R` | C++ binding generator | No |
| `data-raw/generate_s7.R` | S7 class generator | No |
| `data-raw/fix_cpp11.R` | Fixes cpp11 registration bug | No |
| `data-raw/orchestrate.R` | Runs full pipeline | No |
| `src/GDAL7_majorobject.cpp` | MajorObject C++ bindings | Yes |
| `src/GDAL7_dataset.cpp` | Dataset C++ bindings | Yes |
| `src/GDAL7_open.cpp` | gdal_open/gdal_close | No (manual) |
| `src/cpp11.cpp` | cpp11 registration | Yes (by cpp11) |
| `R/aaa-class-majorobject.R` | GDALMajorObject S7 class | Yes |
| `R/aab-class-dataset.R` | GDALDataset S7 class | Yes |
| `R/cpp11.R` | R wrappers for .Call | Yes (by cpp11) |
| `R/gdal-open.R` | gdal_open/gdal_close R wrappers | No (manual) |

### Build Workflow

```bash
# 1. Clone GDAL for SWIG files
git clone --depth 1 https://github.com/osgeo/gdal.git ~/gdal

# 2. Run orchestrate (generates code, runs cpp11, applies fix)
Rscript -e "source('data-raw/orchestrate.R')"

# 3. Install package
R CMD INSTALL --no-staged-install .
```

## Working Functionality

### Classes

- **GDALMajorObject** - Base class for GDAL objects
- **GDALDataset** - Raster/vector dataset (inherits from GDALMajorObject)

### Functions

#### Top-level
- `gdal_open(path, update = FALSE)` - Open a dataset
- `gdal_close(ds)` - Close a dataset

#### MajorObject methods (inherited by Dataset)
- `get_description(x)` - Get object description
- `set_description(x, desc)` - Set object description
- `get_metadata_domain_list(x)` - List metadata domains
- `get_metadata_list(x, domain)` - Get metadata as character vector
- `get_metadata_dict(x, domain)` - Get metadata as key=value pairs
- `get_metadata_item(x, name, domain)` - Get single metadata item
- `set_metadata(x, metadata, domain)` - Set metadata
- `set_metadata_item(x, name, value, domain)` - Set single item

#### Dataset methods
- `get_projection(ds)` - Get projection as WKT string
- `get_projection_ref(ds)` - Alias for get_projection
- `get_file_list(ds)` - Get list of files comprising dataset
- `get_gcpcount(ds)` - Get number of GCPs
- `get_gcpprojection(ds)` - Get GCP projection string
- `get_layer_count(ds)` - Get number of vector layers
- `flush_cache(ds)` - Flush pending writes

#### Dataset methods (classes not yet implemented - will error)
- `get_spatial_ref(ds)` - Returns OGRSpatialReference (class not implemented)
- `get_driver(ds)` - Returns GDALDriver (class not implemented)
- `get_raster_band(ds, n)` - Returns GDALRasterBand (class not implemented)

## Known Issues & Workarounds

### 1. cpp11 Registration Bug

**Problem**: `cpp11::cpp_register()` generates duplicate function declarations with incorrect types in an `extern "C"` block, causing compilation errors.

**Workaround**: `fix_cpp11.R` post-processes `src/cpp11.cpp` to remove the bad declarations.

**Location**: Lines 140+ in generated cpp11.cpp

### 2. R File Load Order

**Problem**: S7 classes must load in dependency order (GDALMajorObject before GDALDataset), but R loads files alphabetically.

**Workaround**: Generated files use `aaa-`/`aab-` prefixes to control load order.

### 3. NAMESPACE Registration

**Problem**: `.Call()` in cpp11.R wrappers needs native symbols to be registered.

**Solution**: NAMESPACE uses `useDynLib(GDAL7, .registration = TRUE)`.

### 4. S7 Method Calls

**Problem**: Originally S7 methods used `.Call()` directly with wrong symbol format.

**Solution**: S7 methods now call the R wrapper functions from cpp11.R.

### 5. Return Type Classes

**Problem**: Methods that return GDAL objects (get_driver, get_raster_band, get_spatial_ref) try to wrap the result in S7 classes that don't exist yet.

**Current state**: These methods will error until the corresponding classes are implemented (GDALDriver, GDALRasterBand, OGRSpatialReference).

**Future fix**: Either implement stub classes or modify generator to return raw external pointers when class doesn't exist.

## Not Yet Implemented

### Classes
- GDALDriver
- GDALRasterBand  
- OGRSpatialReference
- OGRLayer
- OGRFeature
- OGRGeometry

### Dataset Methods (skipped)
- `GetGeoTransform` / `SetGeoTransform` - Array parameters
- `GetExtent` - Array output
- `BuildOverviews` - Complex parameters
- `ReadRaster` / `WriteRaster` - Need Band class
- Vector layer methods - Need OGR includes

### Features
- Automatic memory management (destructor/release)
- Band read/write operations
- Vector feature iteration
- Geometry operations

## Testing

```bash
# Full test suite
Rscript inst/examples/test_gdal7.R

# Quick sanity check
Rscript inst/examples/quick_test.R
```

## Development Notes

### Adding a New Class

1. Add to `orchestrate.R`:
   ```r
   result <- parse_swig_file(file.path(swig_dir, "NewClass.i"))
   cls <- result$classes[[1]]
   generate_cpp11_file(cls, "src/GDAL7_newclass.cpp")
   generate_s7_file(cls, "R/aac-class-newclass.R", skip_methods = skip_list)
   ```

2. Update NAMESPACE with exports

3. Run full pipeline and install

### Skip Lists

Methods are skipped for various reasons:
- GDAL 3.9+ only (not in all builds)
- Complex parameter types (callbacks, arrays)
- Need additional includes (OGR headers)
- Parser doesn't handle signature correctly

See `dataset_skip` in orchestrate.R for current list.
