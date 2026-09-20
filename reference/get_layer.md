# Get a layer from a dataset

Get a layer from a dataset

## Usage

``` r
get_layer(x, layer = 1)
```

## Arguments

- x:

  A GDALDataset object.

- layer:

  The layer to take: its name, or its position counting from 1.

## Value

A GDALLayer object.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
get_layer(ds, 1)
#> <GDALLayer>
#>   Name:       places
#>   Geometry:   Point
#>   Features:   5
#>   CRS:        WGS 84
#>   Arrow:      native
gdal_close(ds)
```
