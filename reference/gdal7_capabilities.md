# What this build of GDAL7 can reach

Some bindings call GDAL functions that are newer than GDAL7's own
minimum. Those bindings always exist, so that loading the package never
depends on which GDAL it was built against, but calling one that the
GDAL in use is too old for raises an error naming the release it needs.
This is how to ask first.

## Usage

``` r
gdal7_capabilities()
```

## Value

A data frame with one row per guarded binding: `binding`, the GDAL
release it needs (`gdal`), and whether this build has it (`available`).

## Details

A binding not listed here needs nothing newer than GDAL7's minimum and
is always available.

## Examples

``` r
gdal7_capabilities()
#>                              binding   gdal available
#> 1     dataset_mark_suppress_on_close 3.12.0      TRUE
#> 2 dataset_get_close_reports_progress 3.13.0     FALSE
#> 3                 dataset_as_mdarray 3.12.0      TRUE
#> 4             dataset_is_thread_safe 3.10.0      TRUE
#> 5    dataset_get_thread_safe_dataset 3.10.0      TRUE
```
