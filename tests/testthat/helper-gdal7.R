# Test fixtures ship with the package, so the suite needs no network and no
# paths outside the installed package.

test_tif <- function() {
  system.file("extdata", "test.tif", package = "GDAL7", mustWork = TRUE)
}

# A 3 by 4 by 5 array over time, latitude and longitude, holding 1 to 60 in
# reading order with one cell set to nodata, plus units, a scale and an offset,
# attributes and a coordinate variable per dimension. Built by
# data-raw/make_multidim_fixture.R.
#
# It is a Zarr V3 store rather than V2 because the V3 layout has no
# dot-prefixed files, so it ships as an ordinary directory instead of a zip
# that every test would have to name through /vsizip/.
test_zarr <- function() {
  system.file("extdata", "multidim.zarr", package = "GDAL7", mustWork = TRUE)
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

# A binding that is guarded on a GDAL newer than GDAL7's own minimum is listed
# in gdal7_capabilities(), which is what says whether this build can call it.
skip_if_no_capability <- function(binding) {
  caps <- gdal7_capabilities()
  row <- caps[caps$binding == binding, ]
  if (nrow(row) == 1L && !row$available) {
    testthat::skip(paste0(binding, " needs GDAL ", row$gdal))
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

# A five-feature point layer in a GeoPackage, with a string, a 64-bit integer
# and a double field. Built with ogr2ogr from a CSV of WKT.
test_gpkg <- function() {
  system.file("extdata", "test.gpkg", package = "GDAL7", mustWork = TRUE)
}

# A scratch copy, for tests that write to the layer.
test_gpkg_copy <- function() {
  path <- tempfile(fileext = ".gpkg")
  file.copy(test_gpkg(), path, overwrite = TRUE)
  path
}
