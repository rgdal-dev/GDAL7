# Package initialization

.onLoad <- function(libname, pkgname) {
  # Initialize GDAL
  # GDALAllRegister() is called automatically by GDAL on first use
  # but we can be explicit here if needed
}

.onUnload <- function(libpath) {
  library.dynam.unload("GDAL7", libpath)
}
