# An oblique azimuthal equidistant, whose antipode is a singularity, and an
# orthographic, whose limb is one. Both are interior to the boxes below, which
# is where a boundary walk alone stops being enough.
aeqd <- "+proj=aeqd +lat_0=45 +lon_0=10 +datum=WGS84"
ortho <- "+proj=ortho +lat_0=45 +lon_0=10 +datum=WGS84"

test_that("an extent comes back in the target's units", {
  out <- transform_extent(c(100, -70, 160, -60), "EPSG:4326", "EPSG:3031")

  expect_named(out, c("xmin", "ymin", "xmax", "ymax"))
  expect_true(all(is.finite(out)))
  expect_true(out[["xmax"]] > out[["xmin"]])
  expect_true(out[["ymax"]] > out[["ymin"]])
  # Metres, not degrees.
  expect_gt(max(abs(out)), 1e5)
  expect_equal(attr(out, "outside"), 0)
})

test_that("densifying the edges gives a box the corners alone would miss", {
  # The longitude range has to straddle a turning point for the bow to show:
  # in EPSG:3031 the easting of a parallel peaks at 90 degrees east, so a box
  # from 60 to 120 has its extreme in the middle of an edge rather than at a
  # corner. A box from 100 to 160 does not, and densifying it changes nothing,
  # which is why this test picks the range it does.
  bbox <- c(60, -70, 120, -60)
  corners <- transform_extent(bbox, "EPSG:4326", "EPSG:3031",
                              densify = 0, mesh = 0)
  walked <- transform_extent(bbox, "EPSG:4326", "EPSG:3031", mesh = 0)

  expect_lte(walked[["xmin"]], corners[["xmin"]])
  expect_gte(walked[["xmax"]], corners[["xmax"]])

  area <- function(x) (x[["xmax"]] - x[["xmin"]]) * (x[["ymax"]] - x[["ymin"]])
  # Around 45 percent more area here, so the margin is not a rounding artefact.
  expect_gt(area(walked), area(corners) * 1.2)
})

test_that("the mesh catches the antipode of an oblique azimuthal", {
  # The walk alone comes back around 365 km short in easting, because the
  # singularity is in the middle of the box rather than on its edge.
  bbox <- c(-175, -50, -165, -40)
  walked <- transform_extent(bbox, "EPSG:4326", aeqd, mesh = 0)
  both <- transform_extent(bbox, "EPSG:4326", aeqd)

  expect_gt(walked[["xmin"]] - both[["xmin"]], 3e5)
  expect_gt(both[["xmax"]] - walked[["xmax"]], 3e5)
  expect_gt(both[["ymax"]] - walked[["ymax"]], 3e5)
})

test_that("the mesh catches an orthographic's limb", {
  bbox <- c(90, -10, 130, 30)
  walked <- transform_extent(bbox, "EPSG:4326", ortho, mesh = 0)
  both <- transform_extent(bbox, "EPSG:4326", ortho)

  expect_gt(both[["xmax"]] - walked[["xmax"]], 5e4)
  # Part of that box is round the back of the globe and has no image at all.
  expect_gt(attr(both, "outside"), 0)
  expect_lt(attr(both, "outside"), 1)
})

test_that("an extent with no image at all is an error, not a narrower box", {
  # Wholly on the far side of the orthographic. Returning the envelope of
  # nothing would be an extent of infinities.
  expect_error(transform_extent(c(-170, -10, -150, 10), "EPSG:4326", ortho),
               "No part of this extent")
})

test_that("the union is never narrower than either sampling alone", {
  bbox <- c(-60, -60, 60, 60)
  omerc <- "+proj=omerc +lat_0=0 +lonc=10 +alpha=45 +datum=WGS84"

  walked <- transform_extent(bbox, "EPSG:4326", omerc, mesh = 0)
  meshed <- transform_extent(bbox, "EPSG:4326", omerc, densify = 0)
  both <- transform_extent(bbox, "EPSG:4326", omerc)

  for (part in list(walked, meshed)) {
    expect_lte(both[["xmin"]], part[["xmin"]])
    expect_lte(both[["ymin"]], part[["ymin"]])
    expect_gte(both[["xmax"]], part[["xmax"]])
    expect_gte(both[["ymax"]], part[["ymax"]])
  }
  # And here the mesh alone is the one that falls short, not the walk: 65
  # points along an edge is coarser than 22 per side.
  expect_lt(walked[["xmin"]], meshed[["xmin"]])
})

test_that("both sides are read in x, y order whatever the authority says", {
  # EPSG:4326's authority order is latitude first. If that leaked through, a
  # longitude of 100 would be read as a latitude and the transform would fail
  # or land somewhere else entirely.
  out <- transform_extent(c(100, -70, 160, -60), "EPSG:4326", "EPSG:4326")
  expect_equal(as.vector(out), c(100, -70, 160, -60))
})

test_that("a round trip contains what it started with", {
  bbox <- c(1e6, 1e6, 2e6, 2e6)
  there <- transform_extent(bbox, "EPSG:3031", "EPSG:4326")
  back <- transform_extent(unname(there), "EPSG:4326", "EPSG:3031")

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
  out <- transform_extent(c(-5e5, -5e5, 5e5, 5e5), "EPSG:3031", "EPSG:4326")
  expect_equal(out[["xmin"]], -180)
  expect_equal(out[["xmax"]], 180)
  expect_equal(out[["ymin"]], -90)
})

test_that("a box crossing the antimeridian is refused rather than half-read", {
  # GDAL would read this as the 20 degrees across the dateline and answer in
  # the same wrapped form, which no union of two samplings can preserve.
  expect_error(transform_extent(c(170, -10, -170, 10), "EPSG:4326", "EPSG:3857"),
               "antimeridian")
  expect_error(transform_extent(c(2e6, 0, 1e6, 1e6), "EPSG:3031", "EPSG:4326"),
               "antimeridian")
})

test_that("a CRS GDAL cannot read is an error naming it", {
  expect_error(transform_extent(c(0, 0, 1, 1), "not a crs", "EPSG:4326"),
               "not a crs")
  expect_error(transform_extent(c(0, 0, 1, 1), "EPSG:4326", "also not"),
               "also not")
})

test_that("the arguments are checked", {
  expect_error(transform_extent(c(0, 0, 1), "EPSG:4326", "EPSG:3031"),
               "4 non-missing numbers")
  expect_error(transform_extent(c(0, 0, 1, NA), "EPSG:4326", "EPSG:3031"),
               "4 non-missing numbers")
  expect_error(transform_extent(c(0, 0, 1, 1), "EPSG:4326", "EPSG:3031",
                                densify = -1), "negative")
  expect_error(transform_extent(c(0, 0, 1, 1), "EPSG:4326", "EPSG:3031",
                                mesh = 5000), "between 0 and 1000")
  expect_error(transform_extent(c(0, 1, 1, 0), "EPSG:4326", "EPSG:3031"),
               "ymax below ymin")
})
