# The bounding box of a layer

The bounding box of a layer

## Usage

``` r
get_extent(x, force = TRUE)
```

## Arguments

- x:

  A GDALLayer object.

- force:

  Compute it by reading the layer when the driver does not know it
  already.

## Value

A named numeric vector: `xmin`, `ymin`, `xmax`, `ymax`. All `NA` for an
empty layer, or for one whose extent is not known and `force` is
`FALSE`.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
get_extent(get_layer(ds, 1))
#>     xmin     ymin     xmax     ymax 
#> 115.8605 -42.8826 151.2093 -12.4634 
gdal_close(ds)
```
