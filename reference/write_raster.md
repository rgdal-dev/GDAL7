# Write a raster window

The mirror of
[`read_raster()`](https://rgdal-dev.github.io/GDAL7/reference/read_raster.md),
with the same window and the same output size, so values read at one
size can be written back at another and GDAL resamples between them.

## Usage

``` r
write_raster(
  x,
  values,
  window = NULL,
  out_size = NULL,
  resample = "nearest",
  bands = NULL
)
```

## Arguments

- x:

  A GDALRasterBand, or a GDALDataset.

- values:

  For a band, a numeric vector. For a dataset, a list of one numeric
  vector per band in `bands`.

- window:

  Numeric of length 4: `c(xoff, yoff, xsize, ysize)` in pixels. Defaults
  to the whole raster.

- out_size:

  Integer of length 2: the width and height of the block of values being
  given. Defaults to the size of the window, which is a write with no
  resampling.

- resample:

  How to resample when `out_size` differs from the window. One of
  "nearest", "bilinear", "cubic", "cubicspline", "lanczos", "average",
  "mode", "gauss", "rms".

- bands:

  For a dataset, which bands to write, one-based. Defaults to all of
  them. Writing several at once is one pass over the data.

## Value

`x`, invisibly.

## Details

Values go in the order they come out: the first row first, x varying
fastest, which is the transpose of what
[`matrix()`](https://rdrr.io/r/base/matrix.html) builds from a vector.

Whatever the band holds, values are given as doubles and GDAL converts.
A value the band's type cannot hold is clamped by GDAL rather than
wrapped, and it says so.

The dataset has to be open for writing: one from
[`gdal_create()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_create.md),
or one opened with `gdal_open(path, update = TRUE)`. Nothing is
guaranteed to be on disk until the dataset is closed with
[`gdal_close()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_close.md),
or
[`gdal_flush()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_flush.md)
is called.

## Examples

``` r
path <- tempfile(fileext = ".tif")
ds <- gdal_create(path, 4, 4, bands = 1, type = "Byte")

write_raster(ds, list(as.double(seq_len(16))))
read_raster(ds)[[1]]
#>  [1]  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16

gdal_close(ds)
unlink(path)
```
