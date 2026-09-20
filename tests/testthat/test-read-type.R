# A scratch Byte raster, since every fixture that ships with the package is
# Int16 and the narrow types are exactly what Byte data is for.
byte_tif <- function(values = as.double(0:15)) {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4, bands = 1, type = "Byte")
  write_raster(ds, list(values))
  gdal_close(ds)
  path
}

test_that("a Byte band reads the same values as raw, integer and double", {
  path <- byte_tif()
  on.exit(unlink(path), add = TRUE)

  ds <- gdal_open(path)
  on.exit(gdal_close(ds), add = TRUE)
  band <- get_raster_band(ds, 1)

  as_double <- read_raster(band)
  as_integer <- read_raster(band, type = "integer")
  as_raw <- read_raster(band, type = "raw")

  expect_type(as_double, "double")
  expect_type(as_integer, "integer")
  expect_type(as_raw, "raw")

  expect_equal(as_double, as.double(0:15))
  expect_equal(as_integer, 0:15)
  expect_equal(as.integer(as_raw), 0:15)
})

test_that("the narrow types hold up through a resampled read", {
  path <- byte_tif()
  on.exit(unlink(path), add = TRUE)

  ds <- gdal_open(path)
  on.exit(gdal_close(ds), add = TRUE)
  band <- get_raster_band(ds, 1)

  window <- c(0, 0, 4, 4)
  reduced <- read_raster(band, window = window, out_size = c(2, 2),
                         resample = "average")
  as_raw <- read_raster(band, window = window, out_size = c(2, 2),
                        resample = "average", type = "raw")

  expect_length(as_raw, 4L)
  expect_equal(as.double(as.integer(as_raw)), reduced)
})

test_that("a band whose type will not fit is refused rather than clamped", {
  # test.tif is Int16, which fits an R integer but not a raw byte.
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds), add = TRUE)
  band <- get_raster_band(ds, 1)

  expect_type(read_raster(band, type = "integer"), "integer")
  expect_error(read_raster(band, type = "raw"), "Int16")
})

test_that("reading a dataset checks every band, not just the first", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds), add = TRUE)

  both <- read_raster(ds, type = "integer")
  expect_length(both, 2L)
  expect_type(both[[1]], "integer")
  expect_equal(both[[1]], as.integer(read_raster(ds)[[1]]))

  expect_error(read_raster(ds, type = "raw"), "Int16")
})

test_that("an unknown type is an R error naming the three choices", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds), add = TRUE)

  expect_error(read_raster(ds, type = "float"), "double")
  expect_error(read_raster(ds, type = c("raw", "raw")), "single")
  expect_error(read_raster(ds, type = NA_character_), "non-missing")
})
