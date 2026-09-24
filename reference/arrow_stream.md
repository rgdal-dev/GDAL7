# The Arrow stream of a layer

The layer as an ArrowArrayStream, which anything that speaks Arrow can
consume: nanoarrow, arrow, duckdb.
[`read_vector()`](https://rgdal-dev.github.io/GDAL7/reference/read_vector.md)
is this plus a conversion to a data frame.

## Usage

``` r
arrow_stream(x, options = NULL, rename = NULL, limit = NULL)
```

## Arguments

- x:

  A GDALLayer object.

- options:

  Character vector of `KEY=VALUE` options for `OGR_L_GetArrowStream`,
  for instance `"MAX_FEATURES_IN_BATCH=1000"` or
  `"GEOMETRY_ENCODING=WKB"`.

- rename:

  A named character vector, `c(new = "old")`, of columns to rename.
  `NULL` renames nothing.

- limit:

  Stop after this many features. `NULL` reads them all.

## Value

A `nanoarrow_array_stream`.

## Details

The stream holds the layer open, and the layer holds its dataset open,
so a stream stays valid until it is released or the dataset is closed by
hand.

A layer allows one stream at a time. A stream is released when it is
collected, or at once by
[`release_arrow_stream()`](https://rgdal-dev.github.io/GDAL7/reference/release_arrow_stream.md);
[`read_vector()`](https://rgdal-dev.github.io/GDAL7/reference/read_vector.md)
does that for you.

Two things GDAL has no stream option for are done around its stream:
`rename` gives columns other names, and `limit` stops after that many
features. Neither copies a value; the schema is renamed and the last
batch is shortened.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
stream <- arrow_stream(get_layer(ds, 1))
nanoarrow::infer_nanoarrow_schema(stream)
#> <nanoarrow_schema struct>
#>  $ format    : chr "+s"
#>  $ name      : chr ""
#>  $ metadata  : list()
#>  $ flags     : int 0
#>  $ children  :List of 5
#>   ..$ fid       :<nanoarrow_schema int64>
#>   .. ..$ format    : chr "l"
#>   .. ..$ name      : chr "fid"
#>   .. ..$ metadata  : list()
#>   .. ..$ flags     : int 0
#>   .. ..$ children  : list()
#>   .. ..$ dictionary: NULL
#>   ..$ name      :<nanoarrow_schema string>
#>   .. ..$ format    : chr "u"
#>   .. ..$ name      : chr "name"
#>   .. ..$ metadata  : list()
#>   .. ..$ flags     : int 2
#>   .. ..$ children  : list()
#>   .. ..$ dictionary: NULL
#>   ..$ population:<nanoarrow_schema int64>
#>   .. ..$ format    : chr "l"
#>   .. ..$ name      : chr "population"
#>   .. ..$ metadata  : list()
#>   .. ..$ flags     : int 2
#>   .. ..$ children  : list()
#>   .. ..$ dictionary: NULL
#>   ..$ elevation :<nanoarrow_schema double>
#>   .. ..$ format    : chr "g"
#>   .. ..$ name      : chr "elevation"
#>   .. ..$ metadata  : list()
#>   .. ..$ flags     : int 2
#>   .. ..$ children  : list()
#>   .. ..$ dictionary: NULL
#>   ..$ geom      :<nanoarrow_schema ogc.wkb{binary}>
#>   .. ..$ format    : chr "z"
#>   .. ..$ name      : chr "geom"
#>   .. ..$ metadata  :List of 1
#>   .. .. ..$ ARROW:extension:name: chr "ogc.wkb"
#>   .. ..$ flags     : int 2
#>   .. ..$ children  : list()
#>   .. ..$ dictionary: NULL
#>  $ dictionary: NULL
gdal_close(ds)
```
