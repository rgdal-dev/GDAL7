# A view of a dataset that several threads may read at once

GDAL 3.10 can hand out a thread-safe view of an open dataset. Reads
through the view may run on several threads at once, which is what lets
GDAL parallelise internally; the dataset it came from is unchanged and
must stay open for as long as the view is used, which GDAL7 enforces.

## Usage

``` r
get_thread_safe_dataset(x, ...)

is_thread_safe(x, ...)
```

## Arguments

- x:

  A GDALDataset.

- ...:

  Arguments passed on to methods.

## Value

`get_thread_safe_dataset()` returns a GDALDataset. `is_thread_safe()`
returns TRUE or FALSE.

## Details

Only raster access is supported, which is GDAL's own limit rather than
one this package adds.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))
is_thread_safe(ds)
#> [1] FALSE

safe <- get_thread_safe_dataset(ds)
is_thread_safe(safe)
#> [1] TRUE
identical(read_raster(safe, out_size = c(4, 4)),
          read_raster(ds, out_size = c(4, 4)))
#> [1] TRUE

gdal_close(safe)
gdal_close(ds)
```
