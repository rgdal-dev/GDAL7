# Read a vector layer into a data frame

The whole layer in one call, through GDAL's column-oriented Arrow API
rather than feature by feature. Geometry arrives as WKB, in a list
column of raw vectors, which is what every other R geometry package can
read.

## Usage

``` r
read_vector(x, layer = 1, where = NULL, bbox = NULL, options = NULL)
```

## Arguments

- x:

  A GDALLayer object, or a GDALDataset, or a path or connection string
  to open.

- layer:

  When `x` is a dataset or a path: which layer, by name or by position.
  Ignored when `x` is already a layer.

- where:

  An SQL WHERE clause to apply first, or `NULL`.

- bbox:

  Numeric of length 4, `c(xmin, ymin, xmax, ymax)`, to apply first, or
  `NULL`.

- options:

  Character vector of `KEY=VALUE` options passed to
  `OGR_L_GetArrowStream`.

## Value

A data frame.

## Examples

``` r
read_vector(system.file("extdata/test.gpkg", package = "GDAL7"))
#>   fid      name population elevation
#> 1   1    Hobart     247086        17
#> 2   2 Melbourne    5031195        31
#> 3   3    Sydney    5312163        19
#> 4   4     Perth    2141834        15
#> 5   5    Darwin     147255        31
#>                                                                                 geom
#> 1 01, 01, 00, 00, 00, d5, 09, 68, 22, 6c, 6a, 62, 40, 8c, b9, 6b, 09, f9, 70, 45, c0
#> 2 01, 01, 00, 00, 00, e2, 58, 17, b7, d1, 1e, 62, 40, 47, 03, 78, 0b, 24, e8, 42, c0
#> 3 01, 01, 00, 00, 00, b1, e1, e9, 95, b2, e6, 62, 40, e5, 61, a1, d6, 34, ef, 40, c0
#> 4 01, 01, 00, 00, 00, 50, 8d, 97, 6e, 12, f7, 5c, 40, 16, fb, cb, ee, c9, f3, 3f, c0
#> 5 01, 01, 00, 00, 00, ec, 2f, bb, 27, 0f, 5b, 60, 40, cc, ee, c9, c3, 42, ed, 28, c0
```
