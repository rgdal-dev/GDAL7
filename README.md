
<!-- README.md is generated from README.Rmd. Please edit that file -->

# GDAL7

<!-- badges: start -->
<!-- badges: end -->

The goal of GDAL7 is to model the GDAL api in R via SWIG.

## Installation

You need GDAL with its development headers (`gdal-config` on its `PATH`,
or pkg-config able to find `gdal`), then:

``` r
remotes::install_github("rgdal-dev/GDAL7")
```

Or from a clone:

``` r
# git clone https://github.com/rgdal-dev/GDAL7 && cd GDAL7
system("R CMD INSTALL --no-staged-install .")
```

The cpp11 registration files (`src/cpp11.cpp`, `R/cpp11.R`) are
committed, so no generation step is needed to install. You only need
`cpp11::cpp_register()` after adding or changing a `[[cpp11::register]]`
function; `data-raw/orchestrate.R` does that as part of regenerating the
bindings.

## Example

The examples below run against a small GeoTIFF that ships with the
package, so they need no network.

``` r
library(GDAL7)

dsn <- system.file("extdata/test.tif", package = "GDAL7")
ds <- gdal_open(dsn)

#### MajorObject methods, shared by datasets, bands and drivers

basename(get_description(ds))                # object description
#> [1] "test.tif"
get_metadata_domain_list(ds)                 # metadata domains
#> [1] "IMAGE_STRUCTURE"     "DERIVED_SUBDATASETS" ""
get_metadata_list(ds, "")                    # metadata as KEY=VALUE strings
#> [1] "AREA_OR_POINT=Area"
get_metadata_dict(ds, "")                    # the same, as a named vector
#> AREA_OR_POINT 
#>        "Area"
get_metadata_item(ds, "AREA_OR_POINT")       # one item, NA when not set
#> [1] "Area"
get_metadata_item(ds, "NO_SUCH_ITEM")
#> [1] NA

#### Dataset methods

get_projection(ds)      # projection as WKT
#> [1] "GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AXIS[\"Latitude\",NORTH],AXIS[\"Longitude\",EAST],AUTHORITY[\"EPSG\",\"4326\"]]"
basename(get_file_list(ds))  # the files this dataset is made of
#> [1] "test.tif"
get_gcpcount(ds)        # number of GCPs
#> [1] 0
get_layer_count(ds)     # number of vector layers
#> [1] 0

c(get_raster_xsize(ds), get_raster_ysize(ds))
#> [1] 20 10
get_raster_count(ds)
#> [1] 2

get_driver(ds)
#> <GDALDriver>
#>   Short name: GTiff
#>   Long name:  GeoTIFF
#>   Help:       drivers/raster/gtiff.html
#>   Capabilities: raster, create, copy, vsi

#### Bands

band <- get_raster_band(ds, 1L)
band
#> <GDALRasterBand>
#>   Band:       1
#>   Size:       20 x 10
#>   Type:       Int16
#>   Block size: 20 x 10
#>   NoData:     -32768
#>   Color:      Gray

get_data_type_name(band)
#> [1] "Int16"
get_block_size(band)
#>  x  y 
#> 20 10
get_nodata_value(band)
#> [1] -32768
```

A band belongs to its dataset, so closing the dataset retires the band
with it. Reaching for one afterwards is an error rather than a crash:

``` r
gdal_close(ds)
get_xsize(band)
#> Error: This GDALRasterBand cannot be used: the GDALDataset it belongs to has been closed
```

### Reading pixels

A read names a window and, separately, the size to return it at. GDAL
picks an overview level that can serve the output size, so a large
window at a small output size costs only the bytes of that level. The
fixture here is a small COG with two overview levels.

``` r
ds <- gdal_open(system.file("extdata/overviews.tif", package = "GDAL7"))
band <- get_raster_band(ds, 1)

get_overview_sizes(band)
#>   xsize ysize
#> 1   256   128
#> 2   128    64

# 512x256 down to 4x2, averaged.
read_raster(band, out_size = c(4, 2), resample = "average")
#> [1]  318  446  574  702  830  958 1086 1214

# An 8x8 window down to 2x2. The window may be fractional.
read_raster(band, window = c(0, 0, 8, 8), out_size = c(2, 2),
            resample = "average")
#> [1]  8 12 24 28

gdal_close(ds)
```

`gdal_info()` gathers everything `gdalinfo` reports that does not need a
pass over the pixels, in a single call rather than one per property:

``` r
info <- gdal_info(system.file("extdata/overviews.tif", package = "GDAL7"))
info$size
#> xsize ysize 
#>   512   256
info$geotransform
#> [1] -180.000000    0.703125    0.000000   90.000000    0.000000   -0.703125
info$band_info
#>   band  type block_x block_y nodata scale offset color unit overviews
#> 1    1 Int16     128     128 -32768    NA     NA  Gray              2
```

### Remote data

Any DSN GDAL understands works, which is the point of the `/vsicurl/`
and service drivers: no download step, and only the bytes actually
needed are read.

``` r
gebco <- "/vsicurl/https://data.source.coop/alexgleith/gebco-2024/GEBCO_2024.tif"

ds <- gdal_open(gebco)
c(get_raster_xsize(ds), get_raster_ysize(ds))
get_block_size(get_raster_band(ds, 1L))
gdal_close(ds)

wmts <- paste0(
  "WMTS:https://services.arcgisonline.com/arcgis/rest/services/",
  "World_Imagery/MapServer/WMTS/1.0.0/WMTSCapabilities.xml,layer=World_Imagery"
)

ds <- gdal_open(wmts)
get_metadata_domain_list(ds)
gdal_close(ds)
```

### Multidimensional data

``` r
zarr <- sprintf(
  'ZARR:"/vsizip/%s/test.zarr"',
  system.file("extdata/test.zarr.zip", package = "GDAL7")
)

ds <- gdal_open(zarr, multidim = TRUE)
grp <- get_root_group(ds)
grp
#> <GDALGroup>
#>   Name: /
#>   Arrays (3): X, Y, test

arr <- open_mdarray(grp, get_mdarray_names(grp)[1])
arr
#> <GDALMDArray>
#>   Name: X
#>   Type: Float64
#>   Dimensions: X=4

get_dimensions(arr)
#>   name size
#> 1    X    4
gdal_close(ds)
```

## Code of Conduct

Please note that the GDAL7 project is released with a [Contributor Code
of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
