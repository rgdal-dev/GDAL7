# GDALRasterBand class

Represents a raster band within a GDAL dataset. Its properties are read
from GDAL each time, and the ones a dataset open for writing can change
are settable:

## Usage

``` r
GDALRasterBand(.ptr)
```

## Arguments

- .ptr:

  Internal. External pointer to the underlying GDAL object.

## Details

- `xsize`, `ysize`, `band_number`, `block_size`, read only.

- `data_type`, its GDAL code, and `data_type_name`, read only.

- `nodata_value`, `scale`, `offset`, `unit_type`, settable.

- `color_interpretation`, settable, and `color_interpretation_name`.

- `overview_count` and `overview_sizes`, read only.

A `nodata_value` of NULL means the band has none, and assigning NULL
takes the value off the band, which is a different thing from setting it
to NaN. Scale and offset are how a band of integers carries real values:
the value meant is `raw * scale + offset`, which GDAL records but does
not apply, so
[`read_raster()`](https://rgdal-dev.github.io/GDAL7/reference/read_raster.md)
returns the raw numbers.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))
band <- get_raster_band(ds, 1)

c(band@xsize, band@ysize)
#> [1] 20 10
band@data_type_name
#> [1] "Int16"
band@block_size
#>  x  y 
#> 20 10 

gdal_close(ds)
```
