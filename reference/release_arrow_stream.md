# Give an Arrow stream back to its layer

A layer allows one Arrow stream at a time, so a stream taken with
[`arrow_stream()`](https://rgdal-dev.github.io/GDAL7/reference/arrow_stream.md)
has to be released before the layer can be read again. Doing nothing
releases it too, when R next collects it.

## Usage

``` r
release_arrow_stream(stream)
```

## Arguments

- stream:

  A stream from
  [`arrow_stream()`](https://rgdal-dev.github.io/GDAL7/reference/arrow_stream.md).

## Value

`NULL`, invisibly. Releasing a stream twice is harmless.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
stream <- arrow_stream(get_layer(ds, 1))
release_arrow_stream(stream)
gdal_close(ds)
```
