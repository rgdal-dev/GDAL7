# A coordinate reference system as WKT

The conversion a dataset's `crs` property does, on its own, for checking
a CRS string or for seeing what one says.

## Usage

``` r
crs_to_wkt(
  crs,
  format = c("WKT2", "WKT2_2019", "WKT2_2015", "WKT1"),
  multiline = FALSE
)
```

## Arguments

- crs:

  A coordinate reference system, in any form GDAL reads.

- format:

  `"WKT2"`, or `"WKT2_2015"` or `"WKT2_2019"` for a particular edition,
  or `"WKT1"`.

- multiline:

  Whether to lay it out over several lines, which is how to read one
  rather than how to store it.

## Value

A WKT string.

## Details

WKT2 is the default because WKT1 cannot carry everything a modern CRS
holds: a projection WKT2 names exactly comes back out of WKT1 as
`PROJCS["unknown"]`. WKT1 is still what GDAL writes into a file and what
the `projection` property returns, so it is here for comparing against
those.

## Examples

``` r
substr(crs_to_wkt("EPSG:4326"), 1, 30)
#> [1] "GEOGCRS[\"WGS 84\",ENSEMBLE[\"Wor"
substr(crs_to_wkt("EPSG:4326", "WKT1"), 1, 30)
#> [1] "GEOGCS[\"WGS 84\",DATUM[\"WGS_198"

cat(crs_to_wkt("EPSG:3857", multiline = TRUE))
#> PROJCRS["WGS 84 / Pseudo-Mercator",
#>     BASEGEOGCRS["WGS 84",
#>         ENSEMBLE["World Geodetic System 1984 ensemble",
#>             MEMBER["World Geodetic System 1984 (Transit)"],
#>             MEMBER["World Geodetic System 1984 (G730)"],
#>             MEMBER["World Geodetic System 1984 (G873)"],
#>             MEMBER["World Geodetic System 1984 (G1150)"],
#>             MEMBER["World Geodetic System 1984 (G1674)"],
#>             MEMBER["World Geodetic System 1984 (G1762)"],
#>             MEMBER["World Geodetic System 1984 (G2139)"],
#>             MEMBER["World Geodetic System 1984 (G2296)"],
#>             ELLIPSOID["WGS 84",6378137,298.257223563,
#>                 LENGTHUNIT["metre",1]],
#>             ENSEMBLEACCURACY[2.0]],
#>         PRIMEM["Greenwich",0,
#>             ANGLEUNIT["degree",0.0174532925199433]],
#>         ID["EPSG",4326]],
#>     CONVERSION["Popular Visualisation Pseudo-Mercator",
#>         METHOD["Popular Visualisation Pseudo Mercator",
#>             ID["EPSG",1024]],
#>         PARAMETER["Latitude of natural origin",0,
#>             ANGLEUNIT["degree",0.0174532925199433],
#>             ID["EPSG",8801]],
#>         PARAMETER["Longitude of natural origin",0,
#>             ANGLEUNIT["degree",0.0174532925199433],
#>             ID["EPSG",8802]],
#>         PARAMETER["False easting",0,
#>             LENGTHUNIT["metre",1],
#>             ID["EPSG",8806]],
#>         PARAMETER["False northing",0,
#>             LENGTHUNIT["metre",1],
#>             ID["EPSG",8807]]],
#>     CS[Cartesian,2],
#>         AXIS["easting (X)",east,
#>             ORDER[1],
#>             LENGTHUNIT["metre",1]],
#>         AXIS["northing (Y)",north,
#>             ORDER[2],
#>             LENGTHUNIT["metre",1]],
#>     USAGE[
#>         SCOPE["Web mapping and visualisation."],
#>         AREA["World between 85.06°S and 85.06°N."],
#>         BBOX[-85.06,-180,85.06,180]],
#>     ID["EPSG",3857]]
```
