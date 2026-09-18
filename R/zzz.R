# Package initialization

.onLoad <- function(libname, pkgname) {
  # S7 registers methods at load time rather than through NAMESPACE directives.
  # This is what makes methods on generics owned by other packages -- print()
  # among them -- actually dispatch. Without it they are defined but never used.
  S7::methods_register()

  # Register all GDAL drivers
  GDAL7_init()
}

.onUnload <- function(libpath) {
  library.dynam.unload("GDAL7", libpath)
}
