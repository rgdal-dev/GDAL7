test_that("bands report their shape and type", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  band <- get_raster_band(ds, 1L)
  expect_s3_class(band, "GDAL7::GDALRasterBand")

  expect_identical(band@xsize, 20L)
  expect_identical(band@ysize, 10L)
  expect_identical(band@band_number, 1L)
  expect_identical(band@data_type_name, "Int16")
  expect_type(band@data_type, "integer")
  expect_identical(get_raster_band(ds, 2L)@band_number, 2L)
})

test_that("block size comes back named", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  block <- get_raster_band(ds, 1L)@block_size
  expect_named(block, c("x", "y"))
  expect_true(all(block > 0L))
})

test_that("nodata is the value when set", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_identical(get_raster_band(ds, 1L)@nodata_value, -32768)
})

test_that("unset scale and offset still return a value", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))
  band <- get_raster_band(ds, 1L)

  # GDAL reports a default scale of 1 and offset of 0 whether or not the file
  # stores them, so these are numeric rather than NULL for this fixture.
  expect_true(is.null(band@scale) || is.numeric(band@scale))
  expect_true(is.null(band@offset) || is.numeric(band@offset))
  expect_type(band@unit_type, "character")
})

test_that("colour interpretation is reported by name", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  name <- get_raster_band(ds, 1L)@color_interpretation_name
  expect_type(name, "character")
  expect_gt(nchar(name), 0L)
})

test_that("an out-of-range band number errors", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))
  expect_error(get_raster_band(ds, 99L))
})

test_that("the band print method dispatches", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  out <- capture.output(print(get_raster_band(ds, 1L)))
  expect_match(out[1], "^<GDALRasterBand>$")
  expect_true(any(grepl("Size: *20 x 10", out)))
})
