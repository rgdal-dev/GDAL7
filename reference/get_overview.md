# Get one overview of a band

Overview levels are numbered from 1, the largest reduced level, so
`level` is the row of `x@overview_sizes` that describes it. Level 0 is
the band itself at full resolution, which is what GDAL numbers -1 where
it has a number for it. Underneath, `level` is GDAL's zero-based
overview index plus one. A string passed through to GDAL unchanged, such
as the open option `OVERVIEW_LEVEL`, keeps GDAL's own numbering.

## Usage

``` r
get_overview(x, level)
```

## Arguments

- x:

  A GDALRasterBand object

- level:

  Overview level, from 0 (the band itself) to `x@overview_count`. Which
  level a read will actually touch follows from `x@overview_sizes` and
  the output size asked for.

## Value

A GDALRasterBand object for the overview, which belongs to the same
dataset as `x`. Level 0 returns `x`.
