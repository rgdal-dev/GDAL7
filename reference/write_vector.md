# Write a data frame to a vector dataset

The other direction of the same Arrow path: the data frame becomes one
record batch, GDAL creates the fields from its schema, and
`OGR_L_WriteArrowBatch` writes it.

## Usage

``` r
write_vector(
  x,
  dsn,
  layer = NULL,
  driver = "GPKG",
  crs = NULL,
  geometry_type = "Unknown",
  geometry_column = NULL,
  fid_column = NULL,
  dataset_options = NULL,
  layer_options = NULL,
  write_options = NULL
)
```

## Arguments

- x:

  A data frame. A list column of raw vectors is the geometry.

- dsn:

  Where to write it.

- layer:

  The layer name to create. Defaults to the file's base name.

- driver:

  The GDAL driver's short name.

- crs:

  The coordinate reference system, in anything GDAL accepts: WKT,
  `"EPSG:4326"`, a PROJ string. `NULL` for none.

- geometry_type:

  The geometry type of the layer, by GDAL's name for it, for instance
  `"Point"` or `"3D Polygon"`. `"Unknown"` lets the driver take whatever
  arrives.

- geometry_column:

  The column holding WKB geometry. The default finds the one list column
  of raw vectors, which is what
  [`read_vector()`](https://rgdal-dev.github.io/GDAL7/reference/read_vector.md)
  returns.

- fid_column:

  The column holding feature ids, which is a property of the layer
  rather than a field of it. The default uses a column called `fid` if
  there is one.

- dataset_options, layer_options, write_options:

  Character vectors of `KEY=VALUE` options for dataset creation, layer
  creation and the write.

## Value

`dsn`, invisibly.

## Examples

``` r
places <- read_vector(system.file("extdata/test.gpkg", package = "GDAL7"))
path <- tempfile(fileext = ".gpkg")
write_vector(places, path, layer = "places", crs = "EPSG:4326")
identical(nrow(read_vector(path)), nrow(places))
#> [1] TRUE
unlink(path)
```
