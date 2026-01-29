# inst/examples/test_gdal7.R
# Comprehensive tests for GDAL7 package
# Run from Docker with: Rscript inst/examples/test_gdal7.R

library(GDAL7)

# Helper to print section headers
section <- function(title) {

  cat("\n", strrep("=", 60), "\n", sep = "")
  cat(" ", title, "\n", sep = "")
  cat(strrep("=", 60), "\n\n", sep = "")
}

# Test files from GDAL autotest suite
test_files <- list(
  uint32 = "~/gdal/autotest/gcore/data/uint32.tif",
  byte = "~/gdal/autotest/gcore/data/byte.tif",
  float32 = "~/gdal/autotest/gcore/data/float32.tif",
  rgb = "~/gdal/autotest/gcore/data/rgbsmall.tif",
  multi = "~/gdal/autotest/gcore/data/stefan_full_rgba.tif"
)

# Expand paths
test_files <- lapply(test_files, normalizePath, mustWork = FALSE)

# Find first existing file
test_file <- NULL
for (nm in names(test_files)) {
  if (file.exists(test_files[[nm]])) {
    test_file <- test_files[[nm]]
    cat("Using test file:", nm, "\n")
    cat("Path:", test_file, "\n")
    break
  }
}

if (is.null(test_file)) {
  stop("No test files found. Run from GDAL Docker container.")
}

# =============================================================================
section("1. Basic Open/Close")
# =============================================================================

ds <- gdal_open(test_file)
cat("Opened dataset successfully\n")
cat("Class:", class(ds)[1], "\n")

gdal_close(ds)
cat("Closed dataset successfully\n")

# =============================================================================
section("2. MajorObject Methods (inherited by Dataset)")
# =============================================================================

ds <- gdal_open(test_file)

# get_description
desc <- get_description(ds)
cat("get_description():\n  ", desc, "\n\n")

# get_metadata_domain_list
domains <- get_metadata_domain_list(ds)
cat("get_metadata_domain_list():\n")
if (length(domains) > 0) {
  for (d in domains) cat("  - '", d, "'\n", sep = "")
} else {
  cat("  (no domains)\n")
}
cat("\n")

# get_metadata_list (default domain)
metadata <- get_metadata_list(ds, "")
cat("get_metadata_list(''):\n")
if (length(metadata) > 0) {
  for (m in metadata[1:min(5, length(metadata))]) {
    cat("  ", m, "\n", sep = "")
  }
  if (length(metadata) > 5) cat("  ... (", length(metadata) - 5, " more)\n")
} else {
  cat("  (no metadata)\n")
}
cat("\n")

# get_metadata_dict (returns named list style)
meta_dict <- get_metadata_dict(ds, "")
cat("get_metadata_dict(''):\n")
if (length(meta_dict) > 0) {
  for (m in meta_dict[1:min(3, length(meta_dict))]) {
    cat("  ", m, "\n", sep = "")
  }
} else {
  cat("  (no metadata)\n")
}
cat("\n")

# get_metadata_item
area <- get_metadata_item(ds, "AREA_OR_POINT", "")
cat("get_metadata_item('AREA_OR_POINT', ''):\n  ",
    if (nchar(area) > 0) area else "(not set)", "\n\n")

gdal_close(ds)

# =============================================================================
section("3. Dataset-Specific Methods")
# =============================================================================

ds <- gdal_open(test_file)

# get_projection
proj <- get_projection(ds)
cat("get_projection():\n")
if (nchar(proj) > 100) {
  cat("  ", substr(proj, 1, 100), "...\n\n")
} else {
  cat("  ", proj, "\n\n")
}

# get_projection_ref (same as get_projection)
proj_ref <- get_projection_ref(ds)
cat("get_projection_ref(): (same as get_projection)\n")
cat("  Length:", nchar(proj_ref), "chars\n\n")

# get_file_list
files <- get_file_list(ds)
cat("get_file_list():\n")
for (f in files) cat("  ", f, "\n")
cat("\n")

# get_gcpcount
gcp_count <- get_gcpcount(ds)
cat("get_gcpcount():\n  ", gcp_count, "\n\n")

# get_gcpprojection
gcp_proj <- get_gcpprojection(ds)
cat("get_gcpprojection():\n  ",
    if (nchar(gcp_proj) > 0) substr(gcp_proj, 1, 50) else "(none)", "\n\n")

# get_layer_count (for vector datasets, will be 0 for rasters)
layer_count <- get_layer_count(ds)
cat("get_layer_count():\n  ", layer_count, "\n\n")

# flush_cache
result <- flush_cache(ds)
cat("flush_cache():\n  returned (invisible)\n\n")

gdal_close(ds)

# =============================================================================
section("4. Get Driver")
# =============================================================================

ds <- gdal_open(test_file)

tryCatch({
  drv <- get_driver(ds)
  cat("get_driver():\n")
  cat("  Class:", class(drv)[1], "\n")
}, error = function(e) {
  cat("get_driver():\n")
  cat("  Not yet usable - GDALDriver class not implemented\n")
  cat("  Error:", conditionMessage(e), "\n")
})
cat("\n")

gdal_close(ds)

# =============================================================================
section("5. Get Raster Band")
# =============================================================================

ds <- gdal_open(test_file)

tryCatch({
  band <- get_raster_band(ds, 1L)
  cat("get_raster_band(1):\n")
  cat("  Class:", class(band)[1], "\n")
}, error = function(e) {
  cat("get_raster_band(1):\n")
  cat("  Not yet usable - GDALRasterBand class not implemented\n")
  cat("  Error:", conditionMessage(e), "\n")
})
cat("\n")

gdal_close(ds)

# =============================================================================
section("6. Get Spatial Reference")
# =============================================================================

ds <- gdal_open(test_file)

tryCatch({
  srs <- get_spatial_ref(ds)
  cat("get_spatial_ref():\n")
  cat("  Class:", class(srs)[1], "\n")
}, error = function(e) {
  cat("get_spatial_ref():\n")
  cat("  Not yet usable - OGRSpatialReference class not implemented\n")
  cat("  Error:", conditionMessage(e), "\n")
})
cat("\n")

gdal_close(ds)

# =============================================================================
section("7. Test with Remote File (vsicurl)")
# =============================================================================

remote_url <- "/vsicurl/https://noaadata.apps.nsidc.org/NOAA/G02135/south/daily/geotiff/2024/01_Jan/S_20240101_concentration_v4.0.tif"

cat("Opening remote file via /vsicurl/...\n")
cat("URL:", remote_url, "\n\n")

tryCatch({
  ds <- gdal_open(remote_url)

  cat("Successfully opened remote dataset!\n\n")

  desc <- get_description(ds)
  cat("Description:\n  ", desc, "\n\n")

  proj <- get_projection(ds)
  cat("Projection (first 80 chars):\n  ", substr(proj, 1, 80), "...\n\n")

  gdal_close(ds)
  cat("Closed remote dataset.\n")

}, error = function(e) {
  cat("Could not open remote file (network may be unavailable):\n  ",
      conditionMessage(e), "\n")
})

# =============================================================================
section("Summary")
# =============================================================================

cat("All tests completed!\n\n")

cat("Working methods:\n")
cat("  MajorObject:\n")
cat("    - get_description()\n")
cat("    - set_description() [not tested - modifies file]\n")
cat("    - get_metadata_domain_list()\n")
cat("    - get_metadata_list(domain)\n")
cat("    - get_metadata_dict(domain)\n")
cat("    - get_metadata_item(name, domain)\n")
cat("    - set_metadata() [not tested - modifies file]\n")
cat("    - set_metadata_item() [not tested - modifies file]\n")
cat("\n")
cat("  Dataset:\n")
cat("    - gdal_open(path)\n")
cat("    - gdal_close(ds)\n")
cat("    - get_projection()\n")
cat("    - get_projection_ref()\n")
cat("    - get_file_list()\n")
cat("    - get_gcpcount()\n")
cat("    - get_gcpprojection()\n")
cat("    - get_layer_count()\n")
cat("    - flush_cache()\n")
cat("\n")
cat("Methods exist but return classes not implemented:\n")
cat("    - get_driver() -> needs GDALDriver class\n")
cat("    - get_raster_band(n) -> needs GDALRasterBand class\n")
cat("    - get_spatial_ref() -> needs OGRSpatialReference class\n")
cat("\n")
cat("Not yet implemented:\n")
cat("  - GDALDriver class\n")
cat("  - GDALRasterBand class\n")
cat("  - OGRSpatialReference class\n")
cat("  - GetGeoTransform/SetGeoTransform\n")
cat("  - ReadRaster/WriteRaster\n")
cat("  - OGR vector layer methods\n")
