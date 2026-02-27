# inst/examples/test_driver.R
# Test GDALDriver functionality

library(GDAL7)

cat("=== Driver Count ===\n")
n <- gdal_get_driver_count()
cat("Registered drivers:", n, "\n\n")

cat("=== Get Driver by Name ===\n")
gtiff <- gdal_get_driver_by_name("GTiff")
if (!is.null(gtiff)) {
    print(gtiff)
} else {
    cat("GTiff driver not found\n")
}
cat("\n")

cat("=== Get Driver from Dataset ===\n")
test_file <- normalizePath("~/gdal/autotest/gcore/data/byte.tif", mustWork = FALSE)
if (file.exists(test_file)) {
    ds <- gdal_open(test_file)
    drv <- get_driver(ds)
    cat("Driver for", basename(test_file), ":\n")
    print(drv)
    gdal_close(ds)
} else {
    cat("Test file not found\n")
}
cat("\n")

cat("=== Common Drivers ===\n")
drivers_to_check <- c("GTiff", "GPKG", "GeoJSON", "PNG", "JPEG", "netCDF", "Zarr", "COG")
for (name in drivers_to_check) {
    drv <- gdal_get_driver_by_name(name)
    if (!is.null(drv)) {
        caps <- character()
        if (test_capability(drv, "DCAP_RASTER")) caps <- c(caps, "R")
        if (test_capability(drv, "DCAP_VECTOR")) caps <- c(caps, "V")
        if (test_capability(drv, "DCAP_CREATE")) caps <- c(caps, "C")
        cat(sprintf("  %-10s %-30s [%s]\n", name, get_long_name(drv), paste(caps, collapse="")))
    }
}
cat("\n")

cat("=== List Raster Drivers ===\n")
raster_drivers <- gdal_drivers(capabilities = "DCAP_RASTER")
cat("Total raster drivers:", nrow(raster_drivers), "\n")
cat("First 10:\n")
print(head(raster_drivers[, c("short_name", "long_name", "create")], 10))
cat("\n")

cat("=== List Vector Drivers ===\n")
vector_drivers <- gdal_drivers(capabilities = "DCAP_VECTOR")
cat("Total vector drivers:", nrow(vector_drivers), "\n")
cat("First 10:\n")
print(head(vector_drivers[, c("short_name", "long_name", "create")], 10))
cat("\n")

cat("Success!\n")

