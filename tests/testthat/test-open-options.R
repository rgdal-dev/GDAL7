test_that("naming the driver opens the file the same way", {
  named <- gdal_open(test_tif(), drivers = "GTiff")
  on.exit(gdal_close(named), add = TRUE)

  probed <- gdal_open(test_tif())
  on.exit(gdal_close(probed), add = TRUE)

  expect_equal(named@raster_xsize, probed@raster_xsize)
  expect_equal(named@raster_count, probed@raster_count)
})

test_that("a driver that cannot read the file is refused rather than skipped", {
  # The point of the argument: without it GDAL would fall through to GTiff and
  # open the file anyway, which is exactly what naming a driver rules out.
  expect_error(gdal_open(test_tif(), drivers = "GPKG"))
})

test_that("an open option reaches the driver", {
  # OVERVIEW_LEVEL is how a dataset is opened at one of its own reduced
  # resolutions, which is the non-virtualisation way to read less of a file.
  ds <- gdal_open(test_cog(), options = "OVERVIEW_LEVEL=0")
  on.exit(gdal_close(ds), add = TRUE)

  full <- gdal_open(test_cog())
  on.exit(gdal_close(full), add = TRUE)

  expect_equal(c(full@raster_xsize, full@raster_ysize), c(512L, 256L))
  expect_equal(c(ds@raster_xsize, ds@raster_ysize), c(256L, 128L))
})

test_that("an empty vector is rejected, and NULL is not", {
  # character(0) as an allowed-driver list would let nothing open at all, and
  # it is nearly always an accident rather than a choice.
  expect_error(gdal_open(test_tif(), drivers = character()), "use NULL")
  expect_error(gdal_open(test_tif(), options = character()), "use NULL")

  ds <- gdal_open(test_tif(), drivers = NULL, options = NULL)
  expect_s3_class(ds, "GDAL7::GDALDataset")
  gdal_close(ds)
})

test_that("both arguments have to be character", {
  expect_error(gdal_open(test_tif(), drivers = 1), "character vector")
  expect_error(gdal_open(test_tif(), options = NA_character_), "missing values")
})
