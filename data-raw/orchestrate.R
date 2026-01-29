# In data-raw/generate_all.R

# Path to GDAL swig includes (adjust to your setup)
swig_dir <- "~/gdal/swig/include"

source("data-raw/parse_swig.R")
source("data-raw/generate_cpp11.R")
source("data-raw/generate_s7.R")

# Parse and generate MajorObject
result <- parse_swig_file(file.path(swig_dir, "MajorObject.i"))
cls <- result$classes[[1]]

generate_cpp11_file(cls, "src/GDAL7_majorobject.cpp")
generate_s7_file(cls, "R/class-majorobject.R")
