# Test fixtures ship with the package, so the suite needs no network and no
# paths outside the installed package.

test_tif <- function() {
  system.file("extdata", "test.tif", package = "GDAL7", mustWork = TRUE)
}

# The Zarr fixture ships zipped: a Zarr store is a tree of dot-files, which
# R CMD check reports as hidden files, and GDAL reads it in place through
# /vsizip/ anyway.
test_zarr <- function() {
  zip <- system.file("extdata", "test.zarr.zip", package = "GDAL7", mustWork = TRUE)
  sprintf('ZARR:"/vsizip/%s/test.zarr"', zip)
}

# A scratch copy, for tests that write. GDAL drops a .aux.xml sidecar beside a
# dataset whose metadata changes, and that must never land in inst/extdata.
test_tif_copy <- function() {
  path <- tempfile(fileext = ".tif")
  file.copy(test_tif(), path, overwrite = TRUE)
  path
}

skip_if_no_driver <- function(name) {
  if (is.null(gdal_get_driver_by_name(name))) {
    testthat::skip(paste0("GDAL build has no ", name, " driver"))
  }
}

# Open file descriptors held by this process. Used to show that datasets are
# actually closed rather than merely dropped. Only Linux has /proc/self/fd.
open_fd_count <- function() {
  if (!dir.exists("/proc/self/fd")) {
    return(NA_integer_)
  }
  length(list.files("/proc/self/fd"))
}

skip_if_no_fd_count <- function() {
  if (is.na(open_fd_count())) {
    testthat::skip("no /proc/self/fd on this platform")
  }
}

# A 512x256 COG with two overview levels and a value that varies per pixel, so
# a resampled read has a checkable answer. Built from a raw gradient with
# gdal_translate -of COG -co OVERVIEW_RESAMPLING=AVERAGE.
test_cog <- function() {
  system.file("extdata", "overviews.tif", package = "GDAL7", mustWork = TRUE)
}
