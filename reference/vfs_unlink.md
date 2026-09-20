# Change a GDAL virtual file system

The same operations as [`unlink()`](https://rdrr.io/r/base/unlink.html),
[`dir.create()`](https://rdrr.io/r/base/files2.html) and
[`file.rename()`](https://rdrr.io/r/base/files.html), over any VSI path
rather than only the local disk.

## Usage

``` r
vfs_unlink(path)

vfs_mkdir(path, mode = 755L)

vfs_rmdir(path)

vfs_rename(from, to)

vfs_copy(from, to)
```

## Arguments

- path, from, to:

  VSI paths.

- mode:

  The permission bits for a new directory, as an octal number.
  Meaningless on the file systems that have no permissions.

## Value

Nothing, invisibly. A failure is an error carrying GDAL's reason.

## Examples

``` r
vfs_write_file("/vsimem/hello.txt", charToRaw("hello"))
vfs_exists("/vsimem/hello.txt")
#> [1] TRUE
vfs_unlink("/vsimem/hello.txt")
vfs_exists("/vsimem/hello.txt")
#> [1] FALSE
```
