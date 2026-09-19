# GDAL's algorithm registry arrived in 3.11. Everything here needs it, and says
# so rather than failing on an older build.
skip_if_no_algorithms <- function() {
  if (!gdal_has_algorithms()) {
    testthat::skip("GDAL is older than 3.11, so it has no algorithm registry")
  }
}

# Both raster fixtures cover the whole globe, so reprojecting either to Web
# Mercator clamps at the poles and GDAL says so. That warning is checked once,
# in its own test, and kept out of the way everywhere else.
reproject_to_memory <- function(input, ...) {
  suppressWarnings(gdal_run("raster reproject", list(
    input = input, output = "", "output-format" = "MEM",
    "dst-crs" = "EPSG:3857", ...
  ), progress = FALSE))
}

test_that("whether this build has the algorithm API is a plain answer", {
  expect_type(gdal_has_algorithms(), "logical")
  expect_length(gdal_has_algorithms(), 1L)
})

test_that("an older GDAL says which release it would need", {
  if (gdal_has_algorithms()) {
    skip("this GDAL has the algorithm registry")
  }
  expect_error(gdal_algorithms(), "3\\.11")
  expect_error(gdal_run("raster reproject"), "3\\.11")
})

# ============================================================================
# The registry
# ============================================================================

test_that("the registry lists its algorithms as a tree", {
  skip_if_no_algorithms()

  top <- gdal_algorithms()
  expect_type(top, "character")
  expect_true(all(c("raster", "vector") %in% top))

  raster <- gdal_algorithms("raster")
  expect_true("reproject" %in% raster)

  # A path is one string or its parts, and a leaf has nothing under it.
  expect_identical(gdal_algorithms("raster reproject"),
                   gdal_algorithms(c("raster", "reproject")))
  expect_length(gdal_algorithms("raster reproject"), 0L)
})

test_that("an algorithm describes itself and its arguments", {
  skip_if_no_algorithms()

  info <- gdal_algorithm_info("raster reproject")
  expect_match(info$description, "[Rr]eproject")
  expect_match(info$url, "^https://")

  args <- info$arguments
  expect_s3_class(args, "data.frame")
  expect_named(args, c("name", "type", "description", "required",
                       "positional", "input", "output", "choices"))
  expect_true(all(c("input", "output", "resampling") %in% args$name))

  expect_true(args$required[args$name == "input"])
  expect_true(args$output[args$name == "output"])

  # GDAL 3.13 renamed this argument from dst-crs to output-crs and kept the old
  # spelling as a hidden alias, which GDAL does not list. So the argument is
  # found by asking which name this GDAL reports rather than by assuming one.
  crs <- intersect(c("output-crs", "dst-crs"), args$name)
  expect_length(crs, 1L)
  expect_identical(args$type[args$name == crs], "string")

  # Arguments with a fixed set of values carry it, the rest carry nothing.
  expect_true("nearest" %in% args$choices[[which(args$name == "resampling")]])
  expect_length(args$choices[[which(args$name == crs)]], 0L)
})

test_that("a name that is not there is answered with the ones that are", {
  skip_if_no_algorithms()

  expect_error(gdal_algorithms("nonsense"), "no algorithm called 'nonsense'")
  expect_error(gdal_algorithms("raster nonsense"), "'raster' has no 'nonsense'")
  expect_error(gdal_run(character(0)), "needs a name")
})

# ============================================================================
# Running
# ============================================================================

test_that("reproject runs into memory, touching no disk", {
  skip_if_no_algorithms()

  before <- length(list.files(tempdir(), recursive = TRUE))
  out <- reproject_to_memory(test_tif())

  expect_s3_class(out, "GDAL7::GDALDataset")
  expect_match(get_projection(out), "Pseudo-Mercator")
  expect_gt(get_raster_xsize(out), 0L)
  expect_identical(get_raster_count(out), 2L)
  expect_identical(length(list.files(tempdir(), recursive = TRUE)), before)

  gdal_close(out)
})

test_that("an already open dataset is used as it stands", {
  skip_if_no_algorithms()

  ds <- gdal_open(test_tif())
  on.exit(gdal_close(ds))

  out <- reproject_to_memory(ds)
  expect_match(get_projection(out), "Pseudo-Mercator")
  gdal_close(out)

  # The algorithm took its own reference, so the dataset it was given is still
  # open and usable afterwards.
  expect_identical(get_raster_xsize(ds), 20L)
})

test_that("an output file is written, closed and readable straight away", {
  skip_if_no_algorithms()

  path <- tempfile(fileext = ".tif")
  result <- suppressWarnings(gdal_run("raster reproject", list(
    input = test_tif(), output = path, "dst-crs" = "EPSG:3857"
  ), progress = FALSE))

  expect_identical(result, path)
  expect_true(file.exists(path))

  ds <- gdal_open(path)
  on.exit(gdal_close(ds))
  expect_match(get_projection(ds), "Pseudo-Mercator")
})

test_that("a pipeline runs, step by step, into memory", {
  skip_if_no_algorithms()

  out <- suppressWarnings(gdal_run("raster pipeline", list(
    pipeline = paste(
      "read", test_cog(),
      "! reproject --dst-crs EPSG:3857 --resampling average",
      "! write --output-format MEM streamed"
    )
  ), progress = FALSE))

  expect_s3_class(out, "GDAL7::GDALDataset")
  expect_match(get_projection(out), "Pseudo-Mercator")
  gdal_close(out)
})

test_that("what GDAL complains about reaches R", {
  skip_if_no_algorithms()

  # The fixture covers the whole globe, which Web Mercator cannot, so GDAL
  # clamps the bounds and says so.
  expect_warning(
    out <- gdal_run("raster reproject", list(
      input = test_tif(), output = "", "output-format" = "MEM",
      "dst-crs" = "EPSG:3857"
    ), progress = FALSE),
    "Clamping output bounds"
  )
  gdal_close(out)
})

test_that("arguments are checked against what the algorithm declares", {
  skip_if_no_algorithms()

  expect_error(gdal_run("raster reproject", list(nope = 1)),
               "no argument called 'nope'")
  expect_error(gdal_run("raster reproject", list("dst-crs" = 3857)),
               "needs a single string")
  expect_error(gdal_run("raster reproject", list(overwrite = "yes")),
               "needs TRUE or FALSE")
  expect_error(gdal_run("raster reproject", list(1)),
               "has to be named")
  expect_error(gdal_run("raster reproject", args = "input"),
               "named list")
})

test_that("a failure carries GDAL's reason for it", {
  skip_if_no_algorithms()

  expect_error(
    gdal_run("raster reproject", list(
      input = "no-such-file.tif", output = "", "output-format" = "MEM",
      "dst-crs" = "EPSG:3857"
    ), progress = FALSE),
    "No such file or directory"
  )
})

test_that("progress is drawn when asked for and silent when not", {
  skip_if_no_algorithms()

  drawn <- capture.output(gdal_close(suppressWarnings(
    gdal_run("raster reproject", list(
      input = test_tif(), output = "", "output-format" = "MEM",
      "dst-crs" = "EPSG:3857"
    ), progress = TRUE)
  )))
  expect_match(paste(drawn, collapse = ""), "=")

  quiet <- capture.output(gdal_close(reproject_to_memory(test_tif())))
  expect_identical(paste(quiet, collapse = ""), "")
})
