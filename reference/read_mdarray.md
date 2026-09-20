# Read from a multidimensional array

Reads a hyperslab: an origin, a count of values along each dimension,
and a step between them. With no arguments it reads the whole array.

## Usage

``` r
read_mdarray(x, start = NULL, count = NULL, step = NULL, nodata_as_na = TRUE)
```

## Arguments

- x:

  A GDALMDArray object

- start:

  Origin of the read, one value per dimension, in the array's own
  dimension order and counting from 1. Defaults to the start of each
  dimension.

- count:

  How many values to read along each dimension. Defaults to as many as
  `start` and `step` allow.

- step:

  Distance between values along each dimension, which may be negative to
  read backwards. Defaults to 1.

- nodata_as_na:

  Whether to turn the array's nodata value into `NA`. TRUE by default.

## Value

A numeric array, or a plain numeric vector for a one-dimensional array.

## Details

The result's `dim` is the reverse of the array's own dimension order, so
a `(time, lat, lon)` array reads into an R array indexed
`[lon, lat, time]`. That is the order ncdf4 and RNetCDF use, and it is
also the order the values already arrive in, so nothing is moved to
produce it. The names on `dim` say which is which. A one-dimensional
array comes back as a plain vector.

## Examples

``` r
path <- system.file("extdata/multidim.zarr", package = "GDAL7")
ds <- gdal_open(path, multidim = TRUE)
arr <- open_mdarray(get_root_group(ds), "temperature")

dim(read_mdarray(arr))
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
#> 

gdal_close(ds)
```
