# Copy a dataset, in another format or with other options

The driver reads the whole of `x` and writes it out its own way. This is
how formats that cannot be built pixel by pixel are made, the Cloud
Optimized GeoTIFF among them, and it carries across everything the
target format can hold: bands, type, geotransform, coordinate reference
system, nodata and metadata.

## Usage

``` r
gdal_create_copy(
  x,
  dsn,
  driver = "GTiff",
  options = NULL,
  strict = FALSE,
  progress = interactive()
)
```

## Arguments

- x:

  A GDALDataset, or a DSN string to open and close again.

- dsn:

  Where to write it. Any VSI path works.

- driver:

  The driver's short name.

- options:

  Creation options, as for
  [`gdal_create()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_create.md).

- strict:

  Whether the copy must be exact. FALSE, the default, lets the driver
  approximate what it cannot represent, which is what makes a copy into
  a narrower format possible at all.

- progress:

  Whether to draw a progress bar. Interactive sessions do by default.
  Ctrl-C stops the copy.

## Value

A GDALDataset, open.

## Details

The file is complete once the returned dataset is closed.

## Examples

``` r
path <- tempfile(fileext = ".tif")
out <- gdal_create_copy(
  system.file("extdata/test.tif", package = "GDAL7"), path,
  driver = "COG", options = c(COMPRESS = "DEFLATE"), progress = FALSE
)
gdal_close(out)

# The GTiff driver reports the layout it found, which is how to tell that
# what was written really is a COG.
ds <- gdal_open(path)
get_metadata_item(ds, "LAYOUT", "IMAGE_STRUCTURE")
#> [1] "COG"
gdal_close(ds)
unlink(path)
```
