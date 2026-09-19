test_that("a multidimensional dataset exposes a root group", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))

  grp <- get_root_group(ds)
  expect_s3_class(grp, "GDAL7::GDALGroup")
  expect_identical(grp@full_name, "/")
})

test_that("arrays can be listed and opened from a group", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)

  names <- grp@mdarray_names
  expect_type(names, "character")
  expect_gt(length(names), 0L)

  arr <- open_mdarray(grp, names[[1]])
  expect_s3_class(arr, "GDAL7::GDALMDArray")
  expect_identical(arr@name, names[[1]])
  expect_null(open_mdarray(grp, "no-such-array"))
})

test_that("array dimensions come back as a data frame", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)
  arr <- open_mdarray(grp, "temperature")

  n <- arr@dimension_count
  expect_identical(n, 3L)

  dims <- arr@dimensions
  expect_s3_class(dims, "data.frame")
  expect_named(dims, c("name", "size", "type", "direction", "indexed"))
  expect_identical(nrow(dims), n)
  expect_identical(dims$name, c("time", "lat", "lon"))
  expect_identical(dims$size, c(3, 4, 5))
  expect_true(all(dims$indexed))

  expect_type(arr@data_type_name, "character")
  expect_type(arr@unit_type, "character")
})

test_that("subgroup listing works on a flat group", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)

  expect_type(grp@group_names, "character")
  expect_null(open_group(grp, "no-such-group"))
})

test_that("the multidim print methods dispatch", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)

  expect_match(capture.output(print(grp))[1], "^<GDALGroup>$")

  arr <- open_mdarray(grp, grp@mdarray_names[[1]])
  expect_match(capture.output(print(arr))[1], "^<GDALMDArray>$")
})

# ============================================================================
# Reading
# ============================================================================

# The fixture holds 1 to 60 in the array's own reading order, with the eighth
# value set to the nodata value. Everything below is checked against that.
fixture_values <- function(na = TRUE) {
  values <- as.double(1:60)
  values[8] <- if (na) NA_real_ else -999
  values
}

test_that("a whole array reads with its dimensions the R way round", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  values <- read_mdarray(arr)

  # GDAL declares (time, lat, lon); R gets it the other way round, which is
  # also the order the values already arrive in.
  expect_identical(dim(values), c(lon = 5L, lat = 4L, time = 3L))
  expect_identical(as.vector(values), fixture_values())
})

test_that("nodata becomes NA, and can be left alone", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  expect_identical(as.vector(read_mdarray(arr)), fixture_values())
  expect_identical(as.vector(read_mdarray(arr, nodata_as_na = FALSE)),
                   fixture_values(na = FALSE))
})

test_that("a slab reads with a start, a count and a step", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  whole <- read_mdarray(arr)

  # The second time step alone.
  second <- read_mdarray(arr, start = c(2, 1, 1), count = c(1, 4, 5))
  expect_identical(dim(second), c(lon = 5L, lat = 4L, time = 1L))
  expect_identical(second[, , 1], whole[, , 2])

  # Every second longitude of the first time step.
  strided <- read_mdarray(arr, start = c(1, 1, 1), count = c(1, 4, 3),
                          step = c(1, 1, 2))
  expect_identical(strided[, , 1], whole[c(1, 3, 5), , 1])

  # A negative step reads a dimension backwards.
  reversed <- read_mdarray(arr, start = c(1, 4, 1), count = c(1, 4, 5),
                           step = c(1, -1, 1))
  expect_identical(reversed[, , 1], whole[, 4:1, 1])
})

test_that("a one-dimensional array reads as a plain vector", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  lon <- open_mdarray(get_root_group(ds), "lon")

  values <- read_mdarray(lon)
  expect_null(dim(values))
  expect_identical(values, c(140, 141, 142, 143, 144))
})

test_that("a read past the end of a dimension is refused by name", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  expect_error(read_mdarray(arr, count = c(4, 4, 5)), "dimension time")
  expect_error(read_mdarray(arr, start = c(1, 1, 9)), "within the array")
  expect_error(read_mdarray(arr, step = c(1, 1, 0)), "cannot be 0")
  expect_error(read_mdarray(arr, count = c(1, 1)), "one value per dimension")
})

# ============================================================================
# Coordinates and metadata
# ============================================================================

test_that("each dimension's coordinate values come back together", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  values <- arr@dimension_values
  expect_named(values, c("time", "lat", "lon"))
  expect_identical(values$time, c(0, 1, 2))
  expect_identical(values$lat, c(-40, -41, -42, -43))
  expect_identical(values$lon, c(140, 141, 142, 143, 144))
})

test_that("coordinate variables are the arrays the format names", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  coords <- arr@coordinate_variables
  expect_identical(vapply(coords, function(a) a@name, ""), c("lat", "lon"))

  # They outlive the list they came in, which is the ownership question.
  first <- coords[[1]]
  rm(coords)
  gc()
  expect_identical(read_mdarray(first), c(-40, -41, -42, -43))
})

test_that("attributes read as a named list of vectors", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)
  arr <- open_mdarray(grp, "temperature")

  attrs <- arr@attributes
  expect_type(attrs, "list")
  expect_identical(attrs$long_name, "air temperature")
  expect_identical(attrs$valid_range, c(-50, 50))

  expect_type(grp@attributes, "list")
})

test_that("scale, offset, unit and nodata are reported", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  expect_identical(arr@scale, 2)
  expect_identical(arr@offset, 0.5)
  expect_identical(arr@unit_type, "degC")
  expect_identical(arr@nodata_value, -999)

  # An array the format says nothing about answers NULL rather than 1 and 0.
  lon <- open_mdarray(get_root_group(ds), "lon")
  expect_null(lon@scale)
  expect_null(lon@offset)

  # Zarr writes a fill value for every array whether or not one was asked for,
  # and for a floating point array that value is NaN. R already reads NaN as
  # missing, so there is nothing for read_mdarray() to substitute.
  expect_identical(lon@nodata_value, NaN)
  expect_identical(read_mdarray(lon), c(140, 141, 142, 143, 144))
})

test_that("mdarray_info answers in one call", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  info <- mdarray_info(arr)
  expect_identical(info$name, "temperature")
  expect_identical(info$full_name, "/temperature")
  expect_identical(info$data_type, "Float64")
  expect_identical(info$nodata, -999)
  expect_identical(nrow(info$dimensions), 3L)
  expect_identical(info$attributes$long_name, "air temperature")
})

# ============================================================================
# Views and the bridge back to classic raster
# ============================================================================

test_that("a view slices without reading", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  first <- get_view(arr, "[0,:,:]")
  expect_s3_class(first, "GDAL7::GDALMDArray")
  expect_identical(first@dimension_count, 2L)

  whole <- read_mdarray(arr)
  expect_identical(read_mdarray(first), whole[, , 1])

  expect_error(get_view(arr, "[nonsense]"), "Could not take that view")
})

test_that("an array can be opened by its path from the root", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)

  arr <- open_mdarray(grp, "/temperature")
  expect_identical(arr@full_name, "/temperature")

  # A path that is not there is NULL, with GDAL's own explanation of which part
  # of it was missing carried across as a warning.
  expect_warning(expect_null(open_mdarray(grp, "/no/such/array")),
                 "Cannot find group")
})

test_that("a two-dimensional array is also a raster", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  # The format says which dimension is X and which is Y, so neither has to be
  # named here.
  raster <- as_classic_dataset(get_view(arr, "[0,:,:]"))
  expect_s3_class(raster, "GDAL7::GDALDataset")
  expect_identical(raster@raster_xsize, 5L)
  expect_identical(raster@raster_ysize, 4L)

  values <- read_raster(raster, out_size = c(5, 4))[[1]]
  expect_identical(values, as.vector(read_mdarray(arr, nodata_as_na = FALSE))[1:20])

  expect_error(as_classic_dataset(arr, x_dim = 1, y_dim = 1), "two different")
  expect_error(as_classic_dataset(open_mdarray(get_root_group(ds), "lon")),
               "needs two dimensions")
})
