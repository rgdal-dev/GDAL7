#' Warp a dataset onto a grid
#'
#' Reproject and resample bands of a dataset onto a destination grid, with
#' GDAL's warp API and no utility layer: a transformer from the source to
#' `crs` (`GDALCreateGenImgProjTransformer2`, approximated within
#' `error_threshold` pixels as gdalwarp's `-et`), then
#' `GDALWarpOperation::ChunkAndWarpImage` into an in-memory dataset. For the
#' same kernel and the same source, the values are gdalwarp's.
#'
#' The source is the dataset as opened, so the resolution it is read at is the
#' caller's choice: to warp from an overview, open it with
#' `options = "OVERVIEW_LEVEL=k only"` (" only", so no coarser level is
#' exposed). Source nodata is honoured and carried to the destination, as
#' gdalwarp does.
#'
#' With `nara = TRUE` the result is a `nativeRaster` and the warp writes into
#' it directly: its four bytes per pixel are the destination's four bands, so
#' nothing is copied or packed afterwards. That needs Byte bands: one (grey)
#' or three (RGB), plus an optional alpha band. The alpha byte is the
#' destination alpha GDAL computes, 0 where no source pixel contributes.
#'
#' @param x A GDALDataset.
#' @param crs The destination CRS, anything GDAL understands (`"EPSG:3031"`,
#'   a PROJ string, WKT).
#' @param extent Numeric of length 4: `c(xmin, ymin, xmax, ymax)` in `crs`.
#' @param size Integer of length 2: the destination width and height.
#' @param resample gdalwarp's `-r` names: `"nearest"` (or `"near"`),
#'   `"bilinear"`, `"cubic"`, `"cubicspline"`, `"lanczos"`, `"average"`,
#'   `"rms"`, `"mode"`, `"max"`, `"min"`, `"med"`, `"q1"`, `"q3"`, `"sum"`.
#' @param bands Which bands, one-based. Defaults to all of them.
#' @param type As in [read_raster()]: `"double"`, `"integer"` or `"raw"`.
#'   Ignored when `nara = TRUE`.
#' @param alpha_band A source band whose zeros mask the source (gdalwarp's
#'   `-srcalpha`). `NULL` (the default) does what gdalwarp does: the last band,
#'   if it is an alpha band and among `bands`. `0` for none. Give it explicitly
#'   for a WMS or WMTS dataset opened at an overview, whose bands report no
#'   colour interpretation (GDAL 3.14).
#' @param error_threshold Maximum error, in pixels, of the approximate
#'   transformer. `0.125` is gdalwarp's default; `0` is exact.
#' @param nara Return a `nativeRaster` instead of a list of bands.
#' @return A named list of one row-major vector per band, of
#'   `size[1] * size[2]` values (as [read_raster()] returns for a dataset), or
#'   with `nara = TRUE` a `nativeRaster` of `size[2]` rows and `size[1]`
#'   columns.
#' @export
#' @examples
#' ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))
#'
#' # test.tif's own grid, at half the resolution, with bilinear resampling.
#' gt <- ds@geotransform
#' ext <- c(gt[1], gt[4] + ds@raster_ysize * gt[6], gt[1] + ds@raster_xsize * gt[2], gt[4])
#' v <- warp_raster(ds, ds@projection, ext, size = c(10L, 10L), resample = "bilinear")
#' str(v)
#'
#' # The same area in longitude and latitude.
#' ll <- transform_extent(ext, ds@projection, "EPSG:4326")
#' str(warp_raster(ds, "EPSG:4326", ll, size = c(8L, 8L)))
#' gdal_close(ds)
#'
#' # An RGB image warped straight into a nativeRaster.
#' path <- tempfile(fileext = ".tif")
#' rgb <- gdal_create(path, 16, 16, bands = 3, type = "Byte")
#' rgb@geotransform <- c(0, 1, 0, 16, 0, -1)
#' rgb@projection <- "EPSG:32755"
#' write_raster(rgb, lapply(1:3, function(b) as.double(rep(b * 60, 256))))
#' gdal_close(rgb)
#' ds <- gdal_open(path)
#' n <- warp_raster(ds, "EPSG:32755", c(-4, -4, 20, 20), size = c(24L, 24L), nara = TRUE)
#' class(n)
#' if (interactive()) plot(as.raster(n))
#' gdal_close(ds)
#' unlink(path)
warp_raster <- function(x, crs, extent, size, resample = "nearest", bands = NULL,
                        type = "double", alpha_band = NULL, error_threshold = 0.125,
                        nara = FALSE) {
  if (!S7::S7_inherits(x, GDALDataset)) {
    stop("`x` must be a GDALDataset", call. = FALSE)
  }
  if (!is.character(crs) || length(crs) != 1L || is.na(crs) || !nzchar(crs)) {
    stop("`crs` must be a single string", call. = FALSE)
  }
  extent <- as.double(extent)
  if (length(extent) != 4L || anyNA(extent)) {
    stop("`extent` must be 4 non-missing numbers: xmin, ymin, xmax, ymax", call. = FALSE)
  }
  if (!(extent[3] > extent[1] && extent[4] > extent[2])) {
    stop("`extent` must have xmax > xmin and ymax > ymin", call. = FALSE)
  }
  size <- as.integer(size)
  if (length(size) != 2L || anyNA(size) || any(size < 1L)) {
    stop("`size` must be 2 positive integers: width, height", call. = FALSE)
  }
  if (!is.character(resample) || length(resample) != 1L || is.na(resample)) {
    stop("`resample` must be a single string", call. = FALSE)
  }
  if (is.null(bands)) {
    bands <- seq_len(x@raster_count)
  }
  alpha <- if (is.null(alpha_band)) -1L else as.integer(alpha_band)
  if (length(alpha) != 1L || is.na(alpha) || alpha < -1L) {
    stop("`alpha_band` must be NULL, 0 or a band number", call. = FALSE)
  }
  error_threshold <- as.double(error_threshold)
  if (length(error_threshold) != 1L || is.na(error_threshold) || error_threshold < 0) {
    stop("`error_threshold` must be a single number, 0 or more", call. = FALSE)
  }
  geotransform <- c(extent[1], (extent[3] - extent[1]) / size[1], 0,
                    extent[4], 0, -(extent[4] - extent[2]) / size[2])
  if (isTRUE(nara)) {
    return(GDAL7_dataset_warp_nara(x@.ptr, crs, geotransform, size, resample,
                                   as.integer(bands), error_threshold, alpha))
  }
  GDAL7_dataset_warp(x@.ptr, crs, geotransform, size, resample, as.integer(bands),
                     resolve_read_type(type), error_threshold, alpha)
}
