# Create a new raster dataset

An empty raster of a given size and type, open for writing. Fill it with
[`write_raster()`](https://rgdal-dev.github.io/GDAL7/reference/write_raster.md),
give it a position and a coordinate reference system through its
`geotransform` and `crs` properties, and close it with
[`gdal_close()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_close.md),
which is what finishes the file.

## Usage

``` r
gdal_create(
  dsn,
  xsize,
  ysize,
  bands = 1L,
  type = "Float64",
  driver = "GTiff",
  options = NULL
)
```

## Arguments

- dsn:

  Where to create it. Any VSI path works, so `"/vsimem/x.tif"` creates
  it in memory.

- xsize, ysize:

  The size in pixels.

- bands:

  How many bands. May be 0 for a dataset that carries only metadata.

- type:

  A GDAL data type name, such as `"Byte"`, `"Int16"` or `"Float32"`.
  [`gdal_data_types()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_data_types.md)
  lists them.

- driver:

  The driver's short name.

- options:

  Creation options, as a named character vector or list, or already
  written as `"KEY=VALUE"` strings.

## Value

A GDALDataset, open for writing.

## Details

Creation options are checked against the driver's own option list before
anything is created, so a misspelled option is an error rather than a
file that quietly lacks what was asked for.
[`driver_options()`](https://rgdal-dev.github.io/GDAL7/reference/driver_options.md)
is that list.

Not every driver can do this: many can only copy an existing dataset,
which is
[`gdal_create_copy()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_create_copy.md).
[`gdal_drivers()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_drivers.md)
reports which is which.

## Examples

``` r
path <- tempfile(fileext = ".tif")
ds <- gdal_create(path, 10, 10, bands = 1, type = "Float32",
                  options = c(COMPRESS = "DEFLATE"))

ds@geotransform <- c(0, 1, 0, 10, 0, -1)
ds@crs <- "EPSG:4326"
write_raster(ds, list(as.double(seq_len(100))))

gdal_close(ds)
gdal_info(path)$band_info
#>   band    type block_x block_y nodata scale offset color unit overviews
#> 1    1 Float32      10      10     NA    NA     NA  Gray              0
unlink(path)
```
