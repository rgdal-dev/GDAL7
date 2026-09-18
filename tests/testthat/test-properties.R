test_that("a dataset's dimensions are properties", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_identical(ds@raster_xsize, 20L)
  expect_identical(ds@raster_ysize, 10L)
  expect_identical(ds@raster_count, 2L)
})

test_that("the property and the generic are the same value", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_identical(get_raster_xsize(ds), ds@raster_xsize)
  expect_identical(get_raster_ysize(ds), ds@raster_ysize)
  expect_identical(get_raster_count(ds), ds@raster_count)
})

test_that("a property is read from GDAL, not cached at construction", {
  ds <- gdal_open(test_tif())
  expect_identical(ds@raster_xsize, 20L)

  gdal_close(ds)
  expect_error(ds@raster_xsize, "has been closed")
})

test_that("a property cannot be set", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_error(ds@raster_xsize <- 1L)
})
