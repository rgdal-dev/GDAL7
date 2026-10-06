# data-raw/knit-icechunk-article.R
# Knit vignettes/articles/icechunk.Rmd from icechunk.Rmd.orig.
#
# The article needs the Icechunk driver (GDAL 3.14 and later) and reads public
# repositories on S3, and neither the CI GDALs nor CRAN's have the driver yet.
# So the article is knitted here, once, and what pkgdown builds is the result:
# code and output as text, with nothing left to evaluate. Knit again when the
# article or the package changes.
#
# Usage: Rscript data-raw/knit-icechunk-article.R
#   Run from the package root, with GDAL7 installed against a GDAL that has the
#   Icechunk driver, and with network access to S3.

if (!"Icechunk" %in% GDAL7::gdal_drivers()$short_name) {
  stop("This GDAL has no Icechunk driver; the article would knit empty.",
       call. = FALSE)
}

old <- setwd("vignettes/articles")
on.exit(setwd(old), add = TRUE)
unlink(Sys.glob("icechunk-*.png"))
knitr::knit("icechunk.Rmd.orig", "icechunk.Rmd")

# Keep the shipped text ASCII; a stray typographic character in output would
# otherwise only show up when someone builds the site.
bad <- grep("[^ -~\t]", readLines("icechunk.Rmd"), value = TRUE)
if (length(bad) > 0) {
  warning("Non-ASCII characters in icechunk.Rmd:\n", paste(bad, collapse = "\n"),
          call. = FALSE)
}
