# GDAL's integer constants

The enumerators GDAL declares: data types (`GDT_*`), access modes
(`GA_*`), colour interpretations (`GCI_*`), resampling algorithms
(`GRA_*`, `GRIORA_*`), open flags (`OF_*`), error classes (`CE_*`,
`CPLE_*`) and the rest. They are returned as one named vector rather
than exported one by one, so that GDAL7 adds two names to the search
path instead of two hundred.

## Usage

``` r
gdal_constants(prefix = NULL)
```

## Arguments

- prefix:

  Optional. Keep only the constants whose names start with this.

## Value

A named integer vector.

## Details

A constant that the GDAL in use is too old to declare is absent from the
vector. See
[`gdal7_capabilities()`](https://rgdal-dev.github.io/GDAL7/reference/gdal7_capabilities.md)
for the same question about bindings.

## Examples

``` r
head(gdal_constants("GDT_"))
#> GDT_Unknown    GDT_Byte    GDT_Int8  GDT_UInt16   GDT_Int16  GDT_UInt32 
#>           0           1          14           2           3           4 
gdal_constants("GA_")
#> GA_ReadOnly   GA_Update 
#>           0           1 
```
