test_that("a multidimensional dataset exposes a root group", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))

  grp <- get_root_group(ds)
  expect_s3_class(grp, "GDAL7::GDALGroup")
  expect_identical(get_full_name(grp), "/")
})

test_that("arrays can be listed and opened from a group", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)

  names <- get_mdarray_names(grp)
  expect_type(names, "character")
  expect_gt(length(names), 0L)

  arr <- open_mdarray(grp, names[[1]])
  expect_s3_class(arr, "GDAL7::GDALMDArray")
  expect_identical(get_name(arr), names[[1]])
  expect_null(open_mdarray(grp, "no-such-array"))
})

test_that("array dimensions come back as a data frame", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)
  arr <- open_mdarray(grp, "test")
  skip_if(is.null(arr), "fixture has no array named 'test'")

  n <- get_dimension_count(arr)
  expect_identical(n, 2L)

  dims <- get_dimensions(arr)
  expect_s3_class(dims, "data.frame")
  expect_named(dims, c("name", "size"))
  expect_identical(nrow(dims), n)
  expect_identical(sort(dims$size), c(3, 4))

  expect_type(get_data_type_name(arr), "character")
  expect_type(get_unit_type(arr), "character")
})

test_that("subgroup listing works on a flat group", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)

  expect_type(get_group_names(grp), "character")
  expect_null(open_group(grp, "no-such-group"))
})

test_that("the multidim print methods dispatch", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  on.exit(gdal_close(ds))
  grp <- get_root_group(ds)

  expect_match(capture.output(print(grp))[1], "^<GDALGroup>$")

  arr <- open_mdarray(grp, get_mdarray_names(grp)[[1]])
  expect_match(capture.output(print(arr))[1], "^<GDALMDArray>$")
})
