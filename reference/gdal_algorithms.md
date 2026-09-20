# List GDAL's algorithms

The registry is a tree: `gdal_algorithms()` gives the top level, and
passing one of those names gives what is under it. These are the same
names the `gdal` command line uses.

## Usage

``` r
gdal_algorithms(path = NULL)
```

## Arguments

- path:

  An algorithm's name, as a string such as `"raster"` or
  `"raster reproject"`, or a character vector of its parts. NULL, the
  default, lists the top level.

## Value

A character vector of names, empty when the algorithm has nothing under
it.

## Examples

``` r
if (gdal_has_algorithms()) {
  gdal_algorithms()
  gdal_algorithms("raster")
}
#>  [1] "as-features"     "aspect"          "blend"           "calc"           
#>  [5] "clean-collar"    "clip"            "color-map"       "compare"        
#>  [9] "contour"         "convert"         "create"          "edit"           
#> [13] "fill-nodata"     "footprint"       "hillshade"       "index"          
#> [17] "info"            "mosaic"          "neighbors"       "nodata-to-alpha"
#> [21] "overview"        "pansharpen"      "pipeline"        "pixel-info"     
#> [25] "polygonize"      "proximity"       "reclassify"      "reproject"      
#> [29] "resize"          "rgb-to-palette"  "roughness"       "scale"          
#> [33] "select"          "set-type"        "sieve"           "slope"          
#> [37] "stack"           "tile"            "tpi"             "tri"            
#> [41] "unscale"         "update"          "viewshed"        "zonal-stats"    
```
