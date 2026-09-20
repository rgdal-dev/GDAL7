# Summarise a dataset in one call

Everything `gdalinfo` reports that does not need a pass over the pixels,
fetched in a single call rather than one per property. Reached one
accessor at a time the same summary is seven round trips per band plus a
handful for the dataset, which over `/vsicurl/` is the difference
between immediate and sluggish.

## Usage

``` r
gdal_info(x)
```

## Arguments

- x:

  A GDALDataset, or a DSN string to open and close again.

## Value

A list with `driver`, `driver_long`, `size`, `bands` (the count),
`projection`, `geotransform`, `files`, `metadata`, and `band_info`, a
data frame with one row per band.

## Examples

``` r
info <- gdal_info(system.file("extdata/test.tif", package = "GDAL7"))
info$size
#> xsize ysize 
#>    20    10 
info$band_info
#>   band  type block_x block_y nodata scale offset     color unit overviews
#> 1    1 Int16      20      10 -32768    NA     NA      Gray              0
#> 2    2 Int16      20      10 -32768    NA     NA Undefined              0
```
