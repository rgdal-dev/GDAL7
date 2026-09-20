# Get one overview of a band

Get one overview of a band

## Usage

``` r
get_overview(x, index)
```

## Arguments

- x:

  A GDALRasterBand object

- index:

  Zero-based overview index, as GDAL numbers them. How many there are is
  `x@overview_count`, and their sizes are `x@overview_sizes`; which
  level a read will actually touch follows from those sizes and the
  output size asked for.

## Value

A GDALRasterBand object for the overview, which belongs to the same
dataset as `x`.
