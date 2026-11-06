# test.tif is a 20 x 10 lon/lat grid of 18 degree cells (two Int16 bands), so
# every test here runs offline.

# An RGB(A) Byte image in UTM, for the nativeRaster path. Band b is b * 60;
# with alpha, the left half is transparent.
rgb_tif <- function(alpha = FALSE) {
  path <- tempfile(fileext = ".tif")
  nb <- if (alpha) 4L else 3L
  ds <- gdal_create(path, 16, 16, bands = nb, type = "Byte")
  ds@geotransform <- c(0, 1, 0, 16, 0, -1)
  ds@projection <- "EPSG:32755"
  vals <- lapply(1:3, function(b) as.double(rep(b * 60, 256)))
  if (alpha) {
    a <- matrix(255, 16, 16)
    a[, 1:8] <- 0
    vals[[4]] <- as.double(t(a))
  }
  write_raster(ds, vals)
  if (alpha) {
    b4 <- get_raster_band(ds, 4L)
    b4@color_interpretation <- "Alpha"
  }
  gdal_close(ds)
  path
}

test_that("warping onto the source's own grid with nearest returns the source", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))
  v <- warp_raster(ds, ds@projection, c(-180, -90, 180, 90), size = c(20L, 10L),
                   type = "integer")
  expect_named(v, c("1", "2"))
  expect_identical(v, read_raster(ds, type = "integer"))
})

test_that("warp_raster matches gdal raster reproject on the same grid and kernel", {
  skip_if_not(gdal_has_algorithms(), "needs GDAL >= 3.11 for the reference")
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))
  for (k in c("nearest", "bilinear", "cubic", "lanczos", "average")) {
    v <- warp_raster(ds, "EPSG:3857", c(-1.5e7, -1e7, 1.5e7, 1e7), size = c(30L, 20L),
                     resample = k)
    ref <- suppressWarnings(gdal_run("raster reproject", list(
      input = test_tif(), output = "", "output-format" = "MEM",
      "output-crs" = "EPSG:3857", bbox = c(-1.5e7, -1e7, 1.5e7, 1e7),
      size = c(30L, 20L), resampling = if (k == "nearest") "near" else k), progress = FALSE))
    expect_equal(v, read_raster(ref), tolerance = 0, label = k)
    gdal_close(ref)
  }
})

test_that("bands and types are chosen, and a type that cannot hold the band is refused", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))
  v <- warp_raster(ds, "EPSG:4326", c(-90, -45, 90, 45), size = c(4L, 4L), bands = 2L,
                   type = "integer")
  expect_named(v, "2")
  expect_type(v[[1]], "integer")
  expect_length(v[[1]], 16L)
  expect_error(warp_raster(ds, "EPSG:4326", c(-90, -45, 90, 45), c(4L, 4L), type = "raw"),
               "does not fit R's raw")
  expect_error(warp_raster(ds, "EPSG:4326", c(-90, -45, 90, 45), c(4L, 4L), bands = 3L),
               "between 1 and 2")
})

test_that("arguments are checked before GDAL sees them", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))
  ext <- c(-90, -45, 90, 45)
  expect_error(warp_raster("x", "EPSG:4326", ext, c(4L, 4L)), "GDALDataset")
  expect_error(warp_raster(ds, "EPSG:4326", c(1, 0, 0, 1), c(4L, 4L)), "xmax > xmin")
  expect_error(warp_raster(ds, "EPSG:4326", ext, c(0L, 4L)), "positive")
  expect_error(warp_raster(ds, "EPSG:4326", ext, c(4L, 4L), resample = "sinc"), "Unknown resampling")
  expect_error(warp_raster(ds, "EPSG:999999", ext, c(4L, 4L)), "not a CRS")
  expect_error(warp_raster(ds, "EPSG:4326", ext, c(4L, 4L), nara = TRUE), "holds bytes")
})

test_that("an RGB image warps straight into a nativeRaster, transparent outside the source", {
  path <- rgb_tif()
  on.exit(unlink(path))
  ds <- gdal_open(path)
  n <- warp_raster(ds, "EPSG:32755", c(-4, -4, 20, 20), size = c(24L, 24L), nara = TRUE)
  gdal_close(ds)
  expect_s3_class(n, "nativeRaster")
  expect_equal(dim(n), c(24L, 24L))
  px <- as.integer(n)
  ch <- function(s) bitwAnd(bitwShiftR(px, s), 255L)
  inside <- ch(24) == 255L
  # the source covers 16 x 16 of the 24 x 24 destination
  expect_equal(sum(inside), 256L)
  expect_true(all(ch(0)[inside] == 60L & ch(8)[inside] == 120L & ch(16)[inside] == 180L))
  expect_true(all(px[!inside] == 0L))
})

test_that("a source alpha band masks the nativeRaster, as gdalwarp's -srcalpha", {
  path <- rgb_tif(alpha = TRUE)
  on.exit(unlink(path))
  ds <- gdal_open(path)
  n <- warp_raster(ds, "EPSG:32755", c(0, 0, 16, 16), size = c(16L, 16L), nara = TRUE)
  gdal_close(ds)
  alpha <- matrix(bitwAnd(bitwShiftR(as.integer(n), 24L), 255L), 16, byrow = TRUE)
  expect_true(all(alpha[, 1:8] == 0L))
  expect_true(all(alpha[, 9:16] == 255L))
})
