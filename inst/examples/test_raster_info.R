# inst/examples/test_raster_info.R
# Test raster info functionality

library(GDAL7)

# Find a test file
test_files <- c(
    "~/gdal/autotest/gcore/data/byte.tif",
    "~/gdal/autotest/gcore/data/uint32.tif",
    "~/gdal/autotest/gcore/data/rgbsmall.tif"
)

test_file <- NULL
for (f in test_files) {
    f <- normalizePath(f, mustWork = FALSE)
    if (file.exists(f)) {
        test_file <- f
        break
    }
}

if (is.null(test_file)) {
    stop("No test file found")
}

cat("Test file:", test_file, "\n\n")

# Open dataset
ds <- gdal_open(test_file)

cat("=== Dataset Dimensions ===\n")
cat("Width:  ", ds@raster_xsize, " pixels\n", sep = "")
cat("Height: ", ds@raster_ysize, " pixels\n", sep = "")
cat("Bands:  ", ds@raster_count, "\n", sep = "")
cat("\n")

# Get each band
nbands <- ds@raster_count
for (i in seq_len(nbands)) {
    cat("=== Band ", i, " ===\n", sep = "")

    band <- get_raster_band(ds, i)
    print(band)
    cat("\n")
}

gdal_close(ds)

cat("=== Test with multi-band file ===\n")
rgb_file <- normalizePath("~/gdal/autotest/gcore/data/rgbsmall.tif", mustWork = FALSE)
if (file.exists(rgb_file)) {
    ds <- gdal_open(rgb_file)
    cat("File:", rgb_file, "\n")
    cat("Size:", ds@raster_xsize, "x", ds@raster_ysize, "\n")
    cat("Bands:", ds@raster_count, "\n\n")

    for (i in seq_len(ds@raster_count)) {
        band <- get_raster_band(ds, i)
        cat("Band", i, ":", band@data_type_name,
            "-", band@color_interpretation_name, "\n")
    }

    gdal_close(ds)
} else {
    cat("RGB test file not found\n")
}

cat("\nSuccess!\n")

