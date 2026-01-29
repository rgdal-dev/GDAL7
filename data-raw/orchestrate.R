# data-raw/orchestrate.R
# Master script to regenerate all GDAL7 bindings from SWIG files
#
# Usage: source("data-raw/orchestrate.R")
# Then:  R CMD INSTALL --no-staged-install .

# Path to GDAL swig includes (adjust to your setup)
swig_dir <- "~/gdal/swig/include"

# Check swig dir exists
if (!dir.exists(normalizePath(swig_dir, mustWork = FALSE))) {
  stop("SWIG directory not found: ", swig_dir,
       "\nClone GDAL repo: git clone --depth 1 https://github.com/osgeo/gdal.git ~/gdal")
}

# Clean stale generated files BEFORE sourcing generators
message("=== Cleaning stale files ===")
unlink("src/cpp11.cpp")
unlink("R/cpp11.R")
unlink(list.files("src", pattern = "\\.(o|so|dll)$", full.names = TRUE))
# Clean old class files (both naming conventions)
unlink("R/class-majorobject.R")
unlink("R/class-dataset.R")
unlink("R/aaa-class-majorobject.R")
unlink("R/aab-class-dataset.R")

# Suppress test output when sourcing
SOURCED <- TRUE
SOURCED_GEN <- TRUE
SOURCED_S7_GEN <- TRUE
SOURCED_FIX_CPP11 <- TRUE

message("=== Loading generators ===")
source("data-raw/parse_swig.R")
source("data-raw/generate_cpp11.R")
source("data-raw/generate_s7.R")
source("data-raw/fix_cpp11.R")

# Skip list for Dataset - methods that don't generate correctly yet
# (GDAL 3.9+ functions, complex signatures, callbacks, arrays, etc.)
dataset_skip <- c(
  "MarkSuppressOnClose", "Close", "GetCloseReportsProgress",
  "IsThreadSafe", "GetThreadSafeDataset", "GetRootGroup",
  "SetProjection", "SetSpatialRef",
  "GetGeoTransform", "SetGeoTransform",
  "GetExtent", "GetExtentWGS84LongLat",
  "BuildOverviews", "AddBand", "CreateMaskBand", "AdviseRead",
  "GetFieldDomainNames", "GetRelationshipNames",
  "GetFieldDomain", "AddFieldDomain", "DeleteFieldDomain", "UpdateFieldDomain",
  "GetRelationship", "AddRelationship", "DeleteRelationship", "UpdateRelationship",
  "AsMDArray", "StartTransaction", "CommitTransaction", "RollbackTransaction",
  "AbortSQL", "ResetReading", "GetLayer", "GetLayerByName", "ClearStatistics"
)

# =============================================================================
# Generate MajorObject (base class - must load first, hence "aaa-" prefix)
# =============================================================================
message("=== Generating MajorObject ===")
result <- parse_swig_file(file.path(swig_dir, "MajorObject.i"))
cls <- result$classes[[1]]

generate_cpp11_file(cls, "src/GDAL7_majorobject.cpp")
generate_s7_file(cls, "R/aaa-class-majorobject.R")  # aaa- ensures it loads first

# =============================================================================
# Generate Dataset (inherits from MajorObject)
# =============================================================================
message("=== Generating Dataset ===")
result <- parse_swig_file(file.path(swig_dir, "Dataset.i"))
cls <- result$classes[[1]]

generate_cpp11_file(cls, "src/GDAL7_dataset.cpp")
generate_s7_file(cls, "R/aab-class-dataset.R", skip_methods = dataset_skip)  # aab- loads second

# =============================================================================
# Generate cpp11 registration and fix it
# =============================================================================
message("=== Generating cpp11 registration ===")
cpp11::cpp_register()

message("=== Fixing cpp11.cpp ===")
fix_cpp11()

# =============================================================================
# Done!
# =============================================================================
message("")
message("=== Generation complete ===")
message("Now run: R CMD INSTALL --no-staged-install .")
message("")
message("Or in R:")
message("  system('R CMD INSTALL --no-staged-install .')")
