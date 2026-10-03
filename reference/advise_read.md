# Tell GDAL what is about to be read

Advice reads nothing into R. It tells the driver which part of a source
the next reads will cover, so the driver can fetch or decode ahead, all
at once, rather than one piece per read. What that buys depends on the
driver:

## Usage

``` r
advise_read(x, ...)
```

## Arguments

- x:

  A
  [GDALMDArray](https://rgdal-dev.github.io/GDAL7/reference/GDALMDArray.md),
  [GDALRasterBand](https://rgdal-dev.github.io/GDAL7/reference/GDALRasterBand.md)
  or
  [GDALDataset](https://rgdal-dev.github.io/GDAL7/reference/GDALDataset.md).

- ...:

  The slice or window; see the Arguments section.

## Value

`x`, invisibly.

## Details

- Zarr decodes every chunk the slice touches on `GDAL_NUM_THREADS`
  threads (all cores unless that is set, or `NUM_THREADS` is given in
  `options`), and the reads that follow are served from those decoded
  chunks. Without the advice a Zarr read decodes its chunks one after
  another.

- netCDF reads the slice into memory in one call.

- Raster drivers that read from a server (WMS, ECW and JP2 streams) can
  start the transfer.

- A driver with nothing to prepare does nothing and still succeeds, so
  advising is never wrong, only sometimes idle. GeoTIFF is one: it
  already gathers the byte ranges for a whole window inside each read.

Each call replaces the last: a Zarr array keeps the chunks of the most
recent advice only.

## Arguments

For a
[GDALMDArray](https://rgdal-dev.github.io/GDAL7/reference/GDALMDArray.md):

- `start`, `count`:

  The slice, as for
  [`read_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/read_mdarray.md):
  in the array's own dimension order, `start` counting from 1. They
  default to the whole array.

For a
[GDALRasterBand](https://rgdal-dev.github.io/GDAL7/reference/GDALRasterBand.md)
or a
[GDALDataset](https://rgdal-dev.github.io/GDAL7/reference/GDALDataset.md):

- `window`, `out_size`:

  As for
  [`read_raster()`](https://rgdal-dev.github.io/GDAL7/reference/read_raster.md).
  A smaller `out_size` lets GDAL plan on an overview.

- `bands`:

  For a dataset, which bands, one-based. Defaults to all.

For all of them, `options` is a character vector of `KEY=VALUE` driver
options, or `NULL`. Zarr reads `NUM_THREADS` and `CACHE_SIZE` (bytes;
half of GDAL's free block cache by default, and the advice fails if the
slice's chunks will not fit in it).

## Examples

``` r
path <- system.file("extdata/multidim.zarr", package = "GDAL7")
ds <- gdal_open(path, multidim = TRUE)
arr <- open_mdarray(get_root_group(ds), "temperature")

# Decode the chunks of the first time step together, then read it.
advise_read(arr, start = c(1, 1, 1), count = c(1, 4, 5))
read_mdarray(arr, start = c(1, 1, 1), count = c(1, 4, 5))
#> , , 1
#> 
#>      [,1] [,2] [,3] [,4]
#> [1,]    1    6   11   16
#> [2,]    2    7   12   17
#> [3,]    3   NA   13   18
#> [4,]    4    9   14   19
#> [5,]    5   10   15   20
#> 

gdal_close(ds)
```
