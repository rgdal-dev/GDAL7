# Every driver this GDAL has

The whole table in one call rather than one call per property per
driver, which on a typical build is the difference between one round
trip and about fourteen hundred.

## Usage

``` r
gdal_drivers(capabilities = NULL)
```

## Arguments

- capabilities:

  Optional character vector of capabilities every returned driver must
  have, named as GDAL names them: `"DCAP_RASTER"`, `"DCAP_VECTOR"`,
  `"DCAP_MULTIDIM_RASTER"`, `"DCAP_CREATE"`, `"DCAP_CREATECOPY"`,
  `"DCAP_VIRTUALIO"`.

## Value

A data frame with one row per driver: `short_name`, `long_name`,
`raster`, `vector`, `multidim`, `create`, `copy`, `vsi` and
`extensions`.

## Examples

``` r
drivers <- gdal_drivers()
nrow(drivers)
#> [1] 210

# The formats that can be written from nothing, rather than only copied.
head(gdal_drivers("DCAP_CREATE")$short_name, 12)
#>  [1] "GTiff"    "VRT"      "NITF"     "HFA"      "MEM"      "FITS"    
#>  [7] "BMP"      "PCIDSK"   "PCRaster" "ILWIS"    "Leveller" "Terragen"
```
