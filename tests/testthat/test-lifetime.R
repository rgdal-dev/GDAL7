test_that("a closed dataset reports itself closed", {
  ds <- gdal_open(test_tif())
  gdal_close(ds)

  expect_error(get_raster_xsize(ds), "has been closed")
  expect_error(get_description(ds), "has been closed")
})

test_that("closing a dataset invalidates bands taken from it", {
  ds <- gdal_open(test_tif())
  band <- get_raster_band(ds, 1)

  expect_equal(get_xsize(band), 20L)

  gdal_close(ds)

  # The point of the exercise: this must be an R error, not a segfault.
  expect_error(get_xsize(band), "the GDALDataset it belongs to has been closed")
  expect_error(get_band_number(band), "the GDALDataset it belongs to has been closed")
})

test_that("a band keeps its dataset open after the dataset is dropped", {
  band <- local({
    ds <- gdal_open(test_tif())
    get_raster_band(ds, 1)
  })

  gc()
  gc()

  expect_equal(get_xsize(band), 20L)
  expect_equal(get_ysize(band), 10L)
})

test_that("closing a dataset twice is harmless", {
  ds <- gdal_open(test_tif())
  gdal_close(ds)
  expect_silent(gdal_close(ds))
})

test_that("handles of the wrong kind are refused", {
  ds <- gdal_open(test_tif())
  band <- get_raster_band(ds, 1)

  # Reaching past the S7 classes, which is what a binding must survive.
  expect_error(GDAL7_dataset_get_raster_xsize(band@.ptr), "Expected a GDALDataset")
  expect_error(GDAL7_band_get_xsize(ds@.ptr), "Expected a GDALRasterBand")
  expect_error(GDAL7_close(band@.ptr), "Expected a GDALDataset")
})

test_that("groups and arrays are not treated as major objects", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  grp <- get_root_group(ds)

  # A group is not a GDALMajorObject in the C API. There is no R method for
  # this today; the binding is what has to refuse it if one is ever added.
  expect_error(GDAL7_majorobject_get_description(grp@.ptr),
               "does not carry GDAL metadata")
})

test_that("closing a dataset invalidates its groups and arrays", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  grp <- get_root_group(ds)
  arr <- open_mdarray(grp, get_mdarray_names(grp)[[1]])

  gdal_close(ds)

  expect_error(get_name(grp), "the GDALDataset it belongs to has been closed")
  expect_error(get_name(arr), "the GDALDataset it belongs to has been closed")
})

test_that("an array keeps its group and dataset alive", {
  skip_if_no_driver("Zarr")

  arr <- local({
    ds <- gdal_open(test_zarr(), multidim = TRUE)
    grp <- get_root_group(ds)
    open_mdarray(grp, get_mdarray_names(grp)[[1]])
  })

  gc()
  gc()

  expect_true(nchar(get_name(arr)) > 0)
  expect_true(get_dimension_count(arr) > 0)
})

test_that("opening and dropping datasets does not leak file handles", {
  skip_if_no_fd_count()

  # Settle any finalizers left over from earlier tests first.
  gc()
  gc()
  before <- open_fd_count()

  for (i in seq_len(500)) {
    ds <- gdal_open(test_tif())
    rm(ds)
  }

  gc()
  gc()
  after <- open_fd_count()

  # A missing finalizer shows up here as 500 extra descriptors, so a couple of
  # descriptors of slack is plenty.
  expect_lt(after, before + 5L)
})
