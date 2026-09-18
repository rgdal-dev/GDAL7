# The bindings in this file exist because the generator derived their C call
# from GDAL's own %extend body. They are here to prove that what it derived is
# what GDAL does.

test_that("the generator's derived calls reach GDAL", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  expect_match(get_file_list(ds), "test\\.tif$")
  expect_identical(get_gcpcount(ds), 0L)
  expect_match(get_projection(ds), "^(PROJCS|GEOGCS|PROJCRS|GEOGCRS)|^$")
  expect_identical(get_projection(ds), get_projection_ref(ds))
  expect_identical(get_layer_count(ds), 0L)
})

test_that("vector-side bindings answer on a raster dataset", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  # No field domains and no relationships on a GeoTIFF, but the calls are real.
  expect_identical(get_field_domain_names(ds), character(0))
  expect_identical(get_relationship_names(ds), character(0))
  expect_silent(reset_reading(ds))
})

test_that("an enum parameter reaches GDAL as the enum", {
  types <- gdal_constants("GDT_")
  path <- tempfile(fileext = ".tif")
  on.exit(unlink(path))
  file.copy(system.file("extdata", "test.tif", package = "GDAL7"), path)

  ds <- gdal_open(path, update = TRUE)
  on.exit(gdal_close(ds), add = TRUE, after = FALSE)

  # GTiff cannot add a band, so what this checks is that GDAL got as far as
  # refusing for its own reason rather than the binding passing nonsense.
  expect_error(add_band(ds, types[["GDT_Float32"]]), "AddBand")
})

test_that("statistics can be cleared on a writable copy", {
  path <- tempfile(fileext = ".tif")
  on.exit(unlink(c(path, paste0(path, ".aux.xml"))))
  file.copy(system.file("extdata", "test.tif", package = "GDAL7"), path)

  ds <- gdal_open(path, update = TRUE)
  expect_silent(clear_statistics(ds))
  gdal_close(ds)
})

test_that("the projection can be set on a writable copy", {
  path <- tempfile(fileext = ".tif")
  on.exit(unlink(c(path, paste0(path, ".aux.xml"))))
  file.copy(system.file("extdata", "test.tif", package = "GDAL7"), path)

  wkt <- paste0(
    'GEOGCS["WGS 84",DATUM["WGS_1984",',
    'SPHEROID["WGS 84",6378137,298.257223563]],',
    'PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]]'
  )

  ds <- gdal_open(path, update = TRUE)
  set_projection(ds, wkt)
  gdal_close(ds)

  ds <- gdal_open(path)
  on.exit(gdal_close(ds), add = TRUE, after = FALSE)
  expect_match(get_projection(ds), "WGS 84")
})

test_that("a transaction on a driver that has none fails as GDAL says", {
  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  # OGRERR_UNSUPPORTED_OPERATION is 4. The binding returns GDAL's own code
  # rather than inventing one.
  expect_identical(start_transaction(ds, FALSE), 4L)
  expect_identical(rollback_transaction(ds), 4L)
})
