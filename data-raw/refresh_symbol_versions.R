# data-raw/refresh_symbol_versions.R
#
# Record the GDAL release each C symbol the generator emits first appeared in.
#
# GDAL's SWIG interface files carry no version information at all, so a
# generated binding that calls a function added in GDAL 3.12 would simply fail
# to link against 3.10. This script answers "since when?" by looking, which is
# the only answer that stays right: it reads GDAL's own public headers at each
# release tag and records the first tag where the symbol appears.
#
# The result is data-raw/gdal-symbol-versions.csv, which the generators read.
# Re-run it after refreshing the API model against a newer GDAL:
#
#   Rscript data-raw/refresh_symbol_versions.R
#
# It needs network access; nothing else in the pipeline does.

source("data-raw/parse_swig.R")
source("data-raw/api_model.R")

TAGS <- c("v3.8.0", "v3.9.0", "v3.10.0", "v3.11.0", "v3.12.0", "v3.13.0")

HEADERS <- c(
  "gcore/gdal.h",
  "gcore/gdal_rat.h",
  "gcore/gdalalgorithm.h",
  # Split out of gdalalgorithm.h in 3.12. Both are read, so a symbol is found
  # whichever side of that move the release is on.
  "gcore/gdalalgorithm_c.h",
  "gcore/gdal_version.h.in",
  "port/cpl_conv.h",
  "port/cpl_error.h",
  "port/cpl_minixml.h",
  "port/cpl_port.h",
  "port/cpl_string.h",
  "port/cpl_vsi.h",
  "alg/gdalwarper.h",
  "ogr/ogr_core.h",
  "ogr/ogr_api.h",
  "ogr/ogr_srs_api.h"
)

version_of_tag <- function(tag) sub("^v", "", tag)

read_headers <- function(tag) {
  texts <- vapply(HEADERS, function(path) {
    url <- sprintf("https://raw.githubusercontent.com/OSGeo/gdal/%s/%s", tag, path)
    text <- tryCatch(paste(readLines(url, warn = FALSE), collapse = "\n"),
                     error = function(e) "")
    # A path that does not exist at this tag answers with GitHub's 404 page.
    if (grepl("^404: Not Found", text)) "" else text
  }, character(1))
  paste(texts, collapse = "\n")
}

# The symbols the hand-written bindings call, read out of them rather than
# listed here, so a guard in src/GDAL7_algorithm.cpp or inst/include/gdal7.h
# rests on the same recorded table as a generated one. Anything that is not
# actually a GDAL function, a macro or a type name, costs one row in the CSV
# and nothing else.
hand_written_symbols <- function() {
  files <- c(list.files("src", pattern = "\\.cpp$", full.names = TRUE),
             "inst/include/gdal7.h")
  files <- files[file.exists(files)]

  symbols <- character()
  for (file in files) {
    text <- paste(readLines(file, warn = FALSE), collapse = "\n")
    # A call: a GDAL, OGR, OSR, CPL or VSI name with an opening bracket after
    # it.
    matches <- regmatches(text, gregexpr("\\b(GDAL|OGR|OSR|CPL|VSI)[A-Za-z0-9_]*\\s*\\(", text))[[1]]
    symbols <- c(symbols, trimws(sub("\\($", "", trimws(matches))))
  }

  # GDAL7's own bindings are named for what they wrap, so they match the same
  # pattern. They are not GDAL symbols.
  symbols <- symbols[!grepl("^GDAL7_", symbols)]
  sort(unique(symbols))
}

symbols_to_check <- function(model) {
  symbols <- hand_written_symbols()

  for (cls in model$classes) {
    for (method in cls$methods) {
      if (!is.null(method$c_call)) {
        symbols <- c(symbols, method$c_call$func)
      }
    }
    for (member in cls$members) {
      if (!is.null(member$c_call)) {
        symbols <- c(symbols, member$c_call$func)
      }
    }
  }

  for (const in model$constants) {
    # A constant whose value is a literal needs no lookup; it is not a symbol.
    if (!grepl('^"', const$value)) {
      symbols <- c(symbols, const$value)
    }
  }

  sort(unique(symbols))
}

main <- function() {
  # The vendored model unless a GDAL checkout is there to re-extract from, so
  # this runs anywhere with network rather than only on a machine with GDAL's
  # sources.
  swig_dir <- "~/gdal/swig/include"
  model <- if (dir.exists(path.expand(swig_dir))) {
    build_api_model(swig_dir = swig_dir)
  } else {
    message("No GDAL checkout at ", swig_dir, "; using the vendored API model")
    read_api_model()
  }
  symbols <- symbols_to_check(model)
  message(sprintf("Checking %d symbols across %d releases", length(symbols), length(TAGS)))

  since <- rep(NA_character_, length(symbols))
  names(since) <- symbols

  for (tag in TAGS) {
    message(sprintf("  reading headers at %s", tag))
    text <- read_headers(tag)
    pending <- symbols[is.na(since[symbols])]
    found <- vapply(pending, function(sym) {
      grepl(paste0("\\b", sym, "\\b"), text)
    }, logical(1))
    since[pending[found]] <- version_of_tag(tag)
  }

  missing <- symbols[is.na(since[symbols])]
  if (length(missing) > 0) {
    message(sprintf("Not found in any scanned release (%d):", length(missing)))
    message(paste(" ", missing, collapse = "\n"))
    message("These are newer than ", tail(TAGS, 1),
            "; the generators will leave them out until a newer tag is scanned.")
  }

  out <- data.frame(symbol = symbols, since = unname(since[symbols]),
                    stringsAsFactors = FALSE)
  write.csv(out, "data-raw/gdal-symbol-versions.csv", row.names = FALSE,
            quote = FALSE, na = "")
  message("Wrote data-raw/gdal-symbol-versions.csv")
}

if (!exists("SOURCED")) {
  main()
}
