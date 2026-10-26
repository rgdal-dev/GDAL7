# data-raw/knit-virtual-references-article.R
# Knit vignettes/articles/virtual-references.Rmd from its .Rmd.orig.
#
# The article reads BRAN2023 from NCI's THREDDS server and a kerchunk Parquet
# reference store from GitHub, and needs GDAL's netCDF, Zarr and Parquet
# drivers and the algorithm API (for mdim mosaic, GDAL 3.12 and later). CI has
# no access to THREDDS for this, so the article is knitted here, once, and what
# pkgdown builds is the result.
#
# Usage: Rscript data-raw/knit-virtual-references-article.R
#   Run from the package root with GDAL7 installed and network access to
#   thredds.nci.org.au and raw.githubusercontent.com.

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
probe <- "/vsicurl/https://thredds.nci.org.au/thredds/fileServer/gb6/BRAN/BRAN2023/daily/ocean_temp_2024_12.nc"
if (!isTRUE(GDAL7::vfs_exists(probe))) {
  stop("Cannot reach ", probe, call. = FALSE)
}

old <- setwd("vignettes/articles")
on.exit(setwd(old), add = TRUE)
unlink(Sys.glob("virtual-references-*.png"))
knitr::knit("virtual-references.Rmd.orig", "virtual-references.Rmd")

bad <- grep("[^ -~\t]", readLines("virtual-references.Rmd"), value = TRUE)
if (length(bad) > 0) {
  warning("Non-ASCII characters in virtual-references.Rmd:\n",
          paste(bad, collapse = "\n"), call. = FALSE)
}
