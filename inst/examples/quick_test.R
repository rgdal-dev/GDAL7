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
cat("Description:", get_description(ds), "\n")
cat("GCP Count:", get_gcpcount(ds), "\n")
cat("Layer Count:", get_layer_count(ds), "\n")
cat("Projection:", substr(get_projection(ds), 1, 60), "...\n")
gdal_close(ds)

cat("\nSuccess!\n")
