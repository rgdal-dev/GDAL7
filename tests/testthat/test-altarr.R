# Read advice, block sizes, and the lazy array built on both.

open_array <- function(path, name) {
  ds <- gdal_open(path, multidim = TRUE)
  open_mdarray(get_root_group(ds), name)
}

test_that("an array reports its chunking in GDAL's order, by name", {
  skip_if_no_driver("Zarr")
  arr <- open_array(test_zarr(), "temperature")
  expect_equal(arr@block_size, c(time = 1, lat = 4, lon = 5))

  z <- write_chunked_zarr(c(3, 7, 10), c(1, 3, 4))
  expect_equal(open_array(z$path, "v")@block_size, c(time = 1, y = 3, x = 4))
})

test_that("advice on an array reads nothing and changes nothing", {
  skip_if_no_driver("Zarr")
  z <- write_chunked_zarr()
  arr <- open_array(z$path, "v")
  before <- read_mdarray(arr)
  expect_identical(advise_read(arr), arr)
  expect_invisible(advise_read(arr, start = c(2, 1, 1), count = c(2, 7, 10),
                               options = "NUM_THREADS=2"))
  # The advised slice reads the same as an unadvised one, through the cache.
  expect_equal(read_mdarray(arr, start = c(2, 1, 1), count = c(2, 7, 10)),
               before[, , 2:3, drop = FALSE], ignore_attr = TRUE)
  expect_error(advise_read(arr, start = c(1, 1, 1), count = c(4, 1, 1)),
               "within the array")
})

test_that("advice on a band or a dataset takes a window", {
  ds <- gdal_open(test_tif())
  band <- get_raster_band(ds, 1)
  expect_identical(advise_read(band), band)
  expect_identical(advise_read(band, window = c(0, 0, 4, 4), out_size = c(2, 2)),
                   band)
  expect_identical(advise_read(ds, window = c(0, 0, 4, 4)), ds)
  expect_error(advise_read(ds, bands = 99), "out of range")
  gdal_close(ds)
})

test_that("a lazy array reads what read_mdarray reads", {
  skip_if_not_installed("altarr")
  skip_if_no_driver("Zarr")
  z <- write_chunked_zarr()
  x <- as_altarr(z$path, array = "v")
  expect_true(altarr::is_altarr(x))
  expect_equal(dim(x), c(10L, 7L, 3L))
  expect_named(dimnames(x), c("x", "y", "time"))

  expect_equal(sum(x), sum(z$values))
  expect_equal(x[cbind(c(1, 10, 5), c(1, 7, 4), c(1, 3, 2))],
               z$values[cbind(c(1, 10, 5), c(1, 7, 4), c(1, 3, 2))])
  expect_equal(altarr::altarr_extract(x, 2:9, 3:6, 2:3),
               z$values[2:9, 3:6, 2:3], ignore_attr = TRUE)
})

test_that("a batch of neighbouring chunks is one read", {
  skip_if_not_installed("altarr")
  skip_if_no_driver("Zarr")
  z <- write_chunked_zarr()
  x <- as_altarr(z$path, array = "v")
  # 3 by 3 by 3 = 27 chunks, all neighbours, so one slice.
  expect_equal(altarr::altarr_extract(x, , , ), z$values, ignore_attr = TRUE)
  stats <- altarr::altarr_stats(x)
  expect_equal(stats[["fetch_calls"]], 1)
  expect_equal(stats[["chunks_fetched"]], 27)
})

test_that("scattered chunks are read one by one and still come out right", {
  skip_if_not_installed("altarr")
  skip_if_no_driver("Zarr")
  z <- write_chunked_zarr(c(4, 12, 16), c(1, 3, 4))
  x <- as_altarr(z$path, array = "v", density = 1)
  # Two opposite corners: a bounding slice of 64 chunks for 2 asked for.
  points <- cbind(c(1, 16), c(1, 12), c(1, 4))
  expect_equal(x[points], z$values[points])
})

test_that("the chunk shape can be given, and unchunked dimensions are filled", {
  skip_if_not_installed("altarr")
  skip_if_no_driver("Zarr")
  z <- write_chunked_zarr()
  x <- as_altarr(z$path, array = "v", chunk = c(5, 7, 1))
  expect_equal(sum(x), sum(z$values))
  expect_equal(GDAL7:::altarr_chunk(c(0, 0, 0), c(10, 7, 3)), c(10, 7, 1))
  expect_error(as_altarr(z$path, array = "v", chunk = c(1, 2)),
               "one non-negative value per dimension")
})

test_that("nodata reads as NA unless asked otherwise", {
  skip_if_not_installed("altarr")
  skip_if_no_driver("Zarr")
  arr <- open_array(test_zarr(), "temperature")
  full <- read_mdarray(arr)
  raw <- read_mdarray(arr, nodata_as_na = FALSE)
  x <- as_altarr(arr)
  expect_equal(sum(is.na(altarr::altarr_extract(x, , , ))), sum(is.na(full)))
  y <- as_altarr(arr, nodata_as_na = FALSE)
  expect_equal(sum(y), sum(raw))
})

test_that("a lazy array from a path survives saveRDS into a new session", {
  skip_if_not_installed("altarr")
  skip_if_no_driver("Zarr")
  z <- write_chunked_zarr()
  x <- as_altarr(z$path, array = "v")
  f <- tempfile(fileext = ".rds")
  saveRDS(x, f)
  # Read it back in a fresh R process, which has none of this session's
  # open arrays and has to reopen the source from the recipe.
  rscript <- file.path(R.home("bin"), "Rscript")
  out <- system2(rscript, c("-e", shQuote(sprintf(
    "x <- readRDS('%s'); cat(x[cbind(3, 4, 2)])", normalizePath(f, winslash = "/")
  ))), stdout = TRUE)
  expect_equal(as.numeric(tail(out, 1)), z$values[3, 4, 2])
  # And here, after forgetting the open array.
  rm(list = ls(GDAL7:::open_arrays), envir = GDAL7:::open_arrays)
  y <- readRDS(f)
  expect_equal(y[cbind(3, 4, 2)], z$values[3, 4, 2])
  expect_lt(file.size(f), 5000)
})

test_that("a band is a lazy [x, y] array in read_raster's order", {
  skip_if_not_installed("altarr")
  ds <- gdal_open(test_tif())
  band <- get_raster_band(ds, 1)
  x <- as_altarr(band, chunk = c(4, 3))
  expect_equal(dim(x), c(band@xsize, band@ysize))
  values <- read_raster(band)
  nodata <- band@nodata_value
  if (!is.null(nodata)) values[values == nodata] <- NA
  expect_equal(as.vector(altarr::altarr_extract(x, , )), values)
  gdal_close(ds)
})

test_that("a path that does not hold the array says so", {
  skip_if_not_installed("altarr")
  skip_if_no_driver("Zarr")
  expect_error(as_altarr(test_zarr(), array = "nope"), "No array called")
  expect_error(as_altarr(test_zarr()), "must name one array")
})
