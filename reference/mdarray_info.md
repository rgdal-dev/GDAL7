# Everything about an array in one call

The multidimensional counterpart of
[`gdal_info()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_info.md):
name, type, unit, nodata, scaling, coordinate reference system,
dimensions and attributes, fetched together rather than one accessor at
a time.

## Usage

``` r
mdarray_info(x, ...)
```

## Arguments

- x:

  A GDALMDArray object

- ...:

  Arguments passed on to methods.

## Value

A list.
