# What a driver will accept

Each driver describes its own creation and open options, in an XML
document GDAL also validates against, so this is read out of GDAL rather
than written down here. `type` is GDAL's own vocabulary: `"int"`,
`"float"`, `"string"`, `"boolean"`, `"string-select"` for one of a fixed
set.

## Usage

``` r
driver_options(x, which = c("creation", "open"))
```

## Arguments

- x:

  A GDALDriver, or a driver's short name such as `"GTiff"`.

- which:

  `"creation"` for the options
  [`gdal_create()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_create.md)
  and
  [`gdal_create_copy()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_create_copy.md)
  take, or `"open"` for the ones
  [`gdal_open()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_open.md)
  does.

## Value

A data frame with one row per option: `name`, `type`, `description`,
`default`, `min`, `max`, `required`, `scope`, and `choices`, a list
column holding the allowed values of the options that have a fixed set
and nothing for the rest.

## Examples

``` r
options <- driver_options("GTiff")
options[options$name %in% c("COMPRESS", "TILED", "BLOCKXSIZE"),
         c("name", "type", "default")]
#>          name          type default
#> 1    COMPRESS string-select    <NA>
#> 16      TILED       boolean      NO
#> 20 BLOCKXSIZE           int     256

# What COMPRESS will take on this build.
options$choices[[which(options$name == "COMPRESS")]]
#>  [1] "NONE"         "LZW"          "PACKBITS"     "JPEG"         "CCITTRLE"    
#>  [6] "CCITTFAX3"    "CCITTFAX4"    "DEFLATE"      "LZMA"         "ZSTD"        
#> [11] "WEBP"         "LERC"         "LERC_DEFLATE" "LERC_ZSTD"   
```
