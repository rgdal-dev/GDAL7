# Multidimensional arrays

GDAL has two models of a raster. The classic one is a stack of
two-dimensional bands, and a netCDF or Zarr variable with a time or
depth axis reaches it as hundreds of subdatasets or bands, with the axes
flattened into names. The multidimensional model, added in GDAL 3.1,
keeps the source’s own shape: groups that hold arrays, arrays that have
named dimensions, dimensions that have coordinate variables, and
attributes everywhere.

GDAL7 binds the multidimensional model directly, as S7 classes with
properties, in the same way as the classic one. Nothing is translated
through the classic model on the way, and nothing is read until it is
asked for. This article walks through it with a small Zarr store that
ships with the package, so every line below runs as written.

``` r

library(GDAL7)
path <- system.file("extdata/multidim.zarr", package = "GDAL7")
```

## Opening: the same file, two models

Opened the classic way, the Zarr store is a dataset whose array has
become bands:

``` r

classic <- gdal_open(path)
classic@raster_count
#> [1] 3
gdal_close(classic)
```

Opened with `multidim = TRUE`, it is a tree. The root group is the way
in:

``` r

ds <- gdal_open(path, multidim = TRUE)
root <- get_root_group(ds)
root
#> <GDALGroup>
#>   Name: /
#>   Arrays (4): lon, temperature, lat, time
root@mdarray_names
#> [1] "lon"         "temperature" "lat"         "time"
root@group_names
#> character(0)
```

A group’s arrays are opened by name, and a deeper one by its full path
from the root, such as `"/ocean/temperature"`. Subgroups are opened with
[`open_group()`](https://rgdal-dev.github.io/GDAL7/reference/open_group.md).

``` r

temperature <- open_mdarray(root, "temperature")
temperature
#> <GDALMDArray>
#>   Name: temperature
#>   Type: Float64
#>   Dimensions: time=3, lat=4, lon=5
#>   Unit: degC
#>   NoData: -999
```

## What an array knows about itself

Everything an array says about itself is a property, read from GDAL when
it is asked for.
[`mdarray_info()`](https://rgdal-dev.github.io/GDAL7/reference/mdarray_info.md)
collects the lot in one call:

``` r

str(mdarray_info(temperature))
#> List of 10
#>  $ name      : chr "temperature"
#>  $ full_name : chr "/temperature"
#>  $ data_type : chr "Float64"
#>  $ unit      : chr "degC"
#>  $ nodata    : num -999
#>  $ scale     : num 2
#>  $ offset    : num 0.5
#>  $ crs       : chr NA
#>  $ dimensions:'data.frame':  3 obs. of  5 variables:
#>   ..$ name     : chr [1:3] "time" "lat" "lon"
#>   ..$ size     : num [1:3] 3 4 5
#>   ..$ type     : chr [1:3] "TEMPORAL" "HORIZONTAL_Y" "HORIZONTAL_X"
#>   ..$ direction: chr [1:3] "" "NORTH" "EAST"
#>   ..$ indexed  : logi [1:3] TRUE TRUE TRUE
#>  $ attributes:List of 3
#>   ..$ coordinates: chr "lat lon"
#>   ..$ long_name  : chr "air temperature"
#>   ..$ valid_range: num [1:2] -50 50
```

The dimensions are a data frame, in GDAL’s order, slowest varying first.
That is the order the format declares them in and the order
`gdal mdim info` prints:

``` r

temperature@dimensions
#>   name size         type direction indexed
#> 1 time    3     TEMPORAL              TRUE
#> 2  lat    4 HORIZONTAL_Y     NORTH    TRUE
#> 3  lon    5 HORIZONTAL_X      EAST    TRUE
```

`type` and `direction` are what the format says about each dimension,
and they are how GDAL picks the X and Y of a raster later on. `indexed`
says whether the dimension has a coordinate variable, and
`dimension_values` reads them all:

``` r

temperature@dimension_values
#> $time
#> [1] 0 1 2
#> 
#> $lat
#> [1] -40 -41 -42 -43
#> 
#> $lon
#> [1] 140 141 142 143 144
```

`coordinate_variables` is the related, more general question: which
arrays the format names as this one’s coordinates. For a regular grid
the answer is the same arrays; for a swath it is two-dimensional
latitude and longitude arrays that index no dimension.

``` r

vapply(temperature@coordinate_variables, function(x) x@name, "")
#> [1] "lat" "lon"
```

The array’s own annotations are in `attributes`, and the ones GDAL
interprets have properties of their own:

``` r

temperature@attributes
#> $coordinates
#> [1] "lat lon"
#> 
#> $long_name
#> [1] "air temperature"
#> 
#> $valid_range
#> [1] -50  50
temperature@unit_type
#> [1] "degC"
temperature@nodata_value
#> [1] -999
c(scale = temperature@scale, offset = temperature@offset)
#>  scale offset 
#>    2.0    0.5
```

## Reading

[`read_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/read_mdarray.md)
with no arguments reads the whole array:

``` r

values <- read_mdarray(temperature)
dim(values)
#>  lon  lat time 
#>    5    4    3
values[, , 1]
#>      [,1] [,2] [,3] [,4]
#> [1,]    1    6   11   16
#> [2,]    2    7   12   17
#> [3,]    3   NA   13   18
#> [4,]    4    9   14   19
#> [5,]    5   10   15   20
```

The result’s `dim` is the reverse of the array’s dimension order, so a
`(time, lat, lon)` array reads into `[lon, lat, time]`. That is the
order ncdf4 and RNetCDF give, and it is the order the values arrive in
from GDAL, so the buffer becomes the R array with nothing moved. The
names on `dim` say which is which.

The nodata value, here -999, has become `NA`; `nodata_as_na = FALSE`
keeps it. The scale and offset are **not** applied: the values are the
stored ones, and the physical ones are a step away:

``` r

range(values * temperature@scale + temperature@offset, na.rm = TRUE)
#> [1]   2.5 120.5
```

A read can be a hyperslab: an origin, a count along each dimension, and
a step. All three are in GDAL’s dimension order, with the origin
counting from 1 as R does. The second time step, every second longitude:

``` r

read_mdarray(temperature, start = c(2, 1, 1), count = c(1, 4, 3),
             step = c(1, 1, 2))
#> , , 1
#> 
#>      [,1] [,2] [,3] [,4]
#> [1,]   21   26   31   36
#> [2,]   23   28   33   38
#> [3,]   25   30   35   40
```

A negative step reads backwards. Latitude in this array runs from -40 to
-43; reading it the other way round puts the south first:

``` r

read_mdarray(temperature, start = c(1, 4, 1), count = c(1, 4, 5),
             step = c(1, -1, 1))
#> , , 1
#> 
#>      [,1] [,2] [,3] [,4]
#> [1,]   16   11    6    1
#> [2,]   17   12    7    2
#> [3,]   18   13   NA    3
#> [4,]   19   14    9    4
#> [5,]   20   15   10    5
```

## Views

A view is a slice, a reordering or a transposition in GDAL’s own syntax,
modelled on numpy’s. It reads nothing; it is another `GDALMDArray`, with
the same properties, that reads through to the original. Indices in a
view count from 0, as they do in GDAL:

``` r

first <- get_view(temperature, "[0,:,:]")
first@dimensions
#>   name size         type direction indexed
#> 1  lat    4 HORIZONTAL_Y     NORTH    TRUE
#> 2  lon    5 HORIZONTAL_X      EAST    TRUE

flipped <- get_view(temperature, "[:,::-1,:]")
flipped@dimensions$name
#> [1] "time"              "subset_lat_3_-1_4" "lon"
flipped@dimension_values[[2]]
#> [1] -43 -42 -41 -40
```

A sliced dimension is renamed to say what was done to it, as above, and
its coordinate variable is sliced with it.

A view can be taken of a view, and a dimension is dropped by indexing it
with a single number, as `[0,:,:]` does to time. A range is
`start:stop:step`, with `stop` excluded as in Python, so
`"[:,0:2,1:5:2]"` is the first two latitudes and every second longitude
from the second.

## Back to a classic raster

A two-dimensional array is a raster, and
[`as_classic_dataset()`](https://rgdal-dev.github.io/GDAL7/reference/as_classic_dataset.md)
turns one into a `GDALDataset`, so the rest of the package applies to
it. The geotransform is worked out from the coordinate variables:

``` r

slice <- as_classic_dataset(first)
slice@geotransform
#>        origin_x     pixel_width    row_rotation        origin_y column_rotation 
#>           139.5             1.0             0.0           -39.5             0.0 
#>    pixel_height 
#>            -1.0
c(slice@raster_xsize, slice@raster_ysize)
#> [1] 5 4
matrix(read_raster(slice)[[1]], slice@raster_xsize)
#>      [,1] [,2] [,3] [,4]
#> [1,]    1    6   11   16
#> [2,]    2    7   12   17
#> [3,]    3 -999   13   18
#> [4,]    4    9   14   19
#> [5,]    5   10   15   20
```

[`read_raster()`](https://rgdal-dev.github.io/GDAL7/reference/read_raster.md)
gives the band’s stored values, nodata included, in the order
[`read_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/read_mdarray.md)
would: X fastest.

X and Y are chosen from the dimensions’ `type`, falling back to the last
two dimensions; `x_dim` and `y_dim` say otherwise. The reverse direction
is
[`as_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/as_mdarray.md),
which presents a classic band as a two-dimensional array.

## Chunks

A chunked store is fastest read a whole chunk at a time, and
`block_size` is the chunk shape, in GDAL’s order. This store has one
time step per chunk:

``` r

temperature@block_size
#> time  lat  lon 
#>    1    4    5
```

[`advise_read()`](https://rgdal-dev.github.io/GDAL7/reference/advise_read.md)
tells the driver what is about to be read. For Zarr that means every
chunk in the slice is fetched and decoded on GDAL’s threads at once,
rather than one after the other as the read reaches it. It matters most
for a remote store, where each chunk is a request:

``` r

advise_read(temperature, start = c(1, 1, 1), count = c(3, 4, 5))
dim(read_mdarray(temperature, start = c(1, 1, 1), count = c(3, 4, 5)))
#>  lon  lat time 
#>    5    4    3
```

With the altarr package installed,
[`as_altarr()`](https://rgdal-dev.github.io/GDAL7/reference/as_altarr.md)
makes a lazy R array that reads chunks only when they are indexed, in
batches, with each batch advised first. Built from a path, it keeps the
path and opens the dataset on its first read, in this session or a later
one:

``` r

lazy <- as_altarr(path, array = "temperature")
dim(lazy)
#> [1] 5 4 3
lazy[, , 3]
#>      [,1] [,2] [,3] [,4]
#> [1,]   41   46   51   56
#> [2,]   42   47   52   57
#> [3,]   43   48   53   58
#> [4,]   44   49   54   59
#> [5,]   45   50   55   60
```

## GDAL’s multidimensional programs

`gdal mdim info`, `convert`, `mosaic` and the rest are algorithms in
GDAL’s registry, and
[`gdal_run()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_run.md)
runs them; `gdal_algorithms("mdim")` lists what this GDAL has. They need
GDAL 3.11 for the registry and 3.12 for `mosaic`, so the code here asks
first:

``` r

has_mosaic <- gdal_has_algorithms() && "mosaic" %in% gdal_algorithms("mdim")
has_mosaic
#> [1] TRUE
```

``` r

report <- gdal_run("mdim info", list(input = path), progress = FALSE)
cat(substr(report, 1, 300), "...\n")
#> {
#>   "type": "group",
#>   "driver": "Zarr",
#>   "name": "/",
#>   "dimensions": [
#>     {
#>       "name": "lat",
#>       "full_name": "/lat",
#>       "size": 4,
#>       "type": "HORIZONTAL_Y",
#>       "direction": "NORTH",
#>       "indexing_variable": "/lat"
#>     },
#>     {
#>       "name": "lon",
#>       "full_name": "/lon",
#>    ...
```

A mosaic puts back together an array that was split into files, which is
how a long model run is usually published: one file per month, or per
day. To show it here the store is first split into one Zarr per time
step with `gdal mdim convert`:

``` r

dir <- tempfile()
dir.create(dir)
pieces <- character(0)
for (t in 0:2) {
  piece <- file.path(dir, sprintf("step%d.zarr", t))
  gdal_run("mdim convert", list(
    input = path, output = piece, "output-format" = "Zarr",
    subset = sprintf("time(%d,%d)", t, t)
  ), progress = FALSE)
  pieces <- c(pieces, piece)
}
basename(pieces)
#> [1] "step0.zarr" "step1.zarr" "step2.zarr"
```

`gdal mdim mosaic` then writes a multidimensional VRT that stitches them
back together along `time`. The VRT is a small XML file that holds no
values, only where each piece goes:

``` r

vrt <- file.path(dir, "mosaic.vrt")
gdal_run("mdim mosaic", list(input = pieces, output = vrt), progress = FALSE)

mosaic <- gdal_open(vrt, multidim = TRUE)
stitched <- open_mdarray(get_root_group(mosaic), "temperature")
stitched@dimensions
#>   name size type direction indexed
#> 1 time    3                   TRUE
#> 2  lat    4                   TRUE
#> 3  lon    5                   TRUE
identical(read_mdarray(stitched), values)
#> [1] TRUE
```

The same values, read from three files through one array, and the files
were not copied: the VRT points at them. The same can be done with files
on a web server or object storage through `/vsicurl/` or `/vsis3/`
paths, which is how a model run published one file per month becomes one
array.

## Further

- [Icechunk](https://rgdal-dev.github.io/GDAL7/articles/icechunk.md):
  versioned Zarr repositories, with branches and tags, through GDAL’s
  Icechunk driver.
- GDAL’s own documentation of the model:
  <https://gdal.org/en/latest/user/multidim_raster_data_model.html>.
