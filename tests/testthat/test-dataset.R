test_that("a dataset opens and reports its shape", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_s3_class(ds, "GDAL7::GDALDataset")
  expect_s3_class(ds, "GDAL7::GDALMajorObject")

  expect_identical(get_raster_xsize(ds), 20L)
  expect_identical(get_raster_ysize(ds), 10L)
  expect_identical(get_raster_count(ds), 2L)
  expect_identical(get_layer_count(ds), 0L)
  expect_identical(get_gcpcount(ds), 0L)
})

test_that("opening a dataset that does not exist errors", {
  expect_error(gdal_open(file.path(tempdir(), "no-such-file.tif")))
})

test_that("projection comes back as WKT", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  wkt <- get_projection(ds)
  expect_type(wkt, "character")
  expect_match(wkt, "WGS 84")
  expect_identical(get_projection_ref(ds), wkt)
})

test_that("the dataset knows its own driver and files", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_identical(get_short_name(get_driver(ds)), "GTiff")
  expect_true(basename(test_tif()) %in% basename(get_file_list(ds)))
})

test_that("description round-trips and metadata is readable", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_identical(get_description(ds), test_tif())
  set_description(ds, "a new description")
  expect_identical(get_description(ds), "a new description")

  expect_type(get_metadata_domain_list(ds), "character")
  expect_type(get_metadata_list(ds, ""), "character")
  expect_type(get_metadata_item(ds, "AREA_OR_POINT", ""), "character")
})

test_that("using a dataset after close is an error, not a crash", {
  ds <- gdal_open(test_tif())
  gdal_close(ds)
  expect_error(get_raster_xsize(ds), "has been closed")
})

test_that("the dataset print method dispatches", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))
  out <- capture.output(print(ds))
  expect_match(out[1], "^<GDALDataset>$")
})

test_that("connection strings are not mangled by path normalisation", {
  # normalizePath() must not touch a DSN that is not a file on disk, or every
  # /vsi*/, WMTS: and NETCDF: string breaks (on Windows especially).
  dsn <- 'NETCDF:"nowhere.nc":var'
  expect_identical(GDAL7:::gdal_dsn(dsn), dsn)
  expect_identical(GDAL7:::gdal_dsn("/vsicurl/https://example.org/x.tif"),
                   "/vsicurl/https://example.org/x.tif")

  # A real file still gets resolved to an absolute path.
  expect_identical(GDAL7:::gdal_dsn(test_tif()), normalizePath(test_tif(), winslash = "/"))

  expect_error(GDAL7:::gdal_dsn(c("a", "b")), "single")
  expect_error(GDAL7:::gdal_dsn(NA_character_), "single")
})
