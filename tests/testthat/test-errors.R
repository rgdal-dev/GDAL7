test_that("a failed open reports what GDAL said", {
  path <- "/no/such/file/at/all.tif"

  # GDAL words a missing file differently on each platform, so what is asserted
  # is that GDAL's own message came through at all, naming the file, rather
  # than the bare fallback GDAL7 uses when GDAL says nothing.
  expect_error(gdal_open(path), "^Failed to open dataset: .")
  expect_error(gdal_open(path), "all\\.tif")
})

test_that("GDAL errors do not carry over from an earlier call", {
  # Leave a failure on GDAL's error state, then make a call that succeeds.
  try(gdal_open("/no/such/file/at/all.tif"), silent = TRUE)

  ds <- gdal_open(test_tif())
  expect_equal(flush_cache(ds), 0L)
})

test_that("metadata that is absent is NA, not an empty string", {
  ds <- gdal_open(test_tif())

  expect_true(is.na(get_metadata_item(ds, "NO_SUCH_ITEM_AT_ALL")))
  expect_equal(get_metadata_item(ds, "AREA_OR_POINT"), "Area")
})

test_that("the dict and list views of metadata differ", {
  ds <- gdal_open(test_tif())

  as_list <- get_metadata_list(ds, "")
  as_dict <- get_metadata_dict(ds, "")

  expect_true("AREA_OR_POINT=Area" %in% as_list)
  expect_null(names(as_list))

  expect_equal(unname(as_dict[["AREA_OR_POINT"]]), "Area")
  expect_true("AREA_OR_POINT" %in% names(as_dict))
})

test_that("dimensions come back as a data frame, one row per dimension", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  grp <- get_root_group(ds)
  arr <- open_mdarray(grp, grp@mdarray_names[[1]])

  dims <- arr@dimensions
  expect_s3_class(dims, "data.frame")
  expect_named(dims, c("name", "size", "type", "direction", "indexed"))
  expect_equal(nrow(dims), arr@dimension_count)
})

test_that("a name that is not in the group is NULL, quietly", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  grp <- get_root_group(ds)

  # GDAL reports nothing for a lookup that misses, so neither does GDAL7.
  expect_silent(result <- open_mdarray(grp, "no_such_array"))
  expect_null(result)
})

test_that("a GDAL warning arrives as an R warning", {
  expect_warning(GDAL7_emit_gdal_message("warning", "something worth saying"),
                 "GDAL: something worth saying")
})

test_that("a GDAL failure arrives as an R error carrying GDAL's own message", {
  expect_error(GDAL7_emit_gdal_message("failure", "the thing that went wrong"),
               "GDAL call failed: the thing that went wrong")
})

test_that("GDAL messages can be handled like any other R condition", {
  caught <- withCallingHandlers(
    {
      GDAL7_emit_gdal_message("warning", "catch me")
      "done"
    },
    warning = function(w) invokeRestart("muffleWarning")
  )
  expect_equal(caught, "done")
})

test_that("non-ASCII metadata survives the round trip to GDAL and back", {
  ds <- gdal_open(test_tif_copy())

  # Built from code points so this file itself stays ASCII. cpp11 translates
  # to UTF-8 on the way in and marks the result UTF-8 on the way out, which is
  # what GDAL expects on every platform.
  value <- intToUtf8(c(0x63, 0x61, 0x66, 0xE9, 0x20,
                       0xE5, 0x6E, 0x67, 0x73, 0x74, 0x72, 0xF6, 0x6D))
  set_metadata_item(ds, "GDAL7_ENCODING_TEST", value, "")

  got <- get_metadata_item(ds, "GDAL7_ENCODING_TEST", "")
  expect_equal(got, value)
  expect_equal(Encoding(got), "UTF-8")
})
