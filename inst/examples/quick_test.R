# inst/examples/quick_test.R
# Quick sanity check for GDAL7 package

library(GDAL7)

# Test with local file
dsn <- normalizePath("~/gdal/autotest/gcore/data/byte.tif", mustWork = FALSE)

if (!file.exists(dsn)) {
  dsn <- normalizePath("~/gdal/autotest/gcore/data/uint32.tif", mustWork = FALSE)
}

if (!file.exists(dsn)) {
  stop("No test file found. Run in GDAL Docker container.")
}

cat("Opening:", dsn, "\n")

ds <- gdal_open(dsn)
cat("Description:", ds@description, "\n")
cat("GCP Count:", ds@gcp_count, "\n")
cat("Layer Count:", ds@layer_count, "\n")
cat("Projection:", substr(ds@projection, 1, 60), "...\n")
gdal_close(ds)

cat("\nSuccess!\n")
