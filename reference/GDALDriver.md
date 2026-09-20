# GDALDriver class

Represents a GDAL format driver, such as GTiff or GPKG. What a driver is
called is a property of it: `short_name` is the name GDAL is asked for
it by, such as `"GTiff"`, `long_name` is what it calls itself, and
`help_topic` is the URL of its page in GDAL's own documentation.

## Usage

``` r
GDALDriver(.ptr)
```

## Arguments

- .ptr:

  Internal. External pointer to the underlying GDAL object.

## Examples

``` r
drv <- gdal_get_driver_by_name("GTiff")
drv@short_name
#> [1] "GTiff"
drv@long_name
#> [1] "GeoTIFF"
```
