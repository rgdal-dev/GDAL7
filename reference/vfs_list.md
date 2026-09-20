# GDAL's virtual file systems

Every GDAL path works here, not only files on disk. `/vsimem/` is
memory, `/vsizip/` and `/vsitar/` look inside archives, `/vsicurl/` and
the cloud prefixes reach remote storage, and they compose:
`/vsizip//vsicurl/https://example.org/a.zip/b.tif` is a file inside a
zip that is never downloaded whole.

## Usage

``` r
vfs_list(path, limit = -1L)

vfs_stat(path)

vfs_exists(path)
```

## Arguments

- path:

  A VSI path.

- limit:

  Roughly the most entries to list. -1, the default, is all of them; a
  limit is what makes listing a large remote prefix bearable. GDAL reads
  a directory in chunks and stops at the first chunk past the limit, so
  a listing can come back a little longer than asked for.

## Value

`vfs_list()` a character vector of names, or NULL. `vfs_stat()` a list
of `size`, `is_directory` and `modified`, or NULL. `vfs_exists()` TRUE
or FALSE.

## Details

`vfs_list()` returns NULL rather than an error for a path that is not a
directory or holds nothing, since a caller cannot otherwise tell the two
apart. `vfs_stat()` returns NULL for a path that is not there.

## Examples

``` r
vfs_exists(system.file("extdata/test.tif", package = "GDAL7"))
#> [1] TRUE
vfs_stat(system.file("extdata/test.tif", package = "GDAL7"))$size
#> [1] 428

# What ships with the package.
vfs_list(system.file("extdata", package = "GDAL7"))
#> [1] "."             "overviews.tif" "multidim.zarr" "test.tif"     
#> [5] "test.gpkg"     ".."           
```
