# Whether this GDAL has algorithms to run

The algorithm registry arrived in GDAL 3.11. Everything in
[`gdal_run()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_run.md),
[`gdal_algorithms()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_algorithms.md)
and
[`gdal_algorithm_info()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_algorithm_info.md)
depends on it, and raises an error naming the release when it is not
there.

## Usage

``` r
gdal_has_algorithms()
```

## Value

TRUE or FALSE.

## Details

Having the API is not the same as having the algorithms. A GDAL can be
built with them turned off, and before GDAL 3.12 each algorithm
registered itself as a side effect of being loaded, which a static link
leaves out, so a statically linked GDAL 3.11 answers from an empty
registry. This checks both, so TRUE means there is something to run.

## Examples

``` r
gdal_has_algorithms()
#> [1] TRUE
```
