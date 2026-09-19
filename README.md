
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

What an object knows about itself is a property, read from GDAL at the
moment it is asked for rather than copied when the object was made, and
settable by assignment where GDAL lets it be set. What an object *does*,
and anything that needs an argument, is a function.

``` r
library(GDAL7)

dsn <- system.file("extdata/test.tif", package = "GDAL7")
ds <- gdal_open(dsn)

#### What every dataset, band and driver carries

basename(ds@description)                # what the object calls itself
#> [1] "test.tif"
ds@metadata_domain_list                 # the metadata domains it has
#> [1] "IMAGE_STRUCTURE"     "DERIVED_SUBDATASETS" ""

get_metadata_list(ds, "")               # metadata as KEY=VALUE strings
#> [1] "AREA_OR_POINT=Area"
get_metadata_dict(ds, "")               # the same, as a named vector
#> AREA_OR_POINT 
#>        "Area"
get_metadata_item(ds, "AREA_OR_POINT")  # one item, NA when not set
#> [1] "Area"

#### What a dataset knows

substr(ds@crs, 1, 40)                   # the CRS as WKT2
#> [1] "GEOGCRS[\"WGS 84\",ENSEMBLE[\"World Geodeti"
substr(ds@projection, 1, 40)            # GDAL's own WKT1 spelling
#> [1] "GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROI"
ds@geotransform                         # pixel and line to x and y
#>        origin_x     pixel_width    row_rotation        origin_y column_rotation 
#>            -180              18               0              90               0 
#>    pixel_height 
#>             -18
basename(ds@file_list)                  # the files it is made of
#> [1] "test.tif"
ds@gcp_count
#> [1] 0
ds@layer_count                          # vector layers, none here
#> [1] 0

c(ds@raster_xsize, ds@raster_ysize, ds@raster_count)
#> [1] 20 10  2

#### Bands

# A band is taken by number, so that is a function; what it then knows about
# itself is a property.
band <- get_raster_band(ds, 1L)
band
#> <GDALRasterBand>
#>   Band:       1
#>   Size:       20 x 10
#>   Type:       Int16
#>   Block size: 20 x 10
#>   NoData:     -32768
#>   Color:      Gray

band@data_type_name
#> [1] "Int16"
band@block_size
#>  x  y 
#> 20 10
band@nodata_value
#> [1] -32768
```

A band belongs to its dataset, so closing the dataset retires the band
with it. Reaching for one afterwards is an error rather than a crash:

``` r
gdal_close(ds)
band@xsize
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

band@overview_sizes
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
c(ds@raster_xsize, ds@raster_ysize)
get_raster_band(ds, 1L)@block_size
gdal_close(ds)

wmts <- paste0(
  "WMTS:https://services.arcgisonline.com/arcgis/rest/services/",
  "World_Imagery/MapServer/WMTS/1.0.0/WMTSCapabilities.xml,layer=World_Imagery"
)

ds <- gdal_open(wmts)
ds@metadata_domain_list
gdal_close(ds)
```

### Multidimensional data

NetCDF, Zarr and HDF5 hold arrays of any number of dimensions rather
than bands of pixels. GDAL7 navigates them and reads them.

``` r
ds <- gdal_open(system.file("extdata/multidim.zarr", package = "GDAL7"),
                multidim = TRUE)
grp <- get_root_group(ds)
grp
#> <GDALGroup>
#>   Name: /
#>   Arrays (4): lon, temperature, lat, time

arr <- open_mdarray(grp, "temperature")
arr
#> <GDALMDArray>
#>   Name: temperature
#>   Type: Float64
#>   Dimensions: time=3, lat=4, lon=5
#>   Unit: degC
#>   NoData: -999

arr@dimensions
#>   name size         type direction indexed
#> 1 time    3     TEMPORAL              TRUE
#> 2  lat    4 HORIZONTAL_Y     NORTH    TRUE
#> 3  lon    5 HORIZONTAL_X      EAST    TRUE
```

A read takes an origin, a count along each dimension and a step. The
`dim` of what comes back is the reverse of the array's own dimension
order, and carries the dimension names, so there is never a question of
which axis is which.

``` r
values <- read_mdarray(arr)
dim(values)
#>  lon  lat time 
#>    5    4    3

# The first time step, every second longitude.
read_mdarray(arr, start = c(1, 1, 1), count = c(1, 4, 3), step = c(1, 1, 2))
#> , , 1
#> 
#>      [,1] [,2] [,3] [,4]
#> [1,]    1    6   11   16
#> [2,]    3   NA   13   18
#> [3,]    5   10   15   20
```

Where the values sit, and what the format says about them:

``` r
arr@dimension_values
#> $time
#> [1] 0 1 2
#> 
#> $lat
#> [1] -40 -41 -42 -43
#> 
#> $lon
#> [1] 140 141 142 143 144

arr@attributes
#> $coordinates
#> [1] "lat lon"
#> 
#> $long_name
#> [1] "air temperature"
#> 
#> $valid_range
#> [1] -50  50
```

A view slices lazily, in GDAL's own syntax, and a two-dimensional array
can be handed to the raster side of the package as an ordinary dataset.

``` r
first <- get_view(arr, "[0,:,:]")
first@dimensions
#>   name size         type direction indexed
#> 1  lat    4 HORIZONTAL_Y     NORTH    TRUE
#> 2  lon    5 HORIZONTAL_X      EAST    TRUE

raster <- as_classic_dataset(first)
c(raster@raster_xsize, raster@raster_ysize)
#> [1] 5 4

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
ds@layers
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

### Creating and writing

A dataset is made with a size, a band count and a type, written into,
and closed. Closing is what finishes the file.

``` r
path <- tempfile(fileext = ".tif")

ds <- gdal_create(path, 64, 48, bands = 1, type = "Float32")
ds@crs <- "EPSG:4326"
ds@geotransform <- c(-180, 360 / 64, 0, 90, 0, -180 / 48)

write_raster(ds, list(as.double(seq_len(64 * 48))))
gdal_close(ds)

info <- gdal_info(path)
info$size
#> xsize ysize 
#>    64    48
info$band_info[c("band", "type", "block_x", "block_y")]
#>   band    type block_x block_y
#> 1    1 Float32      64      32
substr(info$projection, 1, 30)
#> [1] "GEOGCS[\"WGS 84\",DATUM[\"WGS_198"
```

Creation options are a table, read out of the driver's own metadata,
rather than a string of XML to parse or a list of names to remember:

``` r
options <- driver_options("GTiff")
options[options$name %in% c("COMPRESS", "TILED", "BLOCKXSIZE"),
        c("name", "type", "default")]
#>          name          type default
#> 1    COMPRESS string-select    <NA>
#> 16      TILED       boolean      NO
#> 20 BLOCKXSIZE           int     256

options$choices[[which(options$name == "COMPRESS")]][1:6]
#> [1] "NONE"      "LZW"       "PACKBITS"  "JPEG"      "CCITTRLE"  "CCITTFAX3"
```

They are asked about before anything is made, so a name the driver does
not have, or a value it will not take, is an error rather than a file
left behind:

``` r
validate_creation_options("GTiff", c(COMPRESS = "DEFLATE"))
#> [1] TRUE
validate_creation_options("GTiff", c(COMPRES = "DEFLATE"))
#> [1] FALSE

gdal_create(tempfile(fileext = ".tif"), 4, 4,
            options = c(COMPRESS = "NOT_A_CODEC"))
#> Error: The GTiff driver does not take these creation options: 'NOT_A_CODEC' is an unexpected value for COMPRESS creation option of type string-select.
```

`gdal_create_copy()` puts an existing dataset through a driver, which is
how a COG gets made: the driver builds the overviews and lays the file
out itself.

``` r
cog_path <- tempfile(fileext = ".tif")

cog <- gdal_create_copy(path, cog_path, driver = "COG",
                        options = c(COMPRESS = "DEFLATE", BLOCKSIZE = "128"),
                        progress = FALSE)
gdal_close(cog)

reopened <- gdal_open(cog_path)
get_metadata_dict(reopened, "IMAGE_STRUCTURE")
#>      LAYOUT COMPRESSION  INTERLEAVE 
#>       "COG"   "DEFLATE"      "BAND"
get_raster_band(reopened, 1)@block_size
#>   x   y 
#> 128 128
gdal_close(reopened)
```

`gdal_drivers()` says which drivers can do which of those things, in one
pass over the driver manager:

``` r
# Raster drivers that can make a dataset from nothing, rather than only copy
# an existing one.
drivers <- gdal_drivers(c("DCAP_RASTER", "DCAP_CREATE"))
nrow(drivers)
#> [1] 5
head(drivers[c("short_name", "copy", "vsi", "extensions")], 5)
#>   short_name  copy   vsi    extensions
#> 1      GTiff  TRUE  TRUE      tif tiff
#> 2        VRT  TRUE  TRUE           vrt
#> 3        MEM FALSE FALSE          <NA>
#> 4       GPKG  TRUE  TRUE gpkg gpkg.zip
#> 5       Zarr  TRUE  TRUE          zarr
```

### Virtual file systems

Every GDAL path works, not only files on disk, and they compose. A
dataset built at a `/vsimem/` path never reaches the disk, and its bytes
come back as raw:

``` r
ds <- gdal_create("/vsimem/small.tif", 4, 4, bands = 1, type = "Byte")
write_raster(ds, list(as.double(seq_len(16))))
gdal_close(ds)

vfs_stat("/vsimem/small.tif")$size
#> [1] 162
bytes <- vfs_read_file("/vsimem/small.tif")
rawToChar(bytes[1:2])
#> [1] "II"

vfs_unlink("/vsimem/small.tif")
```

GDAL reads its configuration options at the moment it needs them, so
setting one changes how the next call behaves. `with_gdal_config()` sets
them for one expression and puts back exactly what was there:

``` r
with_gdal_config(c(GDAL_CACHEMAX = "16"), gdal_config("GDAL_CACHEMAX"))
#> [1] "16"
gdal_config("GDAL_CACHEMAX")
#> NULL
```

### Algorithms

GDAL 3.11 added a registry of the algorithms its own command line is
built from. GDAL7 binds the registry rather than each utility, so what
`gdal` can do arrives with GDAL rather than with a GDAL7 release.

`gdal_has_algorithms()` says whether this build has any. Having the API
is not the same as having the algorithms: a GDAL can be built with them
turned off, and before 3.12 they registered themselves as a side effect
of being loaded, which a static link leaves out. The Windows build here
links GDAL statically, and answers FALSE today; Linux and macOS have the
algorithms.

``` r
gdal_algorithms()
#> [1] "convert"  "dataset"  "info"     "mdim"     "pipeline" "raster"   "vector"  
#> [8] "vsi"

head(gdal_algorithms("raster"), 12)
#>  [1] "as-features"  "aspect"       "blend"        "calc"         "clean-collar"
#>  [6] "clip"         "color-map"    "compare"      "contour"      "convert"     
#> [11] "create"       "edit"
```

Every algorithm describes itself, so there is no table of arguments in
this package to fall out of date.

``` r
info <- gdal_algorithm_info("raster reproject")
info$description
#> [1] "Reproject a raster dataset."

head(info$arguments[c("name", "type", "required")], 8)
#>           name         type required
#> 1         help      boolean    FALSE
#> 2     help-doc      boolean    FALSE
#> 3   json-usage      boolean    FALSE
#> 4       config  string_list    FALSE
#> 5 input-format  string_list    FALSE
#> 6  open-option  string_list    FALSE
#> 7        input dataset_list     TRUE
#> 8        quiet      boolean    FALSE
```

Arguments go in by name. An algorithm told to write to memory hands back
a dataset and touches no disk; one given a file name writes it, closes
it and hands back the path.

``` r
ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))

reprojected <- gdal_run("raster reproject", list(
  input = ds,
  output = "",
  "output-format" = "MEM",
  "dst-crs" = "EPSG:3857",
  bbox = c(-180, -85, 180, 85),
  "bbox-crs" = "EPSG:4326"
), progress = FALSE)

c(reprojected@raster_xsize, reprojected@raster_ysize)
#> [1] 19 19
substr(reprojected@projection, 1, 40)
#> [1] "PROJCS[\"WGS 84 / Pseudo-Mercator\",GEOGCS"

gdal_close(reprojected)
gdal_close(ds)
```

Pipelines work the same way, with the steps written as GDAL writes them:

``` r
piped <- gdal_run("raster pipeline", list(
  pipeline = paste(
    "read", system.file("extdata/overviews.tif", package = "GDAL7"),
    "! reproject --dst-crs EPSG:3857 --resampling average",
    "! write --output-format MEM streamed"
  )
), progress = FALSE)
#> Warning: GDAL: Clamping output bounds to (-20037508.342789,-20037508.342789) ->
#> (20037508.342789, 20037508.342789)

c(piped@raster_xsize, piped@raster_ysize)
#> [1] 497 497
gdal_close(piped)
```

A long algorithm draws a progress bar and stops on Ctrl-C.

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
gdal_release()[["release"]]
#> [1] "3.12.4"
gdal7_capabilities()
#>                              binding   gdal available
#> 1     dataset_mark_suppress_on_close 3.12.0      TRUE
#> 2 dataset_get_close_reports_progress 3.13.0     FALSE
#> 3                 dataset_as_mdarray 3.12.0      TRUE
#> 4             dataset_is_thread_safe 3.10.0      TRUE
#> 5    dataset_get_thread_safe_dataset 3.10.0      TRUE
```

## Code of Conduct

Please note that the GDAL7 project is released with a [Contributor Code
of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
