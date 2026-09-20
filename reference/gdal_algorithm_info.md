# Describe one of GDAL's algorithms

What the algorithm does, what it is called, and every argument it takes
with its type and whether it is required. This is the reference for what
to put in the `args` of
[`gdal_run()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_run.md),
read out of GDAL itself rather than copied into this package.

## Usage

``` r
gdal_algorithm_info(path)
```

## Arguments

- path:

  The algorithm, as for
  [`gdal_algorithms()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_algorithms.md).

## Value

A list: `name`, `description`, `long_description`, `url`,
`sub_algorithms`, and `arguments`, a data frame with one row per
argument. Its `choices` column is a list, holding the allowed values of
the arguments that have a fixed set and nothing for the rest.

## Examples

``` r
if (gdal_has_algorithms()) {
  info <- gdal_algorithm_info("raster reproject")
  info$description
  head(info$arguments[c("name", "type", "required")])
}
#>           name        type required
#> 1         help     boolean    FALSE
#> 2     help-doc     boolean    FALSE
#> 3   json-usage     boolean    FALSE
#> 4       config string_list    FALSE
#> 5 input-format string_list    FALSE
#> 6  open-option string_list    FALSE
```
