# Warp a dataset onto a grid

Reproject and resample bands of a dataset onto a destination grid, with
GDAL's warp API and no utility layer: a transformer from the source to
`crs` (`GDALCreateGenImgProjTransformer2`, approximated within
`error_threshold` pixels as gdalwarp's `-et`), then
`GDALWarpOperation::ChunkAndWarpImage` into an in-memory dataset. For
the same kernel and the same source, the values are gdalwarp's.

## Usage

``` r
warp_raster(
  x,
  crs,
  extent,
  size,
  resample = "nearest",
  bands = NULL,
  type = "double",
  alpha_band = NULL,
  error_threshold = 0.125,
  nara = FALSE
)
```

## Arguments

- x:

  A GDALDataset.

- crs:

  The destination CRS, anything GDAL understands (`"EPSG:3031"`, a PROJ
  string, WKT).

- extent:

  Numeric of length 4: `c(xmin, ymin, xmax, ymax)` in `crs`.

- size:

  Integer of length 2: the destination width and height.

- resample:

  gdalwarp's `-r` names: `"nearest"` (or `"near"`), `"bilinear"`,
  `"cubic"`, `"cubicspline"`, `"lanczos"`, `"average"`, `"rms"`,
  `"mode"`, `"max"`, `"min"`, `"med"`, `"q1"`, `"q3"`, `"sum"`.

- bands:

  Which bands, one-based. Defaults to all of them.

- type:

  As in
  [`read_raster()`](https://rgdal-dev.github.io/GDAL7/reference/read_raster.md):
  `"double"`, `"integer"` or `"raw"`. Ignored when `nara = TRUE`.

- alpha_band:

  A source band whose zeros mask the source (gdalwarp's `-srcalpha`).
  `NULL` (the default) does what gdalwarp does: the last band, if it is
  an alpha band and among `bands`. `0` for none. Give it explicitly for
  a WMS or WMTS dataset opened at an overview, whose bands report no
  colour interpretation (GDAL 3.14).

- error_threshold:

  Maximum error, in pixels, of the approximate transformer. `0.125` is
  gdalwarp's default; `0` is exact.

- nara:

  Return a `nativeRaster` instead of a list of bands.

## Value

A named list of one row-major vector per band, of `size[1] * size[2]`
values (as
[`read_raster()`](https://rgdal-dev.github.io/GDAL7/reference/read_raster.md)
returns for a dataset), or with `nara = TRUE` a `nativeRaster` of
`size[2]` rows and `size[1]` columns.

## Details

The source is the dataset as opened, so the resolution it is read at is
the caller's choice: to warp from an overview, open it with
`options = "OVERVIEW_LEVEL=k only"` (" only", so no coarser level is
exposed). Source nodata is honoured and carried to the destination, as
gdalwarp does.

With `nara = TRUE` the result is a `nativeRaster`: the warp writes four
Byte bands and one GDAL read interleaves them into its four bytes per
pixel, so nothing is packed in R. That needs Byte bands: one (grey) or
three (RGB), plus an optional alpha band. The alpha byte is the
destination alpha GDAL computes, 0 where no source pixel contributes.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))

# test.tif's own grid, at half the resolution, with bilinear resampling.
gt <- ds@geotransform
ext <- c(gt[1], gt[4] + ds@raster_ysize * gt[6], gt[1] + ds@raster_xsize * gt[2], gt[4])
v <- warp_raster(ds, ds@projection, ext, size = c(10L, 10L), resample = "bilinear")
str(v)
#> List of 2
#>  $ 1: num [1:100] 3 3 3 3 3 3 3 3 3 3 ...
#>  $ 2: num [1:100] 7 7 7 7 7 7 7 7 7 7 ...

# The same area in longitude and latitude.
ll <- transform_extent(ext, ds@projection, "EPSG:4326")
str(warp_raster(ds, "EPSG:4326", ll, size = c(8L, 8L)))
#> List of 2
#>  $ 1: num [1:64] 3 3 3 3 3 3 3 3 3 3 ...
#>  $ 2: num [1:64] 7 7 7 7 7 7 7 7 7 7 ...
gdal_close(ds)

# An RGB image warped straight into a nativeRaster.
path <- tempfile(fileext = ".tif")
rgb <- gdal_create(path, 16, 16, bands = 3, type = "Byte")
rgb@geotransform <- c(0, 1, 0, 16, 0, -1)
rgb@projection <- "EPSG:32755"
write_raster(rgb, lapply(1:3, function(b) as.double(rep(b * 60, 256))))
gdal_close(rgb)
ds <- gdal_open(path)
n <- warp_raster(ds, "EPSG:32755", c(-4, -4, 20, 20), size = c(24L, 24L), nara = TRUE)
class(n)
#> [1] "nativeRaster"
if (interactive()) plot(as.raster(n))
gdal_close(ds)
unlink(path)
```
