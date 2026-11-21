# Package initialization

.onLoad <- function(libname, pkgname) {
  # S7 registers methods at load time rather than through NAMESPACE directives.
  # This is what makes methods on generics owned by other packages -- print()
  # among them -- actually dispatch. Without it they are defined but never used.
  S7::S7_on_load()

  # Register all GDAL drivers
  GDAL7_init()
}

.onUnload <- function(libpath) {
  S7::S7_on_unload()
  library.dynam.unload("GDAL7", libpath)
}

# method(print, ...) <- leaves a stand-in for print in this namespace; this
# removes it once every method above is defined. zzz.R collates last.
S7::S7_on_build()
