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

skip_if_no_driver <- function(name) {
  if (is.null(gdal_get_driver_by_name(name))) {
    testthat::skip(paste0("GDAL build has no ", name, " driver"))
  }
}
