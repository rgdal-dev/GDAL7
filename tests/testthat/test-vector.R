skip_if_no_driver("GPKG")

test_that("a dataset lists its layers", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))

  layers <- ds@layers

  expect_s3_class(layers, "data.frame")
  expect_identical(layers$name, "places")
  expect_identical(layers$geometry_type, "Point")
  expect_identical(layers$feature_count, 5)
  expect_true(layers$fast_arrow)
})

test_that("a layer can be taken by position or by name", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))

  by_index <- get_layer(ds, 1)
  by_name <- get_layer(ds, "places")

  expect_s3_class(by_index, "GDAL7::GDALLayer")
  expect_identical(by_index@name, by_name@name)
  expect_match(by_name@crs, "WGS 84")
  expect_identical(by_name@geometry_type, "Point")
})

test_that("a missing layer is an error rather than a null pointer", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))

  expect_error(get_layer(ds, "no_such_layer"), "no_such_layer")
  expect_error(get_layer(ds, 99), "no layer at that index")
})

test_that("a layer reads to a data frame with WKB geometry", {
  places <- read_vector(test_gpkg())

  expect_s3_class(places, "data.frame")
  expect_identical(nrow(places), 5L)
  expect_true(all(c("name", "population", "elevation") %in% names(places)))
  expect_identical(places$name,
                   c("Hobart", "Melbourne", "Sydney", "Perth", "Darwin"))

  # Geometry is WKB: a raw vector per feature, little-endian point (1, 1).
  expect_true(is.list(places$geom))
  expect_true(all(vapply(places$geom, is.raw, logical(1))))
  expect_identical(as.raw(places$geom[[1]])[1:5],
                   as.raw(c(0x01, 0x01, 0x00, 0x00, 0x00)))
})

test_that("the extent is the one GDAL reports", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))

  extent <- get_extent(get_layer(ds, 1))

  expect_named(extent, c("xmin", "ymin", "xmax", "ymax"))
  expect_equal(unname(extent), c(115.8605, -42.8826, 151.2093, -12.4634),
               tolerance = 1e-6)
})

test_that("an attribute filter applies to counting and to reading", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))
  layer <- get_layer(ds, 1)

  set_filter(layer, where = "population > 1000000")
  expect_identical(feature_count(layer), 3)
  expect_identical(read_vector(layer)$name, c("Melbourne", "Sydney", "Perth"))

  set_filter(layer, where = NULL)
  expect_identical(feature_count(layer), 5)
})

test_that("a spatial filter applies to counting and to reading", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))
  layer <- get_layer(ds, 1)

  set_filter(layer, bbox = c(140, -45, 155, -30))
  expect_identical(feature_count(layer), 3)
  expect_identical(read_vector(layer)$name, c("Hobart", "Melbourne", "Sydney"))

  set_filter(layer, bbox = NULL)
  expect_identical(feature_count(layer), 5)
})

test_that("a bad filter reaches the caller as GDAL's own complaint", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))
  layer <- get_layer(ds, 1)

  # The driver hands the clause to SQLite when the layer is next used rather
  # than when the filter is set, so this is where it goes wrong, and GDAL
  # reports it as a warning rather than a failure.
  set_filter(layer, where = "no_such_column > 1")
  expect_warning(feature_count(layer), "no such column")
})

test_that("a bounding box that is not one is refused", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))
  layer <- get_layer(ds, 1)

  expect_error(set_filter(layer, bbox = c(1, 2, 3)), "4 numbers")
})

test_that("SQL returns a layer that reads like any other", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))

  result <- execute_sql(
    ds, "SELECT name, population FROM places ORDER BY population DESC LIMIT 2")

  expect_s3_class(result, "GDAL7::GDALLayer")
  rows <- read_vector(result)
  expect_identical(rows$name, c("Sydney", "Melbourne"))
})

test_that("a statement with no result set returns NULL", {
  path <- test_gpkg_copy()
  on.exit(unlink(path))

  ds <- gdal_open(path, update = TRUE)
  on.exit(gdal_close(ds), add = TRUE, after = FALSE)

  expect_null(execute_sql(ds, "CREATE INDEX ix_name ON places(name)"))
})

test_that("a failing statement is an error carrying GDAL's reason", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))

  expect_error(execute_sql(ds, "SELECT * FROM no_such_table"), "no_such_table")
})

test_that("the Arrow stream is handed out and given back", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))
  layer <- get_layer(ds, 1)

  stream <- arrow_stream(layer)
  expect_s3_class(stream, "nanoarrow_array_stream")

  # One stream at a time: the layer is only free again once it is released.
  expect_error(arrow_stream(layer), "Arrow stream")
  expect_silent(release_arrow_stream(stream))
  expect_silent(release_arrow_stream(stream))
  expect_s3_class(arrow_stream(layer), "nanoarrow_array_stream")
})

test_that("reading twice works, because read_vector gives the stream back", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))
  layer <- get_layer(ds, 1)

  expect_identical(nrow(read_vector(layer)), 5L)
  expect_identical(nrow(read_vector(layer)), 5L)
})

test_that("a layer stops working when its dataset is closed", {
  ds <- gdal_open(test_gpkg())
  layer <- get_layer(ds, 1)

  gdal_close(ds)

  expect_error(feature_count(layer), "has been closed")
  expect_error(read_vector(layer), "has been closed")
})

test_that("a GeoPackage layer round-trips", {
  places <- read_vector(test_gpkg())
  path <- tempfile(fileext = ".gpkg")
  on.exit(unlink(path))

  write_vector(places, path, layer = "places", crs = "EPSG:4326",
               geometry_type = "Point")
  back <- read_vector(path)

  expect_identical(names(back), names(places))
  expect_identical(back$fid, places$fid)
  expect_identical(back$name, places$name)
  expect_identical(back$population, places$population)
  expect_identical(back$elevation, places$elevation)
  expect_identical(lapply(back$geom, as.raw), lapply(places$geom, as.raw))
})

test_that("the written layer carries its type and its CRS", {
  places <- read_vector(test_gpkg())
  path <- tempfile(fileext = ".gpkg")
  on.exit(unlink(path))

  write_vector(places, path, layer = "cities", crs = "EPSG:4326",
               geometry_type = "Point")

  ds <- gdal_open(path)
  on.exit(gdal_close(ds), add = TRUE, after = FALSE)
  layer <- get_layer(ds, 1)

  expect_identical(layer@name, "cities")
  expect_identical(layer@geometry_type, "Point")
  expect_match(layer@crs, "WGS 84")
  expect_identical(feature_count(layer), 5)
})

test_that("a data frame with no geometry still writes", {
  path <- tempfile(fileext = ".gpkg")
  on.exit(unlink(path))

  write_vector(data.frame(name = c("a", "b"), value = c(1.5, 2.5)),
               path, layer = "plain")
  back <- read_vector(path)

  expect_identical(back$name, c("a", "b"))
  expect_identical(back$value, c(1.5, 2.5))
})

test_that("a geometry type GDAL does not know is refused by name", {
  path <- tempfile(fileext = ".gpkg")
  on.exit(unlink(path))

  expect_error(
    write_vector(data.frame(x = 1), path, geometry_type = "Trapezoid"),
    "Trapezoid is not a geometry type"
  )
})

test_that("feature ids too large for an integer are refused rather than wrapped", {
  path <- tempfile(fileext = ".gpkg")
  on.exit(unlink(path))

  huge <- data.frame(fid = 2^40, name = "far")
  expect_error(write_vector(huge, path), "too large for a 32-bit integer")
})

test_that("a layer names its id and geometry columns as its Arrow stream does", {
  ds <- gdal_open(test_gpkg())
  on.exit(gdal_close(ds))
  layer <- get_layer(ds, 1)
  expect_identical(layer@fid_column, "fid")
  expect_identical(layer@geometry_column, "geom")

  # A result set declares neither, and the stream falls back to GDAL's names.
  result <- execute_sql(ds, "SELECT name, geom FROM places")
  expect_identical(result@fid_column, "OGC_FID")
  expect_identical(result@geometry_column, "geom")
  expect_true(all(c(result@fid_column, result@geometry_column) %in%
                    names(read_vector(result))))

  bare <- execute_sql(ds, "SELECT name FROM places")
  expect_identical(bare@geometry_column, NA_character_)
})

test_that("a format that stores no column names gets GDAL's own", {
  skip_if_not("GeoJSON" %in% gdal_drivers()$short_name)
  path <- tempfile(fileext = ".geojson")
  on.exit(unlink(path))
  write_vector(read_vector(test_gpkg()), path, driver = "GeoJSON",
               geometry_type = "Point")
  ds <- gdal_open(path)
  on.exit(gdal_close(ds), add = TRUE, after = FALSE)
  layer <- get_layer(ds, 1)
  expect_true(all(c(layer@fid_column, layer@geometry_column) %in%
                    names(read_vector(layer))))
})
