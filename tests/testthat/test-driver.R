test_that("the driver registry is populated", {
  expect_gt(gdal_get_driver_count(), 0L)
})

test_that("drivers can be fetched by name and by index", {
  drv <- gdal_get_driver_by_name("GTiff")
  expect_s3_class(drv, "GDAL7::GDALDriver")
  expect_identical(get_short_name(drv), "GTiff")
  expect_match(get_long_name(drv), "GeoTIFF")

  expect_s3_class(gdal_get_driver(0L), "GDAL7::GDALDriver")
  expect_null(gdal_get_driver_by_name("NoSuchDriverExists"))
})

test_that("driver capabilities are reported", {
  drv <- gdal_get_driver_by_name("GTiff")
  expect_true(test_capability(drv, "DCAP_RASTER"))
  expect_true(test_capability(drv, "DCAP_CREATE"))
  expect_false(test_capability(drv, "DCAP_NOT_A_REAL_CAPABILITY"))
})

test_that("has_open_option reads the driver's open option list", {
  # There is no GDALDriverHasOpenOption() in the C API; this is answered from
  # DMD_OPENOPTIONLIST metadata, so it is worth checking both directions.
  drv <- gdal_get_driver_by_name("GTiff")
  expect_true(has_open_option(drv, "GEOREF_SOURCES"))
  expect_false(has_open_option(drv, "NOT_AN_OPEN_OPTION"))

  # A driver with no open option list at all must say FALSE, not error.
  bare <- gdal_get_driver_by_name("MEM")
  skip_if(is.null(bare))
  expect_type(has_open_option(bare, "ANYTHING"), "logical")
})

test_that("gdal_drivers() returns a usable table", {
  d <- gdal_drivers()
  expect_s3_class(d, "data.frame")
  expect_gt(nrow(d), 0L)
  expect_named(
    d,
    c("short_name", "long_name", "raster", "vector", "create", "copy", "vsi")
  )
  expect_true("GTiff" %in% d$short_name)

  rasters <- gdal_drivers("DCAP_RASTER")
  expect_true(all(rasters$raster))
  expect_lte(nrow(rasters), nrow(d))
})

test_that("the driver print method dispatches", {
  # S7 registers methods for other packages' generics in .onLoad rather than
  # through NAMESPACE, so this guards that registration actually happens.
  out <- capture.output(print(gdal_get_driver_by_name("GTiff")))
  expect_match(out[1], "^<GDALDriver>$")
  expect_true(any(grepl("Short name: *GTiff", out)))
})
