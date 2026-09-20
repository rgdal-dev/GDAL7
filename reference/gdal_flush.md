# Write out everything held in memory

A dataset open for writing holds its last blocks in memory until it is
closed. This puts them on disk without closing it, which is what makes a
file readable by something else while it is still being built.

## Usage

``` r
gdal_flush(x, ...)
```

## Arguments

- x:

  A GDALDataset.

- ...:

  Arguments passed on to methods.

## Value

`x`, invisibly.
