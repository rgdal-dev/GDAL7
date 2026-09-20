# Get a raster band from a dataset

A band is taken by number, so this is a function rather than a property.
What the band then knows about itself is a property of the band; see
[GDALRasterBand](https://rgdal-dev.github.io/GDAL7/reference/GDALRasterBand.md).

## Usage

``` r
get_raster_band(x, nBand)
```

## Arguments

- x:

  A GDALDataset object

- nBand:

  Band number, 1-indexed

## Value

A GDALRasterBand object

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))
get_raster_band(ds, 1)
#> <GDALRasterBand>
#>   Band:       1
#>   Size:       20 x 10
#>   Type:       Int16
#>   Block size: 20 x 10
#>   NoData:     -32768
#>   Color:      Gray
gdal_close(ds)
```
