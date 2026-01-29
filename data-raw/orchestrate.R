# data-raw/orchestrate.R
# Run this to regenerate all generated code

# Path to GDAL swig includes (adjust to your setup)
swig_dir <- "~/gdal/swig/include"

# Clean stale cpp11 generated files BEFORE sourcing generators
unlink("src/cpp11.cpp")
unlink("R/cpp11.R")
unlink("src/*.o")

# Suppress test output when sourcing
SOURCED <- TRUE
SOURCED_GEN <- TRUE
SOURCED_S7_GEN <- TRUE

source("data-raw/parse_swig.R")
source("data-raw/generate_cpp11.R")
source("data-raw/generate_s7.R")

# Skip list for Dataset - methods that don't generate correctly yet
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

# Parse and generate MajorObject
result <- parse_swig_file(file.path(swig_dir, "MajorObject.i"))
cls <- result$classes[[1]]

generate_cpp11_file(cls, "src/GDAL7_majorobject.cpp")
generate_s7_file(cls, "R/class-majorobject.R")

# Parse and generate Dataset
result <- parse_swig_file(file.path(swig_dir, "Dataset.i"))
cls <- result$classes[[1]]

generate_cpp11_file(cls, "src/GDAL7_dataset.cpp")
generate_s7_file(cls, "R/class-dataset.R", skip_methods = dataset_skip)

message("\n=== Generation complete ===")
message("Now run: cpp11::cpp_register()")
message("Then:    devtools::document()")
message("Then:    devtools::install()")

