# ============================================================================
# Vector data, by way of GDAL's Arrow API
#
# GDAL 3.6 added a column-oriented read path (RFC 86). A whole layer arrives as
# Arrow record batches, so reading is one call and costs no per-feature R work.
# ============================================================================

#' GDAL layer class
#'
#' @description S7 class wrapping an OGRLayer. A layer belongs to the dataset
#'   it came from, and stops working when that dataset is closed.
#'
#'   `fid_column` and `geometry_column` are the names those two columns have
#'   when the layer is read with [read_vector()] or [arrow_stream()]: the
#'   names the format declares when it stores them as named columns, and
#'   GDAL's own `OGC_FID` and `wkb_geometry` when it does not.
#'   `geometry_column` is `NA` for a layer with no geometry.
#' @param .ptr Internal. External pointer to the underlying GDAL object.
#' @export
GDALLayer <- S7::new_class(
  "GDALLayer",
  package = "GDAL7",

  properties = list(
    .ptr = S7::class_any,
    name = S7::new_property(
      S7::class_character,
      getter = function(self) GDAL7_layer_name(self@.ptr)
    ),
    geometry_type = S7::new_property(
      S7::class_character,
      getter = function(self) GDAL7_layer_geometry_type(self@.ptr)
    ),
    crs = S7::new_property(
      S7::class_character,
      getter = function(self) GDAL7_layer_crs(self@.ptr)
    ),
    fid_column = S7::new_property(
      S7::class_character,
      getter = function(self) arrow_column_name(GDAL7_layer_fid_column(self@.ptr), "OGC_FID")
    ),
    geometry_column = S7::new_property(
      S7::class_character,
      getter = function(self) {
        if (identical(GDAL7_layer_geometry_type(self@.ptr), "None")) {
          return(NA_character_)
        }
        arrow_column_name(GDAL7_layer_geometry_column(self@.ptr), "wkb_geometry")
      }
    )
  ),

  validator = function(self) {
    if (is.null(self@.ptr)) {
      "GDALLayer pointer cannot be NULL"
    }
  }
)

# The name a column has in the layer's Arrow stream. GDAL declares one for the
# feature id and the geometry only when the format stores them as named
# columns (a GeoPackage does, a shapefile does not); otherwise the stream names
# them itself, OGC_FID and wkb_geometry, which is what the stream is read as.
arrow_column_name <- function(declared, fallback) {
  if (length(declared) == 0L || is.na(declared) || !nzchar(declared)) fallback else declared
}

# ----------------------------------------------------------------------------
# Finding layers
# ----------------------------------------------------------------------------

# The body behind the dataset's layers property, which is declared in the
# generated class file. One row per layer: its name, geometry_type,
# feature_count, and whether the driver has a native Arrow fast path
# (fast_arrow). A feature count the driver would have to scan for is NA.
dataset_layers <- function(x) {
  names <- GDAL7_dataset_layer_names(x@.ptr)

  layers <- lapply(seq_along(names), function(i) get_layer(x, i))

  data.frame(
    name = names,
    geometry_type = vapply(layers, function(l) l@geometry_type, character(1)),
    feature_count = vapply(layers, feature_count, double(1)),
    fast_arrow = vapply(layers, function(l) {
      test_capability(l, "FastGetArrowStream")
    }, logical(1)),
    stringsAsFactors = FALSE
  )
}

#' Get a layer from a dataset
#'
#' @param x A GDALDataset object.
#' @param layer The layer to take: its name, or its position counting from 1.
#' @return A GDALLayer object.
#' @examples
#' ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
#' get_layer(ds, 1)
#' gdal_close(ds)
#' @export
get_layer <- S7::new_generic("get_layer", "x", function(x, layer = 1) {
  S7::S7_dispatch()
})

S7::method(get_layer, GDALDataset) <- function(x, layer = 1) {
  ptr <- if (is.character(layer)) {
    GDAL7_dataset_layer_by_name(x@.ptr, layer)
  } else {
    # GDAL counts layers from zero; R counts from one.
    GDAL7_dataset_layer(x@.ptr, as.integer(layer) - 1L)
  }
  GDALLayer(.ptr = ptr)
}

#' Run an SQL statement against a dataset
#'
#' @param x A GDALDataset object.
#' @param sql The statement.
#' @param dialect The SQL dialect: `NULL` for the driver's own, `"SQLITE"` for
#'   GDAL's SQLite dialect, `"OGRSQL"` for GDAL's built-in one.
#' @return A GDALLayer holding the result set, or `NULL` for a statement that
#'   returns none. The result set is released when the layer is garbage
#'   collected, or when the dataset is closed.
#' @examples
#' ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
#' read_vector(execute_sql(ds, "SELECT name FROM places WHERE population > 1e6"))
#' gdal_close(ds)
#' @export
execute_sql <- S7::new_generic("execute_sql", "x", function(x, sql, dialect = NULL) {
  S7::S7_dispatch()
})

S7::method(execute_sql, GDALDataset) <- function(x, sql, dialect = NULL) {
  ptr <- GDAL7_dataset_execute_sql(x@.ptr, sql, as.character(dialect))
  if (is.null(ptr)) {
    return(NULL)
  }
  GDALLayer(.ptr = ptr)
}

# ----------------------------------------------------------------------------
# Asking a layer about itself
# ----------------------------------------------------------------------------

#' Count the features of a layer
#'
#' @param x A GDALLayer object.
#' @param force Count them by reading the layer when the driver does not know
#'   the answer already.
#' @return The number of features, or `NA` when the driver would have to scan
#'   the layer and `force` is `FALSE`. Any filter set on the layer applies.
#' @examples
#' ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
#' feature_count(get_layer(ds, 1))
#' gdal_close(ds)
#' @export
feature_count <- S7::new_generic("feature_count", "x", function(x, force = TRUE) {
  S7::S7_dispatch()
})

S7::method(feature_count, GDALLayer) <- function(x, force = TRUE) {
  GDAL7_layer_feature_count(x@.ptr, isTRUE(force))
}

#' The bounding box of a layer
#'
#' @param x A GDALLayer object.
#' @param force Compute it by reading the layer when the driver does not know
#'   it already.
#' @return A named numeric vector: `xmin`, `ymin`, `xmax`, `ymax`. All `NA`
#'   for an empty layer, or for one whose extent is not known and `force` is
#'   `FALSE`.
#' @examples
#' ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
#' get_extent(get_layer(ds, 1))
#' gdal_close(ds)
#' @export
get_extent <- S7::new_generic("get_extent", "x", function(x, force = TRUE) {
  S7::S7_dispatch()
})

S7::method(get_extent, GDALLayer) <- function(x, force = TRUE) {
  stats::setNames(GDAL7_layer_extent(x@.ptr, isTRUE(force)),
                  c("xmin", "ymin", "xmax", "ymax"))
}

S7::method(test_capability, GDALLayer) <- function(x, capability) {
  GDAL7_layer_test_capability(x@.ptr, capability)
}

S7::method(reset_reading, GDALLayer) <- function(x) {
  GDAL7_layer_reset_reading(x@.ptr)
  invisible(x)
}

#' Restrict which features a layer returns
#'
#' Both filters are set on the layer and stay set. They apply to everything
#' read afterwards, including [feature_count()] and [read_vector()]. Passing
#' `NULL` clears the filter.
#'
#' A spatial filter is what makes a large layer cheap: a driver with a spatial
#' index uses it rather than reading every feature.
#'
#' @param x A GDALLayer object.
#' A clause the driver cannot make sense of is not reported here: most drivers
#' hand it to their own engine when the layer is next used, so a bad clause
#' surfaces as a GDAL warning from [feature_count()] or [read_vector()].
#'
#' @param where An SQL WHERE clause without the WHERE, or `NULL` to clear it.
#' @param bbox Numeric of length 4, `c(xmin, ymin, xmax, ymax)` in the layer's
#'   own coordinates, or `NULL` to clear it.
#' @return The layer, invisibly.
#' @examples
#' ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
#' layer <- get_layer(ds, 1)
#' set_filter(layer, where = "population > 1e6")
#' feature_count(layer)
#' gdal_close(ds)
#' @export
set_filter <- S7::new_generic("set_filter", "x", function(x, where, bbox) {
  S7::S7_dispatch()
})

S7::method(set_filter, GDALLayer) <- function(x, where, bbox) {
  if (!missing(where)) {
    GDAL7_layer_set_attribute_filter(x@.ptr, as.character(where))
  }
  if (!missing(bbox)) {
    bbox <- as.double(bbox)
    if (length(bbox) != 0 && length(bbox) != 4) {
      stop("`bbox` must be 4 numbers: xmin, ymin, xmax, ymax", call. = FALSE)
    }
    GDAL7_layer_set_spatial_filter(x@.ptr, bbox)
  }
  invisible(x)
}

# ----------------------------------------------------------------------------
# Reading
# ----------------------------------------------------------------------------

#' The Arrow stream of a layer
#'
#' The layer as an ArrowArrayStream, which anything that speaks Arrow can
#' consume: nanoarrow, arrow, duckdb. [read_vector()] is this plus a conversion
#' to a data frame.
#'
#' The stream holds the layer open, and the layer holds its dataset open, so a
#' stream stays valid until it is released or the dataset is closed by hand.
#'
#' A layer allows one stream at a time. A stream is released when it is
#' collected, or at once by [release_arrow_stream()]; [read_vector()] does that
#' for you.
#'
#' @param x A GDALLayer object.
#' @param options Character vector of `KEY=VALUE` options for
#'   `OGR_L_GetArrowStream`, for instance `"MAX_FEATURES_IN_BATCH=1000"` or
#'   `"GEOMETRY_ENCODING=WKB"`.
#' @return A `nanoarrow_array_stream`.
#' @examples
#' ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
#' stream <- arrow_stream(get_layer(ds, 1))
#' nanoarrow::infer_nanoarrow_schema(stream)
#' gdal_close(ds)
#' @export
arrow_stream <- S7::new_generic("arrow_stream", "x", function(x, options = NULL) {
  S7::S7_dispatch()
})

S7::method(arrow_stream, GDALLayer) <- function(x, options = NULL) {
  GDAL7_layer_arrow_stream(x@.ptr, as.character(options))
}

#' Read a vector layer into a data frame
#'
#' The whole layer in one call, through GDAL's column-oriented Arrow API rather
#' than feature by feature. Geometry arrives as WKB, in a list column of raw
#' vectors, which is what every other R geometry package can read.
#'
#' @param x A GDALLayer object, or a GDALDataset, or a path or connection
#'   string to open.
#' @param layer When `x` is a dataset or a path: which layer, by name or by
#'   position. Ignored when `x` is already a layer.
#' @param where An SQL WHERE clause to apply first, or `NULL`.
#' @param bbox Numeric of length 4, `c(xmin, ymin, xmax, ymax)`, to apply
#'   first, or `NULL`.
#' @param options Character vector of `KEY=VALUE` options passed to
#'   `OGR_L_GetArrowStream`.
#' @return A data frame.
#' @examples
#' read_vector(system.file("extdata/test.gpkg", package = "GDAL7"))
#' @export
read_vector <- S7::new_generic(
  "read_vector", "x",
  function(x, layer = 1, where = NULL, bbox = NULL, options = NULL) {
    S7::S7_dispatch()
  }
)

S7::method(read_vector, GDALLayer) <-
  function(x, layer = 1, where = NULL, bbox = NULL, options = NULL) {
    if (!is.null(where)) {
      set_filter(x, where = where)
    }
    if (!is.null(bbox)) {
      set_filter(x, bbox = bbox)
    }
    convert_stream(arrow_stream(x, options))
  }

S7::method(read_vector, GDALDataset) <-
  function(x, layer = 1, where = NULL, bbox = NULL, options = NULL) {
    read_vector(get_layer(x, layer), where = where, bbox = bbox, options = options)
  }

S7::method(read_vector, S7::class_character) <-
  function(x, layer = 1, where = NULL, bbox = NULL, options = NULL) {
    ds <- gdal_open(x)
    on.exit(gdal_close(ds))
    read_vector(ds, layer = layer, where = where, bbox = bbox, options = options)
  }

#' Give an Arrow stream back to its layer
#'
#' A layer allows one Arrow stream at a time, so a stream taken with
#' [arrow_stream()] has to be released before the layer can be read again.
#' Doing nothing releases it too, when R next collects it.
#'
#' @param stream A stream from [arrow_stream()].
#' @return `NULL`, invisibly. Releasing a stream twice is harmless.
#' @examples
#' ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
#' stream <- arrow_stream(get_layer(ds, 1))
#' release_arrow_stream(stream)
#' gdal_close(ds)
#' @export
release_arrow_stream <- function(stream) {
  GDAL7_release_arrow_stream(stream)
  invisible(NULL)
}

# nanoarrow warns that it does not recognise GDAL's ogc.wkb extension type and
# is handing back the storage type instead. The storage type is the WKB this
# function documents returning, so the warning is about the intended result.
convert_stream <- function(stream) {
  # Take the stream before arranging to give it back. Without this, a failure
  # to open one would be raised a second time by on.exit re-evaluating the
  # promise, and the second error is the one the caller would see.
  force(stream)

  # A layer allows one Arrow stream at a time, so this one goes back as soon as
  # it has been read rather than whenever it is collected.
  on.exit(GDAL7_release_arrow_stream(stream), add = TRUE)

  withCallingHandlers(
    nanoarrow::convert_array_stream(stream),
    warning = function(w) {
      if (grepl("ogc.wkb", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    }
  )
}

# ----------------------------------------------------------------------------
# Writing
# ----------------------------------------------------------------------------

#' Write a data frame to a vector dataset
#'
#' The other direction of the same Arrow path: the data frame becomes one
#' record batch, GDAL creates the fields from its schema, and
#' `OGR_L_WriteArrowBatch` writes it.
#'
#' @param x A data frame. A list column of raw vectors is the geometry.
#' @param dsn Where to write it.
#' @param layer The layer name to create. Defaults to the file's base name.
#' @param driver The GDAL driver's short name.
#' @param crs The coordinate reference system, in anything GDAL accepts:
#'   WKT, `"EPSG:4326"`, a PROJ string. `NULL` for none.
#' @param geometry_type The geometry type of the layer, by GDAL's name for it,
#'   for instance `"Point"` or `"3D Polygon"`. `"Unknown"` lets the driver
#'   take whatever arrives.
#' @param geometry_column The column holding WKB geometry. The default finds
#'   the one list column of raw vectors, which is what [read_vector()] returns.
#' @param fid_column The column holding feature ids, which is a property of the
#'   layer rather than a field of it. The default uses a column called `fid` if
#'   there is one.
#' @param dataset_options,layer_options,write_options Character vectors of
#'   `KEY=VALUE` options for dataset creation, layer creation and the write.
#' @return `dsn`, invisibly.
#' @examples
#' places <- read_vector(system.file("extdata/test.gpkg", package = "GDAL7"))
#' path <- tempfile(fileext = ".gpkg")
#' write_vector(places, path, layer = "places", crs = "EPSG:4326")
#' identical(nrow(read_vector(path)), nrow(places))
#' unlink(path)
#' @export
write_vector <- function(x, dsn, layer = NULL, driver = "GPKG", crs = NULL,
                         geometry_type = "Unknown", geometry_column = NULL,
                         fid_column = NULL,
                         dataset_options = NULL, layer_options = NULL,
                         write_options = NULL) {
  x <- as.data.frame(x)
  if (is.null(layer)) {
    layer <- tools::file_path_sans_ext(basename(dsn))
  }

  geometry_column <- geometry_column %||% find_geometry_column(x)
  fid_column <- fid_column %||% if ("fid" %in% names(x)) "fid" else NULL

  # GDAL takes the geometry and the feature id from named columns, so these two
  # options are what make a plain data frame a layer. Neither column is a
  # field, so neither is created as one.
  skip <- character()
  if (!is.null(geometry_column)) {
    write_options <- c(write_options, paste0("GEOMETRY_NAME=", geometry_column))
    skip <- c(skip, geometry_column)
  }
  if (!is.null(fid_column)) {
    x[[fid_column]] <- as_feature_id(x[[fid_column]], fid_column)
    write_options <- c(write_options, paste0("FID=", fid_column))
    skip <- c(skip, fid_column)
  }

  ds <- GDALDataset(.ptr = GDAL7_create_vector_dataset(
    driver, dsn, as.character(dataset_options)))
  on.exit(gdal_close(ds))

  target <- GDALLayer(.ptr = GDAL7_dataset_create_layer(
    ds@.ptr, layer, as.character(crs), geometry_type,
    as.character(layer_options)))

  batch <- nanoarrow::as_nanoarrow_array(x)
  schema <- nanoarrow::infer_nanoarrow_schema(batch)

  GDAL7_layer_create_fields(target@.ptr, schema, skip, as.character(write_options))
  GDAL7_layer_write_arrow_batch(target@.ptr, schema, batch,
                                as.character(write_options))

  invisible(dsn)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# A 64-bit field arrives from Arrow as a double, and GDAL will only take a
# feature id as an integer. The values are ids, so they are whole numbers; what
# is worth refusing is one too large to be an R integer, rather than silently
# writing a different id.
as_feature_id <- function(column, name) {
  if (is.integer(column)) {
    return(column)
  }
  if (!is.numeric(column)) {
    stop("`", name, "` holds feature ids, so it must be numeric", call. = FALSE)
  }

  whole <- is.na(column) | column == trunc(column)
  if (!all(whole)) {
    stop("`", name, "` holds feature ids, so it cannot have fractional values",
         call. = FALSE)
  }
  if (any(abs(column) > .Machine$integer.max, na.rm = TRUE)) {
    stop("`", name, "` has feature ids too large for a 32-bit integer; ",
         "pass fid_column = NULL to write them as an ordinary field",
         call. = FALSE)
  }
  as.integer(column)
}

# The geometry is whichever column holds raw vectors, which is how it comes
# back from read_vector() whatever the driver called it.
find_geometry_column <- function(x) {
  is_wkb <- vapply(x, function(column) {
    is.list(column) && all(vapply(column, is.raw, logical(1)))
  }, logical(1))

  if (!any(is_wkb)) {
    return(NULL)
  }
  names(x)[which(is_wkb)[1]]
}

# ----------------------------------------------------------------------------
# Printing
# ----------------------------------------------------------------------------

#' @export
S7::method(print, GDALLayer) <- function(x, ...) {
  cat("<GDALLayer>\n")
  cat("  Name:       ", x@name, "\n", sep = "")
  cat("  Geometry:   ", x@geometry_type, "\n", sep = "")

  count <- feature_count(x, force = FALSE)
  if (!is.na(count)) {
    cat("  Features:   ", format(count, scientific = FALSE), "\n", sep = "")
  }

  crs <- x@crs
  if (!is.na(crs)) {
    cat("  CRS:        ", crs_label(crs), "\n", sep = "")
  }
  if (test_capability(x, "FastGetArrowStream")) {
    cat("  Arrow:      native\n")
  }
  invisible(x)
}

# The WKT of a CRS runs to many lines; its name is the useful part.
crs_label <- function(wkt) {
  name <- sub('^[A-Z]+\\[\"([^\"]+)\".*$', "\\1", wkt)
  if (identical(name, wkt)) substr(wkt, 1, 40) else name
}
