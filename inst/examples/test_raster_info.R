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
cat("Width:  ", get_raster_xsize(ds), " pixels\n", sep = "")
cat("Height: ", get_raster_ysize(ds), " pixels\n", sep = "")
cat("Bands:  ", get_raster_count(ds), "\n", sep = "")
cat("\n")

# Get each band
nbands <- get_raster_count(ds)
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
    cat("Size:", get_raster_xsize(ds), "x", get_raster_ysize(ds), "\n")
    cat("Bands:", get_raster_count(ds), "\n\n")

    for (i in seq_len(get_raster_count(ds))) {
        band <- get_raster_band(ds, i)
        cat("Band", i, ":", get_data_type_name(band),
            "-", get_color_interpretation_name(band), "\n")
    }

    gdal_close(ds)
} else {
    cat("RGB test file not found\n")
}

cat("\nSuccess!\n")

