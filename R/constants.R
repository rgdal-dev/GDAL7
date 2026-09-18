# ============================================================================
# GDAL constants and capabilities
# ============================================================================

#' GDAL's integer constants
#'
#' The enumerators GDAL declares: data types (`GDT_*`), access modes (`GA_*`),
#' colour interpretations (`GCI_*`), resampling algorithms (`GRA_*`,
#' `GRIORA_*`), open flags (`OF_*`), error classes (`CE_*`, `CPLE_*`) and the
#' rest. They are returned as one named vector rather than exported one by one,
#' so that GDAL7 adds two names to the search path instead of two hundred.
#'
#' A constant that the GDAL in use is too old to declare is absent from the
#' vector. See [gdal7_capabilities()] for the same question about bindings.
#'
#' @param prefix Optional. Keep only the constants whose names start with this.
#' @return A named integer vector.
#' @examples
#' head(gdal_constants("GDT_"))
#' gdal_constants("GA_")
#' @export
gdal_constants <- function(prefix = NULL) {
  values <- GDAL7_integer_constants()
  if (is.null(prefix)) {
    return(values)
  }
  values[startsWith(names(values), prefix)]
}

#' GDAL's string constants
#'
#' The metadata and capability keys GDAL declares: driver metadata
#' (`DMD_*`), driver capabilities (`DCAP_*`), dataset capabilities (`GDsC*`)
#' and dimension types (`DIM_TYPE_*`). These are the keys to pass to
#' [get_metadata_item()] and [test_capability()].
#'
#' @param prefix Optional. Keep only the constants whose names start with this.
#' @return A named character vector.
#' @examples
#' head(gdal_string_constants("DCAP_"))
#' @export
gdal_string_constants <- function(prefix = NULL) {
  values <- GDAL7_string_constants()
  if (is.null(prefix)) {
    return(values)
  }
  values[startsWith(names(values), prefix)]
}

#' What this build of GDAL7 can reach
#'
#' Some bindings call GDAL functions that are newer than GDAL7's own minimum.
#' Those bindings always exist, so that loading the package never depends on
#' which GDAL it was built against, but calling one that the GDAL in use is too
#' old for raises an error naming the release it needs. This is how to ask
#' first.
#'
#' A binding not listed here needs nothing newer than GDAL7's minimum and is
#' always available.
#'
#' @return A data frame with one row per guarded binding: `binding`, the GDAL
#'   release it needs (`gdal`), and whether this build has it (`available`).
#' @examples
#' gdal7_capabilities()
#' @export
gdal7_capabilities <- function() {
  info <- GDAL7_capabilities()
  data.frame(
    binding = info$binding,
    gdal = info$gdal,
    available = info$available,
    stringsAsFactors = FALSE
  )
}

#' The GDAL library GDAL7 is running against
#'
#' @return A named character vector: the `release` name, its `date`, and the
#'   full `version` string GDAL reports.
#' @examples
#' gdal_version()
#' @export
gdal_version <- function() {
  info <- GDAL7_gdal_version()
  stats::setNames(info, c("release", "date", "version"))
}
