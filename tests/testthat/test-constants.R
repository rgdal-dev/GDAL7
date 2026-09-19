test_that("GDAL's enumerators reach R with their GDAL names", {
  types <- gdal_constants("GDT_")

  expect_type(types, "integer")
  expect_true(all(nzchar(names(types))))
  expect_identical(unname(types[["GDT_Unknown"]]), 0L)
  expect_identical(unname(types[["GDT_Byte"]]), 1L)

  # The value is the one GDAL reports for a band of that type, which is the
  # whole point of having the table.
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))
  band <- get_raster_band(ds, 1)
  expect_identical(band@data_type, unname(types[["GDT_Int16"]]))
})

test_that("constants cover the other enumerations too", {
  expect_identical(unname(gdal_constants("GA_")[["GA_ReadOnly"]]), 0L)
  expect_identical(unname(gdal_constants("GF_")[["GF_Read"]]), 0L)
  expect_true("GCI_Undefined" %in% names(gdal_constants("GCI_")))
  expect_true("GRA_NearestNeighbour" %in% names(gdal_constants("GRA_")))
  expect_true("CE_Failure" %in% names(gdal_constants("CE_")))
})

test_that("a prefix filters and an unknown prefix gives nothing", {
  all_constants <- gdal_constants()
  expect_gt(length(all_constants), 100)
  expect_true(all(startsWith(names(gdal_constants("OF_")), "OF_")))
  expect_length(gdal_constants("NOT_A_PREFIX_"), 0)
})

test_that("string constants are the metadata keys they name", {
  keys <- gdal_string_constants()

  expect_type(keys, "character")
  expect_identical(unname(keys[["DMD_LONGNAME"]]), "DMD_LONGNAME")
  expect_identical(unname(keys[["DCAP_RASTER"]]), "DCAP_RASTER")

  # A key is only useful if a driver answers to it.
  driver <- gdal_get_driver_by_name("GTiff")
  expect_true(nzchar(get_metadata_item(driver, keys[["DMD_LONGNAME"]], "")))
  expect_true(test_capability(driver, keys[["DCAP_RASTER"]]))
})

test_that("gdal_release reports the library actually loaded", {
  version <- gdal_release()

  expect_named(version, c("release", "date", "version"))
  expect_match(version[["release"]], "^[0-9]+\\.[0-9]+")
  expect_match(version[["version"]], "^GDAL ")
  expect_true(startsWith(version[["version"]], paste0("GDAL ", version[["release"]])))
})

test_that("the capability table says what this build reaches", {
  capabilities <- gdal7_capabilities()

  expect_s3_class(capabilities, "data.frame")
  expect_named(capabilities, c("binding", "gdal", "available"))
  expect_type(capabilities$available, "logical")
  expect_true(all(grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", capabilities$gdal)))

  # Availability is not a guess: it is whether this GDAL is new enough.
  running <- package_version(gdal_release()[["release"]])
  expect_identical(capabilities$available,
                   package_version(capabilities$gdal) <= running)
})

test_that("a binding the GDAL in use is too old for says so", {
  capabilities <- gdal7_capabilities()
  missing <- capabilities[!capabilities$available, ]
  skip_if(nrow(missing) == 0, "this GDAL is new enough for every binding")

  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  # mark_suppress_on_close is the one guarded binding that takes nothing else.
  skip_if(!"dataset_mark_suppress_on_close" %in% missing$binding)
  expect_error(mark_suppress_on_close(ds), "needs GDAL 3\\.12\\.0 or newer")
})

test_that("the vendored API model records what it was extracted from", {
  path <- system.file("api", "gdal-api.json", package = "GDAL7")
  expect_true(nzchar(path))

  text <- readLines(path, warn = FALSE)
  expect_match(paste(text, collapse = "\n"),
               '"gdal_version"\\s*:\\s*"[0-9]+\\.[0-9]+\\.[0-9]+"')
})
