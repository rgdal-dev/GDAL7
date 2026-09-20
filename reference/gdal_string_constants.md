# GDAL's string constants

The metadata and capability keys GDAL declares: driver metadata
(`DMD_*`), driver capabilities (`DCAP_*`), dataset capabilities
(`GDsC*`) and dimension types (`DIM_TYPE_*`). These are the keys to pass
to
[`get_metadata_item()`](https://rgdal-dev.github.io/GDAL7/reference/get_metadata_item.md)
and
[`test_capability()`](https://rgdal-dev.github.io/GDAL7/reference/test_capability.md).

## Usage

``` r
gdal_string_constants(prefix = NULL)
```

## Arguments

- prefix:

  Optional. Keep only the constants whose names start with this.

## Value

A named character vector.

## Examples

``` r
head(gdal_string_constants("DCAP_"))
#>                                DCAP_OPEN 
#>                              "DCAP_OPEN" 
#>                              DCAP_CREATE 
#>                            "DCAP_CREATE" 
#>             DCAP_CREATE_MULTIDIMENSIONAL 
#>           "DCAP_CREATE_MULTIDIMENSIONAL" 
#>                          DCAP_CREATECOPY 
#>                        "DCAP_CREATECOPY" 
#>   DCAP_CREATE_ONLY_VISIBLE_AT_CLOSE_TIME 
#> "DCAP_CREATE_ONLY_VISIBLE_AT_CLOSE_TIME" 
#>         DCAP_CREATECOPY_MULTIDIMENSIONAL 
#>       "DCAP_CREATECOPY_MULTIDIMENSIONAL" 
```
