# GDAL enum tables

The `GDT_*` and `GCI_*` codes as named integer vectors, read out of the
GDAL in use rather than hard coded, so a build with types this package
has never heard of still reports them. These are what give meaning to
the integers from a band's `data_type` and `color_interpretation`.

## Usage

``` r
gdal_data_types()

gdal_color_interpretations()
```

## Value

A named integer vector.

## Examples

``` r
gdal_data_types()
#>  Unknown     Byte   UInt16    Int16   UInt32    Int32  Float32  Float64 
#>        0        1        2        3        4        5        6        7 
#>   CInt16   CInt32 CFloat32 CFloat64   UInt64    Int64     Int8  Float16 
#>        8        9       10       11       12       13       14       15 
#> CFloat16 
#>       16 
names(gdal_data_types())[gdal_data_types() == 3]
#> [1] "Int16"
```
