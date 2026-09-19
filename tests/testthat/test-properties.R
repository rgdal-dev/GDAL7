# What an object knows about itself is a property, read from GDAL each time it
# is asked for, and settable where GDAL lets it be set.

test_that("a dataset's dimensions are properties", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_identical(ds@raster_xsize, 20L)
  expect_identical(ds@raster_ysize, 10L)
  expect_identical(ds@raster_count, 2L)
})

test_that("a property is read from GDAL, not cached at construction", {
  ds <- gdal_open(test_tif())
  expect_identical(ds@raster_xsize, 20L)

  gdal_close(ds)
  expect_error(ds@raster_xsize, "has been closed")
})

test_that("a read-only property cannot be set", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_error(ds@raster_xsize <- 1L)
})

test_that("a band's properties are its own, not the dataset's", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))
  band <- get_raster_band(ds, 1)

  expect_identical(band@xsize, ds@raster_xsize)
  expect_identical(band@band_number, 1L)
  expect_identical(band@data_type_name, "Int16")
  expect_named(band@block_size, c("x", "y"))
})

test_that("what GDAL lets you set is set by assignment", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4, bands = 1, type = "Int16")
  on.exit({
    gdal_close(ds)
    unlink(path)
  }, add = TRUE)

  band <- get_raster_band(ds, 1)

  band@nodata_value <- -999
  band@scale <- 0.1
  band@offset <- 20
  band@unit_type <- "degC"

  # Read back from GDAL rather than from anything R kept.
  fresh <- get_raster_band(ds, 1)
  expect_identical(fresh@nodata_value, -999)
  expect_identical(fresh@scale, 0.1)
  expect_identical(fresh@offset, 20)
  expect_identical(fresh@unit_type, "degC")

  ds@description <- "a description"
  expect_identical(ds@description, "a description")
})

test_that("a version-guarded accessor stays a function, so printing is safe", {
  # Reading a property must never raise, and printing an object reads every
  # one of them, so a getter whose GDAL is newer than the package floor is
  # left as a function that says which release it needs.
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_false("close_reports_progress" %in% names(S7::S7_class(ds)@properties))
  expect_true(is.function(get_close_reports_progress))

  expect_silent(invisible(capture.output(print(ds))))
})

test_that("a dataset's crs is WKT2 and takes anything GDAL reads", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4)
  on.exit({
    gdal_close(ds)
    unlink(path)
  }, add = TRUE)

  expect_true(is.na(ds@crs))

  ds@crs <- "EPSG:3857"
  expect_match(ds@crs, "^PROJCRS")
  expect_match(ds@crs, "Pseudo-Mercator")

  # The projection property beside it is GDAL's own SetProjection, which is
  # WKT1, and WKT1 cannot say what WKT2 says.
  expect_match(ds@projection, "^PROJCS")
})
