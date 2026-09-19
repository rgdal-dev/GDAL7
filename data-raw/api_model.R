# data-raw/api_model.R
#
# The API model: what GDAL7 knows about GDAL, extracted once from GDAL's SWIG
# interface files and then vendored as inst/api/gdal-api.json.
#
# Two things follow from vendoring it. The generators run from a clone with no
# GDAL checkout, which is what lets CI regenerate and diff on every commit. And
# "GDAL 3.14 added twelve methods" arrives as a reviewable change to one JSON
# file rather than as a mystery in the generated C++.

# Files parsed, in the order their classes are generated.
API_FILES <- c("MajorObject.i", "Dataset.i", "gdalconst.i")

# The class each file contributes, by its internal SWIG name. Naming them is
# what keeps the model stable when a file gains a class, which Dataset.i did.
API_CLASSES <- c(
  "MajorObject.i" = "GDALMajorObjectShadow",
  "Dataset.i" = "GDALDatasetShadow"
)

api_model_path <- function() "inst/api/gdal-api.json"

# Read the GDAL version from the checkout the SWIG files came out of, so the
# model records what it was extracted from.
read_gdal_version <- function(swig_dir) {
  version_file <- file.path(dirname(dirname(normalizePath(swig_dir))),
                            "gcore", "gdal_version.h.in")
  if (!file.exists(version_file)) {
    return(NA_character_)
  }
  lines <- readLines(version_file, warn = FALSE)
  part <- function(what) {
    m <- regmatches(lines, regexec(
      sprintf("^#\\s*define\\s+GDAL_VERSION_%s\\s+(\\d+)", what), lines))
    m <- Filter(function(x) length(x) == 2, m)
    if (length(m) == 0) NA_character_ else m[[1]][2]
  }
  major <- part("MAJOR")
  minor <- part("MINOR")
  rev <- part("REV")
  if (anyNA(c(major, minor, rev))) NA_character_ else paste(major, minor, rev, sep = ".")
}

# Strip a parsed method or member down to what the generators use, and attach
# the C call derived from its %extend body.
model_method <- function(method) {
  list(
    name = method$name,
    return_type = method$return_type,
    newobject = isTRUE(method$newobject),
    params = lapply(method$params, function(p) {
      list(
        name = p$name,
        type = p$type,
        default = if (is.null(p$default)) NA_character_ else p$default,
        typemap = p$typemap,
        output = isTRUE(p$output),
        nonnull = isTRUE(p$nonnull)
      )
    }),
    c_call = derive_c_call(method$body)
  )
}

model_member <- function(member) {
  list(
    name = member$name,
    type = member$type,
    c_call = derive_c_call(member$get_body)
  )
}

build_api_model <- function(swig_dir = "~/gdal/swig/include") {
  swig_dir <- path.expand(swig_dir)
  if (!dir.exists(swig_dir)) {
    stop("SWIG directory not found: ", swig_dir,
         "\nClone GDAL: git clone --depth 1 --filter=blob:none --sparse ",
         "https://github.com/OSGeo/gdal.git ~/gdal && ",
         "(cd ~/gdal && git sparse-checkout set swig/include gcore)")
  }

  classes <- list()
  constants <- list()

  for (file in API_FILES) {
    parsed <- parse_swig_file(file.path(swig_dir, file))

    if (length(parsed$constants) > 0) {
      constants <- c(constants, parsed$constants)
    }

    if (!file %in% names(API_CLASSES)) next
    wanted <- API_CLASSES[[file]]

    cls <- parsed$classes[[wanted]]
    if (is.null(cls)) {
      stop(sprintf("%s does not define %s any more", file, wanted))
    }

    classes[[length(classes) + 1]] <- list(
      file = file,
      internal_name = cls$internal_name,
      public_name = cls$public_name,
      parent = cls$parent,
      members = lapply(cls$members, model_member),
      methods = lapply(cls$methods, model_method)
    )
  }

  # A name repeated in gdalconst.i (several are, for backwards compatibility)
  # is the same constant; keep the first spelling.
  seen <- vapply(constants, function(x) x$name, character(1))
  constants <- constants[!duplicated(seen)]

  list(
    gdal_version = read_gdal_version(swig_dir),
    extracted = format(Sys.Date()),
    files = API_FILES,
    classes = classes,
    constants = constants
  )
}

write_api_model <- function(model, path = api_model_path()) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  json <- jsonlite::toJSON(model, pretty = TRUE, auto_unbox = TRUE,
                           null = "null", na = "null")
  writeLines(json, path)
  message(sprintf("Wrote %s", path))
  invisible(path)
}

read_api_model <- function(path = api_model_path()) {
  if (!file.exists(path)) {
    stop("No API model at ", path,
         "\nRun: Rscript data-raw/orchestrate.R --refresh")
  }
  normalise_api_model(jsonlite::fromJSON(path, simplifyVector = FALSE))
}

# JSON has one empty value and R has several. Put back the shapes the
# generators expect, so that reading the model and parsing the SWIG files give
# the same thing: NA for an absent string, NULL for an absent default, and a
# character vector rather than a list of strings.
normalise_api_model <- function(model) {
  na_if_null <- function(x) if (is.null(x)) NA_character_ else as.character(x)

  fix_call <- function(call) {
    if (is.null(call)) return(NULL)
    list(func = as.character(call$func), args = unlist(call$args, use.names = FALSE))
  }

  model$gdal_version <- na_if_null(model$gdal_version)

  model$classes <- lapply(model$classes, function(cls) {
    cls$parent <- na_if_null(cls$parent)
    cls$members <- lapply(cls$members, function(member) {
      member$c_call <- fix_call(member$c_call)
      member
    })
    cls$methods <- lapply(cls$methods, function(method) {
      method$c_call <- fix_call(method$c_call)
      method$params <- lapply(method$params, function(param) {
        param$typemap <- na_if_null(param$typemap)
        param$default <- if (is.null(param$default)) NULL else as.character(param$default)
        param
      })
      method
    })
    cls
  })

  model
}

# The recorded first GDAL release of each C symbol the model calls. See
# data-raw/refresh_symbol_versions.R for how it is produced.
read_symbol_versions <- function(path = "data-raw/gdal-symbol-versions.csv") {
  if (!file.exists(path)) {
    stop("No symbol version table at ", path,
         "\nRun: Rscript data-raw/refresh_symbol_versions.R")
  }
  table <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
  since <- table$since
  since[since == ""] <- NA_character_
  stats::setNames(since, table$symbol)
}
