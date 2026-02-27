# Package initialization

.onLoad <- function(libname, pkgname) {
  # Register all GDAL drivers
  GDAL7_init()
}

.onUnload <- function(libpath) {
  library.dynam.unload("GDAL7", libpath)
}
