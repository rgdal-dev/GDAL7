test_that("a box comes back in the target's units", {
  # Roughly the Australian sector of the Southern Ocean, in polar
  # stereographic metres.
  out <- transform_bounds(c(100, -70, 160, -60), "EPSG:4326", "EPSG:3031")

  expect_named(out, c("xmin", "ymin", "xmax", "ymax"))
  expect_true(all(is.finite(out)))
  expect_true(out[["xmax"]] > out[["xmin"]])
  expect_true(out[["ymax"]] > out[["ymin"]])
  # Metres, not degrees.
  expect_gt(max(abs(out)), 1e5)
})

test_that("densifying the edges gives a box the corners alone would miss", {
  # The longitude range has to straddle a turning point for the bow to show:
  # in EPSG:3031 the easting of a parallel peaks at 90 degrees east, so a box
  # from 60 to 120 has its extreme in the middle of an edge rather than at a
  # corner. A box from 100 to 160 does not, and densifying it changes nothing,
  # which is why this test picks the range it does.
  bbox <- c(60, -70, 120, -60)
  corners <- transform_bounds(bbox, "EPSG:4326", "EPSG:3031", densify = 0)
  densified <- transform_bounds(bbox, "EPSG:4326", "EPSG:3031")

  # The corner box is contained in the densified one and is strictly smaller.
  expect_lte(densified[["xmin"]], corners[["xmin"]])
  expect_lte(densified[["ymin"]], corners[["ymin"]])
  expect_gte(densified[["xmax"]], corners[["xmax"]])
  expect_gte(densified[["ymax"]], corners[["ymax"]])

  area <- function(x) (x[["xmax"]] - x[["xmin"]]) * (x[["ymax"]] - x[["ymin"]])
  # Around 45 percent more area here, so the margin is not a rounding artefact.
  expect_gt(area(densified), area(corners) * 1.2)
})

test_that("both sides are read in x, y order whatever the authority says", {
  # EPSG:4326's authority order is latitude first. If that leaked through, a
  # longitude of 100 would be read as a latitude and the transform would fail
  # or land somewhere else entirely.
  out <- transform_bounds(c(100, -70, 160, -60), "EPSG:4326", "EPSG:4326")
  expect_equal(unname(out), c(100, -70, 160, -60))
})

test_that("a round trip contains what it started with", {
  bbox <- c(1e6, 1e6, 2e6, 2e6)
  there <- transform_bounds(bbox, "EPSG:3031", "EPSG:4326")
  back <- transform_bounds(unname(there), "EPSG:4326", "EPSG:3031")

  # A round trip is not an identity and should not be tested as one. The
  # envelope of an envelope only ever grows, and it grows a lot here: the
  # geographic envelope of a projected rectangle covers a wedge much larger
  # than the rectangle. Containment is the invariant that actually holds.
  expect_lte(back[["xmin"]], bbox[1])
  expect_lte(back[["ymin"]], bbox[2])
  expect_gte(back[["xmax"]], bbox[3])
  expect_gte(back[["ymax"]], bbox[4])
})

test_that("a box that surrounds the pole opens out to every longitude", {
  # Not a defect: a box containing the south pole really does span 360
  # degrees, and a caller picking a window from it needs to see that rather
  # than a narrow band that would clip.
  out <- transform_bounds(c(-5e5, -5e5, 5e5, 5e5), "EPSG:3031", "EPSG:4326")
  expect_equal(out[["xmin"]], -180)
  expect_equal(out[["xmax"]], 180)
  expect_equal(out[["ymin"]], -90)
})

test_that("a CRS GDAL cannot read is an error naming it", {
  expect_error(transform_bounds(c(0, 0, 1, 1), "not a crs", "EPSG:4326"),
               "not a crs")
  expect_error(transform_bounds(c(0, 0, 1, 1), "EPSG:4326", "also not"),
               "also not")
})

test_that("the box has to be four numbers", {
  expect_error(transform_bounds(c(0, 0, 1), "EPSG:4326", "EPSG:3031"),
               "4 non-missing numbers")
  expect_error(transform_bounds(c(0, 0, 1, NA), "EPSG:4326", "EPSG:3031"),
               "4 non-missing numbers")
  expect_error(transform_bounds(c(0, 0, 1, 1), "EPSG:4326", "EPSG:3031",
                                densify = -1),
               "negative")
})
