
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

### Vector data

A whole layer arrives as a data frame in one call, through the
column-oriented Arrow path GDAL added in 3.6, so there is no per-feature
work in R at all. Geometry comes back as WKB, in a list column of raw
vectors:

``` r
gpkg <- system.file("extdata/test.gpkg", package = "GDAL7")

ds <- gdal_open(gpkg)
gdal_layers(ds)
#>     name geometry_type feature_count fast_arrow
#> 1 places         Point             5       TRUE

places <- read_vector(ds)
places[c("name", "population")]
#>        name population
#> 1    Hobart     247086
#> 2 Melbourne    5031195
#> 3    Sydney    5312163
#> 4     Perth    2141834
#> 5    Darwin     147255

gdal_close(ds)
```

Filters are set on the layer and apply to everything read afterwards. A
spatial filter is what makes a large layer cheap, because a driver with
a spatial index uses it rather than reading every feature:

``` r
ds <- gdal_open(gpkg)
layer <- get_layer(ds, "places")

set_filter(layer, where = "population > 1e6", bbox = c(140, -45, 155, -30))
read_vector(layer)$name
#> [1] "Melbourne" "Sydney"

read_vector(execute_sql(ds, "SELECT name FROM places ORDER BY name LIMIT 2"))
#>   OGC_FID   name
#> 1       1 Darwin
#> 2       2 Hobart
gdal_close(ds)
```

The same path runs the other way, so a data frame with a WKB column
writes back out as a layer:

``` r
path <- tempfile(fileext = ".gpkg")
write_vector(places, path, layer = "places", crs = "EPSG:4326",
             geometry_type = "Point")

identical(read_vector(path), places)
#> [1] TRUE
unlink(path)
```

### Constants and capabilities

The enumerators and metadata keys that GDAL declares come through as two
named vectors, rather than two hundred exported names:

``` r
gdal_constants("GDT_")[1:6]
#> GDT_Unknown    GDT_Byte    GDT_Int8  GDT_UInt16   GDT_Int16  GDT_UInt32 
#>           0           1          14           2           3           4
gdal_string_constants("DCAP_")[1:3]
#>                      DCAP_OPEN                    DCAP_CREATE 
#>                    "DCAP_OPEN"                  "DCAP_CREATE" 
#>   DCAP_CREATE_MULTIDIMENSIONAL 
#> "DCAP_CREATE_MULTIDIMENSIONAL"
```

The dimensions of a dataset are S7 properties, read from GDAL each time
rather than copied when the object was made:

``` r
ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))
c(ds@raster_xsize, ds@raster_ysize, ds@raster_count)
#> [1] 20 10  2
gdal_close(ds)
```

A few bindings call GDAL functions newer than the minimum GDAL7
requires. They always exist and always dispatch; calling one that the
GDAL in use is too old for raises an error naming the release it needs.
`gdal7_capabilities()` is how to ask first:

``` r
gdal_version()[["release"]]
#> [1] "3.8.4"
gdal7_capabilities()
#>                              binding   gdal available
#> 1     dataset_mark_suppress_on_close 3.12.0     FALSE
#> 2 dataset_get_close_reports_progress 3.13.0     FALSE
#> 3             dataset_is_thread_safe 3.10.0     FALSE
#> 4    dataset_get_thread_safe_dataset 3.10.0     FALSE
#> 5                 dataset_as_mdarray 3.12.0     FALSE
```

## Code of Conduct

Please note that the GDAL7 project is released with a [Contributor Code
of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
