# Read and write bytes over a GDAL virtual file system

With `/vsimem/` these are how a dataset built in memory leaves GDAL
without ever reaching the disk: create it at a `/vsimem/` path, close
it, and read the bytes.

## Usage

``` r
vfs_read_file(path)

vfs_write_file(path, bytes)
```

## Arguments

- path:

  A VSI path.

- bytes:

  A raw vector.

## Value

`vfs_read_file()` a raw vector. `vfs_write_file()` nothing, invisibly.

## Examples

``` r
# A GeoTIFF that is never written to disk.
ds <- gdal_create("/vsimem/small.tif", 4, 4, bands = 1, type = "Byte")
write_raster(ds, list(as.double(seq_len(16))))
gdal_close(ds)

bytes <- vfs_read_file("/vsimem/small.tif")
length(bytes)
#> [1] 162
rawToChar(bytes[1:2])
#> [1] "II"

vfs_unlink("/vsimem/small.tif")
```
