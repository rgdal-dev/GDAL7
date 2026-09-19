# GDAL's virtual file systems, and the configuration options that steer them.

test_that("a file on disk is found and measured", {
  path <- test_tif()

  expect_true(vfs_exists(path))
  expect_false(vfs_exists(paste0(path, ".not-there")))

  info <- vfs_stat(path)
  expect_named(info, c("size", "is_directory", "modified"))
  expect_identical(info$size, as.double(file.size(path)))
  expect_false(info$is_directory)

  expect_null(vfs_stat(paste0(path, ".not-there")))
})

test_that("a directory is listed, and a file is not a directory", {
  entries <- vfs_list(dirname(test_tif()))

  expect_type(entries, "character")
  expect_true("test.tif" %in% entries)

  expect_true(vfs_stat(dirname(test_tif()))$is_directory)
  # A path with nothing under it answers NULL rather than raising, since a
  # caller cannot otherwise tell an empty directory from a file.
  expect_null(vfs_list(test_tif()))
})

test_that("a listing can be cut short", {
  all_entries <- vfs_list(dirname(test_tif()))
  skip_if(length(all_entries) < 3, "too few files here to cut a listing short")

  entries <- vfs_list(dirname(test_tif()), limit = 1)

  # GDAL reads a directory in chunks and stops at the first chunk past the
  # limit, so the limit is a hint rather than a promise. What it does promise
  # is that what comes back is part of the listing, and no longer than it.
  expect_true(length(entries) >= 1L)
  expect_lte(length(entries), length(all_entries))
  expect_true(all(entries %in% all_entries))
})

# ============================================================================
# Memory
# ============================================================================

test_that("bytes go into memory and come back", {
  on.exit(try(vfs_unlink("/vsimem/hello.txt"), silent = TRUE), add = TRUE)

  bytes <- charToRaw("hello, vsimem")
  vfs_write_file("/vsimem/hello.txt", bytes)

  expect_true(vfs_exists("/vsimem/hello.txt"))
  expect_identical(vfs_stat("/vsimem/hello.txt")$size, as.double(length(bytes)))
  expect_identical(vfs_read_file("/vsimem/hello.txt"), bytes)

  vfs_unlink("/vsimem/hello.txt")
  expect_false(vfs_exists("/vsimem/hello.txt"))
})

test_that("an empty file is a file", {
  on.exit(try(vfs_unlink("/vsimem/empty"), silent = TRUE), add = TRUE)

  vfs_write_file("/vsimem/empty", raw(0))
  expect_identical(vfs_read_file("/vsimem/empty"), raw(0))
})

test_that("a dataset built in memory never reaches the disk", {
  on.exit(try(vfs_unlink("/vsimem/small.tif"), silent = TRUE), add = TRUE)

  before <- length(list.files(tempdir(), recursive = TRUE))

  ds <- gdal_create("/vsimem/small.tif", 4, 4, bands = 1, type = "Byte")
  write_raster(ds, list(as.double(seq_len(16))))
  gdal_close(ds)

  expect_identical(length(list.files(tempdir(), recursive = TRUE)), before)

  # It is a real GeoTIFF: GDAL opens it again, and the bytes start the way a
  # TIFF's do.
  reopened <- gdal_open("/vsimem/small.tif")
  on.exit(gdal_close(reopened), add = TRUE)
  expect_identical(read_raster(reopened)[[1]], as.double(seq_len(16)))

  bytes <- vfs_read_file("/vsimem/small.tif")
  expect_true(length(bytes) > 0)
  expect_true(rawToChar(bytes[1:2]) %in% c("II", "MM"))
})

test_that("directories, renames and copies work in memory", {
  on.exit({
    try(vfs_unlink("/vsimem/dir/b.txt"), silent = TRUE)
    try(vfs_unlink("/vsimem/dir/c.txt"), silent = TRUE)
    try(vfs_rmdir("/vsimem/dir"), silent = TRUE)
  }, add = TRUE)

  vfs_mkdir("/vsimem/dir")
  expect_true(vfs_stat("/vsimem/dir")$is_directory)

  vfs_write_file("/vsimem/dir/a.txt", charToRaw("a"))
  vfs_rename("/vsimem/dir/a.txt", "/vsimem/dir/b.txt")
  expect_false(vfs_exists("/vsimem/dir/a.txt"))
  expect_identical(vfs_read_file("/vsimem/dir/b.txt"), charToRaw("a"))

  vfs_copy("/vsimem/dir/b.txt", "/vsimem/dir/c.txt")
  expect_identical(vfs_read_file("/vsimem/dir/c.txt"), charToRaw("a"))
  expect_true(all(c("b.txt", "c.txt") %in% vfs_list("/vsimem/dir")))
})

test_that("what cannot be done says so, with GDAL's reason where there is one", {
  expect_error(vfs_unlink("/vsimem/not-there"), "Could not delete")
  expect_error(vfs_read_file("/vsimem/not-there"), "Could not open")
  expect_error(vfs_rmdir("/vsimem/not-there"), "Could not remove the directory")
  expect_error(vfs_write_file("/vsimem/x", "not raw"), "must be a raw vector")
})

# ============================================================================
# Configuration options
# ============================================================================

test_that("an option is set, read and unset", {
  on.exit(gdal_config("GDAL7_TEST_OPTION", NULL), add = TRUE)

  expect_null(gdal_config("GDAL7_TEST_OPTION"))

  gdal_config("GDAL7_TEST_OPTION", "one")
  expect_identical(gdal_config("GDAL7_TEST_OPTION"), "one")

  # A logical arrives as GDAL writes its own booleans.
  gdal_config("GDAL7_TEST_OPTION", TRUE)
  expect_identical(gdal_config("GDAL7_TEST_OPTION"), "YES")

  # Unset is not the same as set to the empty string.
  gdal_config("GDAL7_TEST_OPTION", "")
  expect_identical(gdal_config("GDAL7_TEST_OPTION"), "")
  gdal_config("GDAL7_TEST_OPTION", NULL)
  expect_null(gdal_config("GDAL7_TEST_OPTION"))
})

test_that("setting an option reports what was there before", {
  on.exit(gdal_config("GDAL7_TEST_OPTION", NULL), add = TRUE)

  expect_null(gdal_config("GDAL7_TEST_OPTION", "first"))
  expect_identical(gdal_config("GDAL7_TEST_OPTION", "second"), "first")
})

test_that("a scoped change puts back exactly what was there", {
  on.exit({
    gdal_config("GDAL7_TEST_SET", NULL)
    gdal_config("GDAL7_TEST_UNSET", NULL)
  }, add = TRUE)

  gdal_config("GDAL7_TEST_SET", "before")

  result <- with_gdal_config(c(GDAL7_TEST_SET = "during",
                               GDAL7_TEST_UNSET = "during"), {
    c(gdal_config("GDAL7_TEST_SET"), gdal_config("GDAL7_TEST_UNSET"))
  })

  expect_identical(result, c("during", "during"))
  expect_identical(gdal_config("GDAL7_TEST_SET"), "before")
  # What was unset goes back to unset, rather than to an empty string.
  expect_null(gdal_config("GDAL7_TEST_UNSET"))
})

test_that("a scoped change puts things back even when the expression fails", {
  on.exit(gdal_config("GDAL7_TEST_SET", NULL), add = TRUE)

  gdal_config("GDAL7_TEST_SET", "before")
  expect_error(
    with_gdal_config(c(GDAL7_TEST_SET = "during"), stop("no")), "no"
  )
  expect_identical(gdal_config("GDAL7_TEST_SET"), "before")
})

test_that("the options that are set can be listed", {
  on.exit(gdal_config("GDAL7_TEST_OPTION", NULL), add = TRUE)

  gdal_config("GDAL7_TEST_OPTION", "listed")
  options <- gdal_config_options()

  expect_type(options, "character")
  expect_identical(options[["GDAL7_TEST_OPTION"]], "listed")
})
