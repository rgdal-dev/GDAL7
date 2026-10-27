# data-raw/knit-virtual-references-article.R
# Knit vignettes/articles/virtual-references.Rmd from its .Rmd.orig.
#
# The article reads BRAN2023's daily netCDF files and a kerchunk Parquet
# reference store for them, and needs GDAL's netCDF, Zarr and Parquet drivers
# and the algorithm API (for mdim mosaic, GDAL 3.12 and later). CI has no
# access to the files, so the article is knitted here, once, and what pkgdown
# builds is the result.
#
# By default the files are read from NCI's THREDDS server and the references
# from GitHub. At NCI both can be read in place instead, by setting two
# environment variables the article reads:
#
#   BRAN_DAILY  the directory of the daily files, /g/data/gb6/BRAN/BRAN2023/daily
#   BRAN_REFS   a reference store whose paths point there; make one from the
#               GitHub store with data-raw/localize-refs.py
#
# Usage: Rscript data-raw/knit-virtual-references-article.R
#   Run from the package root with GDAL7 installed.

drivers <- GDAL7::gdal_drivers()$short_name
missing <- setdiff(c("netCDF", "Zarr", "Parquet"), drivers)
if (length(missing) > 0) {
  stop("This GDAL has no ", paste(missing, collapse = ", "), " driver.",
       call. = FALSE)
}
if (!GDAL7::gdal_has_algorithms() ||
    !"mosaic" %in% GDAL7::gdal_algorithms("mdim")) {
  stop("This GDAL has no 'mdim mosaic' algorithm (GDAL 3.12 and later).",
       call. = FALSE)
}
daily <- Sys.getenv(
  "BRAN_DAILY",
  "/vsicurl/https://thredds.nci.org.au/thredds/fileServer/gb6/BRAN/BRAN2023/daily"
)
probe <- file.path(daily, "ocean_temp_2024_12.nc")
if (!isTRUE(GDAL7::vfs_exists(probe))) {
  stop("Cannot reach ", probe, call. = FALSE)
}
if (startsWith(daily, "/vsicurl/") != (Sys.getenv("BRAN_REFS") == "")) {
  warning("BRAN_DAILY and BRAN_REFS are not both set or both unset; the two ",
          "routes may read the files from different places.", call. = FALSE)
}

old <- setwd("vignettes/articles")
on.exit(setwd(old), add = TRUE)
unlink(Sys.glob("virtual-references-*.png"))
knitr::knit("virtual-references.Rmd.orig", "virtual-references.Rmd")

knitted <- readLines("virtual-references.Rmd")
errors <- grep("^#> (Error|Warning)", knitted, value = TRUE)
if (length(errors) > 0) {
  stop("The knitted article shows errors or warnings:\n",
       paste(errors, collapse = "\n"), call. = FALSE)
}
if (!file.exists("virtual-references-map-1.png")) {
  stop("The knit made no map.", call. = FALSE)
}

bad <- grep("[^ -~\t]", knitted, value = TRUE)
if (length(bad) > 0) {
  warning("Non-ASCII characters in virtual-references.Rmd:\n",
          paste(bad, collapse = "\n"), call. = FALSE)
}
