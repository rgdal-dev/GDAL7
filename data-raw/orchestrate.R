# data-raw/orchestrate.R
# Regenerate every generated file in GDAL7 from the vendored API model.
#
# Usage:
#   Rscript data-raw/orchestrate.R              # generate from inst/api/gdal-api.json
#   Rscript data-raw/orchestrate.R --refresh    # re-extract the model from ~/gdal first
#
# The default needs no GDAL checkout, which is what lets CI regenerate and diff
# on every commit. --refresh is the step a human takes when GDAL moves on; it
# rewrites inst/api/gdal-api.json, and the change it makes to the generated
# code is then a reviewable diff rather than a surprise.
#
# After generating: R CMD INSTALL --no-staged-install .

args <- commandArgs(trailingOnly = TRUE)
refresh <- "--refresh" %in% args
swig_dir <- "~/gdal/swig/include"

# Suppress the generators' standalone test blocks when sourced.
SOURCED <- TRUE
SOURCED_GEN <- TRUE
SOURCED_S7_GEN <- TRUE

message("=== Loading generators ===")
source("data-raw/parse_swig.R")
source("data-raw/api_model.R")
source("data-raw/generate_cpp11.R")
source("data-raw/generate_s7.R")
source("data-raw/generate_constants.R")

# =============================================================================
# The API model
# =============================================================================

if (refresh) {
  message("=== Refreshing the API model from ", swig_dir, " ===")
  write_api_model(build_api_model(swig_dir))
}

model <- read_api_model()
symbol_versions <- read_symbol_versions()
message(sprintf("=== API model: GDAL %s, extracted %s ===",
                model$gdal_version, model$extracted))

# Methods that are written by hand elsewhere in the package. Unlike everything
# the generator declines to emit, these are not gaps: they are places where a
# hand-written binding does more than the generator could, and generating them
# too would define the same symbol twice.
hand_written <- list(
  Dataset = c(
    # R/driver.R and R/raster-info.R, where the classes they return live.
    "GetDriver", "GetRasterBand",
    # R/raster-io.R. Each carries a double[6], which the generator cannot
    # express in either direction.
    "GetGeoTransform", "SetGeoTransform",
    # src/GDAL7_multidim.cpp, which also opens groups and arrays.
    "GetRootGroup",
    # src/GDAL7_create.cpp. Both take a scope flag whose only supported value
    # is GDAL_OF_RASTER, which is not worth an argument, and the dataset the
    # second returns is held by reference rather than owned, which the
    # generator has no way to know.
    "IsThreadSafe", "GetThreadSafeDataset"
  )
)

# =============================================================================
# Clean stale generated files BEFORE generating
# =============================================================================

message("=== Cleaning stale files ===")
unlink("src/cpp11.cpp")
unlink("R/cpp11.R")
unlink(list.files("src", pattern = "\\.(o|so|dll)$", full.names = TRUE))
unlink("R/aaa-class-majorobject.R")
unlink("R/aab-class-dataset.R")
unlink("src/GDAL7_majorobject.cpp")
unlink("src/GDAL7_dataset.cpp")
unlink("src/GDAL7_constants.cpp")
unlink("src/GDAL7_capabilities.cpp")

# =============================================================================
# Classes
# =============================================================================

# MajorObject is generated first and named "aaa-" so that it loads before the
# classes that inherit from it.
outputs <- list(
  MajorObject = list(cpp = "src/GDAL7_majorobject.cpp",
                     r = "R/aaa-class-majorobject.R"),
  Dataset = list(cpp = "src/GDAL7_dataset.cpp",
                 r = "R/aab-class-dataset.R")
)

capabilities <- list()

for (cls in model$classes) {
  name <- cls$public_name
  message(sprintf("=== Generating %s ===", name))

  paths <- outputs[[name]]
  if (is.null(paths)) {
    stop("No output paths are configured for class ", name)
  }

  result <- generate_cpp11_file(cls, paths$cpp, symbol_versions,
                                hand_written = hand_written[[name]] %||% character())
  generate_s7_file(cls, paths$r, methods = result$methods, members = result$members)

  capabilities <- c(capabilities, result$capabilities)

  if (length(result$skipped) > 0) {
    message(sprintf("    %d method(s) not generated; reasons are in %s",
                    length(unique(vapply(result$skipped, function(x) x$name, ""))),
                    paths$cpp))
  }
}

# =============================================================================
# Constants and capabilities
# =============================================================================

# The generator only knows about what it generated, and gdal7_capabilities() is
# meant to answer for every binding that can be unavailable, so the guarded
# hand-written ones are added here.
capabilities <- c(capabilities, list(
  list(name = "dataset_is_thread_safe", since = "3.10.0"),
  list(name = "dataset_get_thread_safe_dataset", since = "3.10.0")
))

message("=== Generating constants ===")
generate_constants_file(model, "src/GDAL7_constants.cpp", symbol_versions)

message("=== Generating capabilities ===")
generate_capabilities_file(capabilities, "src/GDAL7_capabilities.cpp")

# =============================================================================
# cpp11 registration
# =============================================================================

message("=== Generating cpp11 registration ===")
cpp11::cpp_register()

message("")
message("=== Generation complete ===")
message("Now run: R CMD INSTALL --no-staged-install .")
