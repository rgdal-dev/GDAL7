# Creating datasets, writing to them, and what a driver will accept.

# ============================================================================
# What a driver accepts
# ============================================================================

test_that("a driver's options are a table, not a string of XML", {
  options <- driver_options("GTiff")

  expect_s3_class(options, "data.frame")
  expect_named(options, c("name", "type", "description", "default", "min",
                          "max", "required", "scope", "choices"))
  expect_true(nrow(options) > 10)
  expect_true(all(c("COMPRESS", "TILED", "BLOCKXSIZE") %in% options$name))

  # An option with a fixed set of values carries them.
  expect_true("DEFLATE" %in% options$choices[[which(options$name == "COMPRESS")]])
  expect_identical(options$type[options$name == "TILED"], "boolean")

  # A range is carried as numbers where the driver declares one. Which
  # options declare a range is a matter for the GDAL in front of us: GTiff
  # gained most of its ranges after 3.8, so what is checked here is that a
  # range reads back as a number, not that any given option has one.
  expect_type(options$min, "double")
  expect_type(options$max, "double")
  ranged <- options[!is.na(options$min) | !is.na(options$max), ]
  if (nrow(ranged) > 0) {
    expect_true(all(is.finite(c(ranged$min, ranged$max)) | is.na(c(ranged$min, ranged$max))))
  }
})

test_that("open options are a different list from creation options", {
  creation <- driver_options("GTiff", "creation")
  open <- driver_options("GTiff", "open")

  expect_s3_class(open, "data.frame")
  expect_false(identical(sort(creation$name), sort(open$name)))
})

test_that("a driver with nothing to say gives an empty table", {
  skip_if_no_driver("MEM")

  # Whatever this build's MEM driver declares, the shape is the same.
  options <- driver_options("MEM")
  expect_s3_class(options, "data.frame")
  expect_named(options, c("name", "type", "description", "default", "min",
                          "max", "required", "scope", "choices"))
})

test_that("a driver that is not there is said so by name", {
  expect_error(driver_options("NoSuchDriver"), "no driver called 'NoSuchDriver'")
  expect_error(driver_options(42), "GDALDriver or a single driver name")
})

test_that("options are checked against the driver before anything is made", {
  expect_true(validate_creation_options("GTiff", c(COMPRESS = "DEFLATE")))
  expect_false(validate_creation_options("GTiff", c(COMPRES = "DEFLATE")))

  # The three ways of writing them mean the same thing.
  expect_true(validate_creation_options("GTiff", list(TILED = TRUE)))
  expect_true(validate_creation_options("GTiff", "TILED=YES"))
  expect_true(validate_creation_options("GTiff", NULL))

  expect_error(validate_creation_options("GTiff", "TILED"),
               "already written as")
})

# ============================================================================
# Creating
# ============================================================================

test_that("a dataset is created with the size and type asked for", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 10, 20, bands = 3, type = "Int16")
  on.exit(gdal_close(ds), add = TRUE)

  expect_identical(ds@raster_xsize, 10L)
  expect_identical(ds@raster_ysize, 20L)
  expect_identical(ds@raster_count, 3L)
  expect_identical(get_raster_band(ds, 1)@data_type_name, "Int16")
})

test_that("a bad creation option is refused, quoting GDAL's own reason", {
  path <- tempfile(fileext = ".tif")

  # GDAL's complaint is the message, so the option that is wrong is named.
  # A name the driver does not have, and a value it will not take.
  expect_error(gdal_create(path, 4, 4, options = c(COMPRES = "DEFLATE")),
               "COMPRES")
  expect_error(gdal_create(path, 4, 4, options = c(COMPRESS = "NOT_A_CODEC")),
               "COMPRESS")

  # And nothing was created.
  expect_false(file.exists(path))
})

test_that("what cannot be created is said before anything is attempted", {
  path <- tempfile(fileext = ".tif")

  expect_error(gdal_create(path, 4, 4, type = "Float128"), "not a GDAL data type")
  expect_error(gdal_create(path, 4, 4, driver = "NoSuchDriver"),
               "no driver called 'NoSuchDriver'")
  expect_error(gdal_create(path, 0, 4), "positive width and height")

  # Some drivers write only by copying, which is a different function. Which
  # ones is a matter for the GDAL in front of us: COG gained Create() in 3.13,
  # so the driver is found by asking rather than by being named here.
  drivers <- gdal_drivers()
  copy_only <- drivers$short_name[drivers$raster & drivers$copy & !drivers$create]
  skip_if(length(copy_only) == 0, "this GDAL has no copy-only raster driver")

  expect_error(gdal_create(path, 4, 4, driver = copy_only[1]),
               "cannot create a dataset from nothing")
})

# ============================================================================
# Writing
# ============================================================================

test_that("values written come back unchanged, in the same order", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 8, 4, bands = 1, type = "Float32")
  values <- as.double(seq_len(32))
  write_raster(ds, list(values))
  gdal_close(ds)

  ds <- gdal_open(path)
  on.exit(gdal_close(ds), add = TRUE)
  expect_identical(read_raster(ds)[[1]], values)

  # The documented order: first row first, x varying fastest.
  band <- get_raster_band(ds, 1)
  expect_identical(read_raster(band, window = c(0, 0, 8, 1)), as.double(1:8))
  expect_identical(read_raster(band, window = c(0, 1, 8, 1)), as.double(9:16))
})

test_that("a window is written where it was asked for", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4, bands = 1, type = "Byte")
  write_raster(ds, list(rep(0, 16)))

  band <- get_raster_band(ds, 1)
  write_raster(band, rep(7, 4), window = c(1, 1, 2, 2))
  gdal_close(ds)

  ds <- gdal_open(path)
  on.exit(gdal_close(ds), add = TRUE)
  values <- matrix(read_raster(ds)[[1]], nrow = 4, byrow = TRUE)
  expect_identical(values[2:3, 2:3], matrix(7, 2, 2))
  expect_identical(sum(values), 28)
})

test_that("several bands are written in one pass", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4, bands = 3, type = "Byte")
  write_raster(ds, list(rep(1, 16), rep(2, 16), rep(3, 16)))
  gdal_close(ds)

  ds <- gdal_open(path)
  on.exit(gdal_close(ds), add = TRUE)
  values <- read_raster(ds)
  expect_length(values, 3L)
  expect_identical(vapply(values, function(v) v[[1]], double(1)),
                   c("1" = 1, "2" = 2, "3" = 3))
})

test_that("values of the wrong length are refused rather than truncated", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4, bands = 2, type = "Byte")
  on.exit(gdal_close(ds), add = TRUE)

  expect_error(write_raster(ds, list(rep(1, 15), rep(2, 16))),
               "15 values for a 4 by 4 block")
  expect_error(write_raster(ds, list(rep(1, 16))), "1 blocks of values for 2")
  expect_error(write_raster(ds, rep(1, 16)), "list of one vector per band")
  expect_error(write_raster(get_raster_band(ds, 1), rep(1, 15)),
               "15 values for a 4 by 4 block")
})

test_that("writing to a dataset opened read-only fails rather than pretends", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds), add = TRUE)

  expect_error(write_raster(ds, list(rep(1, 400), rep(1, 400))))
})

test_that("a flush makes what is written readable while still open", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4, bands = 1, type = "Byte")
  on.exit(gdal_close(ds), add = TRUE)

  write_raster(ds, list(as.double(seq_len(16))))
  gdal_flush(ds)

  # A TIFF flushed but not closed can still have an incomplete strip table,
  # which some libtiff builds warn about and work around while others say
  # nothing. Either way the values are there, which is what is being tested.
  other <- suppressWarnings(gdal_open(path))
  on.exit(gdal_close(other), add = TRUE)
  expect_identical(read_raster(other)[[1]], as.double(seq_len(16)))
})

# ============================================================================
# The properties a created dataset needs
# ============================================================================

test_that("a coordinate reference system goes in however it is written", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4)
  on.exit(gdal_close(ds), add = TRUE)

  ds@crs <- "EPSG:3857"
  expect_match(ds@projection, "Pseudo-Mercator")

  # A PROJ string and WKT are the same offer.
  # The projection property is GDAL's WKT1, which spells a projection with
  # underscores and loses the name of one it has no code for.
  ds@crs <- "+proj=laea +lat_0=-90 +lon_0=0 +datum=WGS84"
  expect_match(ds@projection, "Lambert_Azimuthal_Equal_Area")

  ds@crs <- crs_to_wkt("EPSG:4326")
  expect_match(ds@projection, "WGS 84")
})

test_that("a CRS is written as WKT2 unless WKT1 is asked for", {
  expect_error(crs_to_wkt("EPSG:notanumber"), "as a coordinate reference system")

  # WKT2 keeps what WKT1 cannot: the projection below has no EPSG code, and
  # WKT1 writes it out as "unknown".
  expect_match(crs_to_wkt("EPSG:4326"), "^GEOGCRS")
  expect_match(crs_to_wkt("EPSG:4326", "WKT1"), "^GEOGCS")

  laea <- "+proj=laea +lat_0=-90 +lon_0=0 +datum=WGS84"
  expect_match(crs_to_wkt(laea), "Lambert Azimuthal Equal Area")
  expect_match(crs_to_wkt(laea, "WKT1"), "unknown")

  expect_true(grepl("\n", crs_to_wkt("EPSG:4326", multiline = TRUE), fixed = TRUE))
  expect_false(grepl("\n", crs_to_wkt("EPSG:4326"), fixed = TRUE))
})

test_that("what a band's values mean is set and read back", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4, bands = 1, type = "Int16")
  band <- get_raster_band(ds, 1)

  band@nodata_value <- -999
  band@scale <- 0.1
  band@offset <- 20
  band@unit_type <- "degC"

  expect_identical(band@nodata_value, -999)
  expect_identical(band@scale, 0.1)
  expect_identical(band@offset, 20)
  expect_identical(band@unit_type, "degC")

  # NULL takes the nodata value off rather than setting it to anything.
  band@nodata_value <- NULL
  expect_null(band@nodata_value)

  gdal_close(ds)
})

test_that("a colour interpretation is set by name", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4, bands = 3, type = "Byte")
  on.exit(gdal_close(ds), add = TRUE)

  band <- get_raster_band(ds, 1)
  band@color_interpretation <- "Red"
  expect_identical(get_raster_band(ds, 1)@color_interpretation_name, "Red")

  other <- get_raster_band(ds, 2)
  expect_error(other@color_interpretation <- "Puce",
               "not a colour interpretation")
})

# ============================================================================
# Copying: the exit criterion
# ============================================================================

test_that("a COG built from R is a COG by the driver's own account", {
  skip_if_no_driver("COG")

  # Big enough that the COG driver builds overviews, which is part of what
  # makes the layout what it is.
  source_path <- tempfile(fileext = ".tif")
  ds <- gdal_create(source_path, 512, 512, bands = 1, type = "Float32")
  ds@geotransform <- c(0, 1, 0, 512, 0, -1)
  ds@crs <- "EPSG:3857"
  write_raster(ds, list(as.double(seq_len(512 * 512))))
  gdal_close(ds)

  path <- tempfile(fileext = ".tif")
  out <- gdal_create_copy(source_path, path, driver = "COG",
                          options = c(COMPRESS = "DEFLATE", BLOCKSIZE = "128"),
                          progress = FALSE)
  gdal_close(out)

  cog <- gdal_open(path)
  on.exit(gdal_close(cog), add = TRUE)
  band <- get_raster_band(cog, 1)

  # GDAL's GTiff driver reports the layout it recognised on the way in, which
  # is the format's own verdict rather than this package's.
  expect_identical(get_metadata_item(cog, "LAYOUT", "IMAGE_STRUCTURE"), "COG")
  expect_identical(get_metadata_item(cog, "COMPRESSION", "IMAGE_STRUCTURE"),
                   "DEFLATE")
  expect_identical(unname(band@block_size), c(128L, 128L))
  expect_true(band@overview_count >= 1L)

  # And it holds what went in.
  expect_identical(read_raster(band, window = c(0, 0, 8, 1)), as.double(1:8))
  expect_match(cog@projection, "Pseudo-Mercator")
})

test_that("a copy takes a dataset as well as a path", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds), add = TRUE)

  out <- gdal_create_copy(ds, path, progress = FALSE)
  expect_identical(out@raster_count, ds@raster_count)
  gdal_close(out)
})

test_that("a copy draws a progress bar when asked and is silent when not", {
  path <- tempfile(fileext = ".tif")
  drawn <- capture.output(
    gdal_close(gdal_create_copy(test_tif(), path, progress = TRUE))
  )
  expect_true(any(grepl("=", drawn, fixed = TRUE)))

  path2 <- tempfile(fileext = ".tif")
  silent <- capture.output(
    gdal_close(gdal_create_copy(test_tif(), path2, progress = FALSE))
  )
  expect_length(silent, 0L)
})

test_that("a dataset is deleted through its driver, sidecars and all", {
  path <- tempfile(fileext = ".tif")
  ds <- gdal_create(path, 4, 4)
  set_metadata_item(ds, "NOTE", "something", "")
  gdal_close(ds)
  expect_true(file.exists(path))

  gdal_delete(path)
  expect_false(file.exists(path))
  expect_false(file.exists(paste0(path, ".aux.xml")))
})

# ============================================================================
# Thread-safe datasets
# ============================================================================

test_that("a GDAL without thread-safe datasets says which release it needs", {
  caps <- gdal7_capabilities()
  skip_if(caps$available[caps$binding == "dataset_get_thread_safe_dataset"],
          "this GDAL has thread-safe datasets")

  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds), add = TRUE)

  expect_error(is_thread_safe(ds), "3\\.10")
  expect_error(get_thread_safe_dataset(ds), "3\\.10")
})

test_that("a thread-safe view reads the same as the dataset it came from", {
  skip_if_no_capability("dataset_get_thread_safe_dataset")

  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds), add = TRUE)

  expect_false(is_thread_safe(ds))

  safe <- get_thread_safe_dataset(ds)
  on.exit(gdal_close(safe), add = TRUE)

  expect_true(is_thread_safe(safe))
  expect_identical(read_raster(safe, out_size = c(4, 4)),
                   read_raster(ds, out_size = c(4, 4)))
})

test_that("a thread-safe view does not outlive its dataset", {
  skip_if_no_capability("dataset_get_thread_safe_dataset")

  ds <- gdal_open(test_tif())
  safe <- get_thread_safe_dataset(ds)

  gdal_close(ds)
  # The view is held by reference, so this is an R error rather than a read of
  # freed memory.
  expect_error(read_raster(safe), "has been closed")

  # Closing the dataset while a view of it is alive must not delete it out from
  # under the view: GDAL took a reference when the view was made, and the view
  # gives it back when it goes. Getting this wrong corrupts the heap rather
  # than failing here, so the check is that GDAL still works afterwards.
  rm(safe)
  gc()
  again <- gdal_open(test_tif())
  on.exit(gdal_close(again), add = TRUE)
  expect_identical(again@raster_xsize, 20L)
})

test_that("a thread-safe view survives the garbage collector", {
  skip_if_no_capability("dataset_get_thread_safe_dataset")

  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds), add = TRUE)

  for (i in 1:50) {
    safe <- get_thread_safe_dataset(ds)
    expect_identical(safe@raster_xsize, ds@raster_xsize)
    rm(safe)
    gc()
  }
  expect_identical(ds@raster_xsize, 20L)
})

# ============================================================================
# The driver table
# ============================================================================

test_that("every driver arrives in one table", {
  drivers <- gdal_drivers()

  expect_s3_class(drivers, "data.frame")
  expect_named(drivers, c("short_name", "long_name", "raster", "vector",
                          "multidim", "create", "copy", "vsi", "extensions"))
  expect_true(nrow(drivers) > 5)
  expect_true("GTiff" %in% drivers$short_name)
  expect_true(drivers$create[drivers$short_name == "GTiff"])
})

test_that("the table is filtered by GDAL's own capability names", {
  creatable <- gdal_drivers("DCAP_CREATE")
  expect_true(all(creatable$create))
  expect_true(nrow(creatable) < nrow(gdal_drivers()))

  both <- gdal_drivers(c("DCAP_RASTER", "DCAP_CREATE"))
  expect_true(all(both$raster & both$create))

  expect_error(gdal_drivers("DCAP_NONSENSE"), "Cannot filter on DCAP_NONSENSE")
})
