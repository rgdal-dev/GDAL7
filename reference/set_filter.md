# Restrict which features a layer returns

Both filters are set on the layer and stay set. They apply to everything
read afterwards, including
[`feature_count()`](https://rgdal-dev.github.io/GDAL7/reference/feature_count.md)
and
[`read_vector()`](https://rgdal-dev.github.io/GDAL7/reference/read_vector.md).
Passing `NULL` clears the filter.

## Usage

``` r
set_filter(x, where, bbox)
```

## Arguments

- x:

  A GDALLayer object. A clause the driver cannot make sense of is not
  reported here: most drivers hand it to their own engine when the layer
  is next used, so a bad clause surfaces as a GDAL warning from
  [`feature_count()`](https://rgdal-dev.github.io/GDAL7/reference/feature_count.md)
  or
  [`read_vector()`](https://rgdal-dev.github.io/GDAL7/reference/read_vector.md).

- where:

  An SQL WHERE clause without the WHERE, or `NULL` to clear it.

- bbox:

  Numeric of length 4, `c(xmin, ymin, xmax, ymax)` in the layer's own
  coordinates, or `NULL` to clear it.

## Value

The layer, invisibly.

## Details

A spatial filter is what makes a large layer cheap: a driver with a
spatial index uses it rather than reading every feature.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
layer <- get_layer(ds, 1)
set_filter(layer, where = "population > 1e6")
feature_count(layer)
#> [1] 3
gdal_close(ds)
```
