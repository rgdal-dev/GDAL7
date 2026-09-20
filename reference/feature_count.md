# Count the features of a layer

Count the features of a layer

## Usage

``` r
feature_count(x, force = TRUE)
```

## Arguments

- x:

  A GDALLayer object.

- force:

  Count them by reading the layer when the driver does not know the
  answer already.

## Value

The number of features, or `NA` when the driver would have to scan the
layer and `force` is `FALSE`. Any filter set on the layer applies.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
feature_count(get_layer(ds, 1))
#> [1] 5
gdal_close(ds)
```
