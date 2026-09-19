test_that("the geotransform comes back in GDAL's order", {
  ds <- gdal_open(test_tif())
  gt <- ds@geotransform

  expect_length(gt, 6L)
  expect_named(gt, c("origin_x", "pixel_width", "row_rotation",
                     "origin_y", "column_rotation", "pixel_height"))
  expect_equal(unname(gt), c(-180, 18, 0, 90, 0, -18))
})

test_that("pixel and georeferenced coordinates convert both ways", {
  ds <- gdal_open(test_tif())
  gt <- ds@geotransform

  corners <- pixel_to_xy(gt, c(0, 20), c(0, 10))
  expect_equal(corners$x, c(-180, 180))
  expect_equal(corners$y, c(90, -90))

  # Round trip lands back where it started.
  point <- pixel_to_xy(gt, 3.5, 4.5)
  back <- xy_to_pixel(gt, point$x, point$y)
  expect_named(back, c("pixel", "line"))
  expect_equal(back$pixel, 3.5)
  expect_equal(back$line, 4.5)
})

test_that("pixel_to_xy is vectorised and keeps NA as NA", {
  gt <- c(0, 1, 0, 0, 0, -1)
  out <- pixel_to_xy(gt, c(0, 1, NA), c(0, 1, 2))

  expect_length(out$x, 3L)
  expect_equal(out$x[1:2], c(0, 1))
  expect_true(is.na(out$x[3]))
  expect_true(is.na(out$y[3]))
})

test_that("a geotransform that cannot be inverted is an error", {
  expect_error(xy_to_pixel(c(0, 0, 0, 0, 0, 0), 1, 1), "cannot be inverted")
})

test_that("a geotransform must be six numbers", {
  expect_error(xy_to_pixel(c(1, 2, 3), 1, 1), "6 numbers")
  expect_error(pixel_to_xy(c(1, 2, 3), 1, 1), "6 numbers")
})

test_that("overviews are reported and can be opened", {
  ds <- gdal_open(test_cog())
  band <- get_raster_band(ds, 1)

  expect_equal(band@overview_count, 2L)

  sizes <- band@overview_sizes
  expect_equal(sizes$xsize, c(256L, 128L))
  expect_equal(sizes$ysize, c(128L, 64L))

  ov <- get_overview(band, 0)
  expect_equal(ov@xsize, 256L)
  expect_equal(ov@ysize, 128L)

  expect_error(get_overview(band, 5), "out of range")
})

test_that("an overview outlives the band but not the dataset", {
  ds <- gdal_open(test_cog())
  ov <- get_overview(get_raster_band(ds, 1), 0)

  gc()
  expect_equal(ov@xsize, 256L)

  gdal_close(ds)
  expect_error(ov@xsize, "the GDALDataset it belongs to has been closed")
})

test_that("a band with no overviews reports none", {
  ds <- gdal_open(test_tif())
  band <- get_raster_band(ds, 1)

  expect_equal(band@overview_count, 0L)
  expect_equal(nrow(band@overview_sizes), 0L)
})

test_that("reading a window gives the values GDAL holds", {
  ds <- gdal_open(test_cog())
  band <- get_raster_band(ds, 1)

  # The fixture's value at (col, row) is (row * 4 + col) %% 3001.
  expect_equal(read_raster(band, window = c(0, 0, 6, 1)), c(0, 1, 2, 3, 4, 5))
  expect_equal(read_raster(band, window = c(0, 1, 3, 1)), c(4, 5, 6))

  # x varies fastest, so a 3x2 window is row 0 then row 1.
  expect_equal(read_raster(band, window = c(0, 0, 3, 2)), c(0, 1, 2, 4, 5, 6))
})

test_that("a whole-band read is the whole band", {
  ds <- gdal_open(test_cog())
  band <- get_raster_band(ds, 1)

  expect_length(read_raster(band), 512L * 256L)
})

test_that("a reduced read matches gdal_translate on the same window", {
  ds <- gdal_open(test_cog())
  band <- get_raster_band(ds, 1)

  # Reference values from, on the same fixture:
  #   gdal_translate -of AAIGrid -srcwin 0 0 8 8 -outsize 2 2 -r average
  expect_equal(
    read_raster(band, window = c(0, 0, 8, 8), out_size = c(2, 2),
                resample = "average"),
    c(8, 12, 24, 28)
  )

  #   gdal_translate -of AAIGrid -outsize 4 2 -r average
  expect_equal(
    read_raster(band, out_size = c(4, 2), resample = "average"),
    c(318, 446, 574, 702, 830, 958, 1086, 1214)
  )
})

test_that("a fractional window is read as given", {
  ds <- gdal_open(test_cog())
  band <- get_raster_band(ds, 1)

  # Offset by half a pixel in each direction, so this is not the same read as
  # the integer window at the same size.
  half <- read_raster(band, window = c(0.5, 0.5, 3, 3), out_size = c(3, 3),
                      resample = "bilinear")
  whole <- read_raster(band, window = c(0, 0, 3, 3), out_size = c(3, 3),
                       resample = "bilinear")

  expect_length(half, 9L)
  expect_false(isTRUE(all.equal(half, whole)))
})

test_that("several bands read in one call", {
  ds <- gdal_open(test_tif())

  both <- read_raster(ds, out_size = c(4, 2))
  expect_named(both, c("1", "2"))
  expect_length(both[["1"]], 8L)

  one <- read_raster(ds, bands = 2, out_size = c(4, 2))
  expect_named(one, "2")
  expect_equal(one[["2"]], both[["2"]])
})

test_that("read_raster rejects arguments it cannot honour", {
  ds <- gdal_open(test_tif())
  band <- get_raster_band(ds, 1)

  expect_error(read_raster(band, resample = "nope"), "Unknown resampling")
  expect_error(read_raster(band, window = c(0, 0, 4)), "4 non-missing numbers")
  expect_error(read_raster(band, out_size = c(0, 4)), "must be positive")
  expect_error(read_raster(band, window = c(0, 0, 0, 4)), "positive width")
  expect_error(read_raster(band, bands = 1), "applies to a dataset")
  expect_error(read_raster(ds, bands = 99), "out of range")
})

test_that("gdal_info reports the dataset in one call", {
  info <- gdal_info(test_cog())

  expect_equal(info$driver, "GTiff")
  expect_equal(unname(info$size), c(512L, 256L))
  expect_equal(info$bands, 1L)
  expect_match(info$projection, "WGS 84")
  expect_length(info$geotransform, 6L)

  expect_s3_class(info$band_info, "data.frame")
  expect_equal(nrow(info$band_info), 1L)
  expect_equal(info$band_info$type, "Int16")
  expect_equal(info$band_info$block_x, 128L)
  expect_equal(info$band_info$nodata, -32768)
  expect_equal(info$band_info$overviews, 2L)
})

test_that("gdal_info takes an open dataset and leaves it open", {
  ds <- gdal_open(test_tif())
  info <- gdal_info(ds)

  expect_equal(info$bands, 2L)
  expect_equal(nrow(info$band_info), 2L)

  # Still usable: gdal_info only closes a dataset it opened itself.
  expect_equal(ds@raster_xsize, 20L)
})

test_that("the enum tables name the codes the rest of the package returns", {
  types <- gdal_data_types()
  expect_type(types, "integer")
  expect_equal(types[["Int16"]], 3L)

  ds <- gdal_open(test_tif())
  band <- get_raster_band(ds, 1)
  expect_equal(names(types)[types == band@data_type], band@data_type_name)

  colors <- gdal_color_interpretations()
  expect_equal(colors[["Gray"]], 1L)
  expect_equal(
    names(colors)[colors == band@color_interpretation],
    band@color_interpretation_name
  )
})

test_that("a dataset with no geotransform says so", {
  # A bare VRT band carries no geotransform at all. GDAL reports the identity
  # and a failure together for those, which is why NULL is used instead.
  path <- tempfile(fileext = ".vrt")
  writeLines(c(
    '<VRTDataset rasterXSize="4" rasterYSize="4">',
    '  <VRTRasterBand dataType="Byte" band="1"/>',
    "</VRTDataset>"
  ), path)

  ds <- gdal_open(path)
  expect_equal(ds@raster_xsize, 4L)
  expect_null(ds@geotransform)
})

test_that("a multidimensional array reports its numeric type", {
  skip_if_no_driver("Zarr")

  ds <- gdal_open(test_zarr(), multidim = TRUE)
  grp <- get_root_group(ds)
  arr <- open_mdarray(grp, "temperature")

  # GDALExtendedDataTypeGetName() is empty for a plain numeric array, so the
  # ordinary GDAL type underneath is what gets reported.
  expect_equal(arr@data_type_name, "Float64")
})
