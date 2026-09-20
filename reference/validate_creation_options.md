# Check creation options against a driver

GDAL's own check of a set of options against the driver's option list,
which is what
[`gdal_create()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_create.md)
and
[`gdal_create_copy()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_create_copy.md)
run before creating anything. Use it to ask the question without the
answer being an error.

## Usage

``` r
validate_creation_options(x, options)
```

## Arguments

- x:

  A GDALDriver, or a driver's short name.

- options:

  Creation options, as a named character vector or list, or already
  written as `"KEY=VALUE"` strings.

## Value

TRUE or FALSE.

## Examples

``` r
validate_creation_options("GTiff", c(COMPRESS = "DEFLATE"))
#> [1] TRUE
validate_creation_options("GTiff", c(COMPRES = "DEFLATE"))
#> [1] FALSE
```
