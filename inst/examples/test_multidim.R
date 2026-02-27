# inst/examples/test_multidim.R
# Test multidimensional API (NetCDF, Zarr, HDF5)

library(GDAL7)

cat("=== Test Multidimensional API ===\n\n")

# Check if Zarr driver is available
zarr_drv <- gdal_get_driver_by_name("Zarr")
if (is.null(zarr_drv)) {
    cat("Zarr driver not available\n")
} else {
    cat("Zarr driver: ", get_long_name(zarr_drv), "\n", sep = "")
}

netcdf_drv <- gdal_get_driver_by_name("netCDF")
if (is.null(netcdf_drv)) {
    cat("netCDF driver not available\n")
} else {
    cat("netCDF driver: ", get_long_name(netcdf_drv), "\n", sep = "")
}
cat("\n")

# Try to find a multidimensional test file
test_files <- c(
    "~/gdal/autotest/gdrivers/data/netcdf/alldatatypes.nc",
    "~/gdal/autotest/gdrivers/data/netcdf/cf_lcc1sp.nc",
    "~/gdal/autotest/gdrivers/data/zarr/test.zarr"
)

test_file <- NULL
for (f in test_files) {
    f <- normalizePath(f, mustWork = FALSE)
    if (file.exists(f) || dir.exists(f)) {
        test_file <- f
        break
    }
}

if (is.null(test_file)) {
    cat("No multidimensional test file found in autotest suite.\n")
    cat("Searching for any .nc files...\n")
    nc_files <- list.files("~/gdal/autotest", pattern = "\\.nc$",
                           recursive = TRUE, full.names = TRUE)
    if (length(nc_files) > 0) {
        test_file <- nc_files[1]
        cat("Found:", test_file, "\n")
    }
}

if (!is.null(test_file)) {
    cat("\n=== Opening in multidim mode: ===\n")
    cat(test_file, "\n\n")

    tryCatch({
        ds <- gdal_open(test_file, multidim = TRUE)

        grp <- get_root_group(ds)
        if (!is.null(grp)) {
            cat("Root group:\n")
            print(grp)
            cat("\n")

            # List subgroups
            subgroups <- get_group_names(grp)
            if (length(subgroups) > 0) {
                cat("Subgroups: ", paste(subgroups, collapse = ", "), "\n\n")
            }

            # List and examine arrays
            arrays <- get_mdarray_names(grp)
            if (length(arrays) > 0) {
                cat("=== Arrays ===\n")
                for (arr_name in head(arrays, 5)) {
                    arr <- open_mdarray(grp, arr_name)
                    if (!is.null(arr)) {
                        print(arr)
                        cat("\n")
                    }
                }
            }
        } else {
            cat("No root group (dataset may not be multidimensional)\n")
        }

        gdal_close(ds)

    }, error = function(e) {
        cat("Error:", conditionMessage(e), "\n")
    })
} else {
    cat("No test file found.\n")
}

cat("\n=== Test with remote Zarr ===\n")
# Try a public Zarr store
#zarr_url <- "/vsicurl/https://s3.us-west-2.amazonaws.com/earthmover-sample-data/sst/sst.zarr"
zarr_url <- "ZARR:\"/vsicurl/https://raw.githubusercontent.com/mdsumner/virtualized/refs/heads/main/remote/ocean_salt_2023.parq\""
tryCatch({
    cat("Opening:", zarr_url, "\n")
    ds <- gdal_open(zarr_url, multidim = TRUE)

    grp <- get_root_group(ds)
    if (!is.null(grp)) {
        print(grp)

      # Get root group
      print(get_name(grp)); print(get_full_name(grp))
      print(get_group_names(grp)); #print(open_group(grp, "subgroup"))



        arrays <- get_mdarray_names(grp)
        if (length(arrays) > 0) {
            cat("\nFirst array:\n")
            arr <- open_mdarray(grp, arrays[1])
            if (!is.null(arr)) {
                print(arr)
              print(get_dimension_count(arr))
              print(get_dimensions(arr))
            }
        }
    }

    gdal_close(ds)

}, error = function(e) {
    cat("Could not open remote Zarr (network may be unavailable):\n")
    cat("  ", conditionMessage(e), "\n")
})

cat("\nSuccess!\n")
