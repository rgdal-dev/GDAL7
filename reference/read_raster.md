# Read a window of raster data

Reads a window of a band, or of several bands of a dataset, at a chosen
output size. The window and the output size are independent, which is
the whole point: asking for a large window at a small output size lets
GDAL serve the read from an overview, so a huge raster over `/vsicurl/`
costs only the bytes of the overview level it picks.

## Usage

``` r
read_raster(
  x,
  window = NULL,
  out_size = NULL,
  resample = "nearest",
  bands = NULL,
  type = "double"
)
```

## Arguments

- x:

  A GDALRasterBand, or a GDALDataset.

- window:

  Numeric of length 4: `c(xoff, yoff, xsize, ysize)` in pixels. Defaults
  to the whole raster.

- out_size:

  Integer of length 2: the width and height to return. Defaults to the
  size of the window, which is a read with no resampling.

- resample:

  One of "nearest", "bilinear", "cubic", "cubicspline", "lanczos",
  "average", "mode", "gauss", "rms".

- bands:

  For a dataset, which bands to read, one-based. Defaults to all of
  them. Reading several at once is one pass over the data rather than
  one per band.

- type:

  The R type to read into: `"double"` (the default), `"integer"` or
  `"raw"`. `"double"` holds any band type and is eight bytes a value.
  `"raw"` is one byte and reads a Byte band as-is, which is what an RGB
  image wants. `"integer"` is four bytes and covers Byte, Int8, Int16,
  UInt16 and Int32. A band whose type will not fit is an error rather
  than a silent clamp, and for a dataset every band read has to fit.

  Two things the narrower types cannot carry. `"raw"` has no missing
  value, so a nodata pixel comes back as whatever byte the file holds.
  `"integer"` has one, and it is `.Machine$integer.max + 1` in disguise,
  so an Int32 band holding that exact value reads as `NA`.

## Value

For a band, a vector of `out_size[1] * out_size[2]` values, of the
requested `type`. For a dataset, a named list of one such vector per
band.

## Details

The window is in pixel coordinates and may be fractional. Whole numbers
fall on pixel corners, so `c(0, 0, 10, 10)` is the first ten pixels of
the first ten rows.

Values come back as doubles whatever the band holds, in GDAL's order:
the first row of the output first, x varying fastest. That is the
transpose of what R's [`matrix()`](https://rdrr.io/r/base/matrix.html)
builds from a vector, so reshape with
`matrix(values, nrow = out_size[1])` and read the columns as rows, or
transpose it.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))
band <- get_raster_band(ds, 1)

# The whole band.
length(read_raster(band))
#> [1] 200

# A 4x4 window, averaged down to 2x2.
read_raster(band, window = c(0, 0, 4, 4), out_size = c(2, 2),
            resample = "average")
#> [1] 3 3 3 3

# Both bands at once.
str(read_raster(ds, out_size = c(5, 5)))
#> List of 2
#>  $ 1: num [1:25] 3 3 3 3 3 3 3 3 3 3 ...
#>  $ 2: num [1:25] 7 7 7 7 7 7 7 7 7 7 ...

# test.tif holds Int16, which fits an R integer but not a raw byte.
str(read_raster(band, out_size = c(4, 4), type = "integer"))
#>  int [1:16] 3 3 3 3 3 3 3 3 3 3 ...

gdal_close(ds)

# A Byte band does fit, and as raw it is an eighth of the memory of the
# same read as double.
path <- tempfile(fileext = ".tif")
bytes <- gdal_create(path, 4, 4, bands = 1, type = "Byte")
write_raster(bytes, list(as.double(0:15)))
gdal_close(bytes)

ds <- gdal_open(path)
str(read_raster(get_raster_band(ds, 1), type = "raw"))
#>  raw [1:16] 00 01 02 03 ...
gdal_close(ds)
unlink(path)
```
