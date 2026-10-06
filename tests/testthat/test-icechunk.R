# The Icechunk driver arrived in GDAL 3.14 and is skipped wherever it is
# missing. The fixture's history is described in
# data-raw/make_icechunk_fixture.py: main has the second time step raised by
# 100 since tag v1, and branch experiment has every value lowered by 50.

icechunk_repo <- function() {
  system.file("extdata/temperature.icechunk", package = "GDAL7")
}

read_icechunk_temperature <- function(dsn) {
  ds <- gdal_open(dsn, multidim = TRUE)
  on.exit(gdal_close(ds))
  read_mdarray(open_mdarray(get_root_group(ds), "temperature"))
}

test_that("an Icechunk repository reads as a multidimensional dataset", {
  skip_if_no_driver("Icechunk")

  ds <- gdal_open(icechunk_repo(), multidim = TRUE)
  on.exit(gdal_close(ds))
  arr <- open_mdarray(get_root_group(ds), "temperature")

  expect_identical(arr@dimensions$name, c("time", "lat", "lon"))
  expect_identical(unname(arr@block_size), c(1, 9, 18))
  expect_identical(dim(read_mdarray(arr)), c(lon = 36L, lat = 18L, time = 3L))
})

test_that("a tag and a branch are read from the connection string", {
  skip_if_no_driver("Icechunk")

  repo <- icechunk_repo()
  main <- read_icechunk_temperature(repo)
  v1 <- read_icechunk_temperature(paste0("ICECHUNK:", repo, "?tag=v1"))
  experiment <- read_icechunk_temperature(paste0("ICECHUNK:", repo, "?branch=experiment"))

  expect_equal(main[, , c(1, 3)], v1[, , c(1, 3)])
  expect_equal(main[, , 2] - v1[, , 2], array(100, c(36, 18)),
               ignore_attr = TRUE, tolerance = 1e-5)
  expect_equal(experiment - v1, array(-50, c(36, 18, 3)),
               ignore_attr = TRUE, tolerance = 1e-5)
})

test_that("the driver's list-branches algorithm comes back as JSON text", {
  skip_if_no_driver("Icechunk")
  skip_if_not(gdal_has_algorithms(), "this GDAL has no algorithms to run")

  branches <- gdal_run("driver icechunk list-branches",
                       list(input = icechunk_repo()), progress = FALSE)
  expect_type(branches, "character")
  expect_match(branches, '"name": "experiment"', fixed = TRUE)
  expect_match(branches, '"name": "main"', fixed = TRUE)
})

test_that("/vsiicechunk/ lists the Zarr tree a snapshot describes", {
  skip_if_no_driver("Icechunk")

  logical <- sprintf("/vsiicechunk/{%s}", icechunk_repo())
  expect_setequal(setdiff(vfs_list(logical), c(".", "..")),
                  c("zarr.json", "lat", "lon", "temperature", "time"))
})
