# gdal7: Fresh GDAL Bindings for R

## The Opportunity

Two parallel evolutions are converging:

**R's OOP systems**: S3 → S4 → R6 → **S7**
- S7 is the R Consortium's answer to R's OOP fragmentation
- Joint effort: R-Core, Bioconductor, tidyverse, ROpenSci
- Designed to supersede both S3 and S4
- Goal: merge into base R
- Currently v0.2.0 on CRAN (Nov 2024)

**R-GDAL bindings**: rgdal → sf/terra/gdalraster → **?**
- rgdal: retired 2023
- sf/terra: high-level, opinionated (excellent for their use cases)
- gdalraster: lower-level but uses Rcpp Modules → S4 classes
- Gap: no comprehensive, modern, low-level GDAL bindings

## The Insight

GDAL already maintains language-agnostic interface definitions in `swig/include/*.i`:

```
gdal.i (68K)      - Core functionality
Dataset.i (37K)   - Raster datasets
Band.i (29K)      - Raster bands  
ogr.i (143K)      - Vector (OGR)
osr.i (46K)       - Spatial reference
MultiDimensional.i (52K) - NetCDF/Zarr style arrays
```

These files define the public API that GDAL exposes to Python, Java, and C#. They're:
- **Curated** - GDAL maintainers decide what's public
- **Stable** - breaking changes are versioned
- **Complete** - everything you need for bindings
- **Language-neutral** - the core `.i` files have minimal language-specific code

We don't need to reverse-engineer GDAL's C++ headers or manually track API changes. We parse these `.i` files and generate R bindings.

## Why Not Alternatives?

**vs. Converting gdalraster piecemeal**
- Still stuck with S4 (Rcpp Modules output)
- Manual effort for each method
- Doesn't track GDAL changes

**vs. Parsing C++ headers directly**
- Preprocessor complexity
- Templates, private members, implementation details
- Much harder to parse correctly

**vs. Wrapping the C API**
- Loses OO structure
- Have to reconstruct class relationships manually
- More boilerplate

**vs. Manual bindings**
- Doesn't scale (GDAL has hundreds of methods)
- Drift as GDAL evolves
- Tedious and error-prone

## The Architecture

```
GDAL swig/include/*.i files
         │
         ▼
┌─────────────────────┐
│  R Parser (~700 LOC)│  ← Extracts classes, methods, types
└─────────────────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐ ┌──────────┐
│ cpp11 │ │ S7 classes│
│ glue  │ │ + generics│
└───────┘ └──────────┘
    │         │
    └────┬────┘
         ▼
┌─────────────────────┐
│   gdal7 R package   │
└─────────────────────┘
```

## Why S7?

1. **Properties with getters/setters** - map directly to C++ accessors
2. **Validators** - enforce GDAL constraints at R level  
3. **Formal class definitions** - machine-generatable
4. **R-Core backing** - will be in base R, not a third-party dependency
5. **S3/S4 interop** - coexists with sf, terra, stars
6. **Functional OOP** - `method(object)` not `object$method()`, idiomatic R

Example of what generated code looks like:

```r
GDALDataset <- S7::new_class("GDALDataset",

parent = GDALMajorObject,
properties = list(
  .ptr = S7::class_any,
  raster_xsize = S7::new_property(
    class = S7::class_integer,
    getter = function(self) .Call(gdal7_dataset_get_raster_xsize, self@.ptr)
  )
))

get_raster_band <- S7::new_generic("get_raster_band", "x")
S7::method(get_raster_band, GDALDataset) <- function(x, band) {
GDALRasterBand(.ptr = .Call(gdal7_dataset_get_raster_band, x@.ptr, as.integer(band)))
}
```

## Relationship to Existing Packages

**sf, terra, stars**: High-level, user-facing
- gdal7 could be a foundation they build on
- Or coexist independently (S7 interoperates with S3/S4)

**gdalraster**: Similar level but different approach
- Could eventually build on gdal7
- Or maintained separately for existing users

**vapour**: Low-level but C API based
- gdal7 provides OO interface as alternative

## Scope

**Phase 1: Core Raster** (proof of concept)
- GDALMajorObject, GDALDataset, GDALRasterBand, GDALDriver

**Phase 2: Vector**
- OGRLayer, OGRFeature, OGRGeometry

**Phase 3: Spatial Reference**
- OGRSpatialReference, OGRCoordinateTransformation

**Phase 4: Multidimensional** (critical for modern workflows)
- GDALGroup, GDALMDArray, GDALDimension, GDALAttribute

**Phase 5: Algorithms & Utilities**
- Warp, Translate, VRT, VSI

## What We've Proven

The parser works. From the SWIG `.i` files we successfully extract:
- Classes with inheritance
- Methods with full signatures
- Return types including pointers
- Parameters with defaults and type hints
- Typemap annotations (NONNULL, CSL, dict, etc.)

| File | Classes | Methods |
|------|---------|---------|
| MajorObject.i | 1 | 9 |
| Dataset.i | 1 | 45 |
| Band.i | 1 | 57 |
| MultiDimensional.i | 6 | 92 |

## Remaining Work

1. Properties (from `%immutable` blocks)
2. Constants (from `%constant` directives)
3. cpp11 code generator
4. S7 code generator
5. Package scaffolding and testing

Estimated: 2-4 focused days to working prototype.

## Why This Matters

- **Comprehensive**: Full GDAL API, not a curated subset
- **Current**: Regenerate when GDAL updates
- **Modern**: S7 + cpp11, not legacy tooling
- **Maintainable**: Generator, not hand-written bindings
- **Foundation**: Other packages can build on it

This is the R-GDAL binding that should exist.
