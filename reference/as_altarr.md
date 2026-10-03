# A GDAL array or band as a lazy R array

Returns an ordinary double array: a `dim`, no class, and nothing read
yet. Base R indexing, [`sum()`](https://rdrr.io/r/base/sum.html),
[`mean()`](https://rdrr.io/r/base/mean.html) and the rest pull values
from GDAL as they need them, a batch of chunks at a time, and keep
recent chunks in a cache. The object is made by the altarr package
(`hypertidy/altarr`), which has to be installed; see
[`altarr::altarr_contract`](https://rdrr.io/pkg/altarr/man/altarr_contract.html)
for what base R reads lazily and what it materialises.

## Usage

``` r
as_altarr(x, ...)
```

## Arguments

- x:

  A
  [GDALMDArray](https://rgdal-dev.github.io/GDAL7/reference/GDALMDArray.md),
  a
  [GDALRasterBand](https://rgdal-dev.github.io/GDAL7/reference/GDALRasterBand.md),
  or the path of a multidimensional source.

- ...:

  See the Arguments section.

## Value

A lazy double array.

## Details

The chunks are the source's own: a multidimensional array's
`block_size`, or a band's `block_size`. A dimension the format does not
chunk along is given a chunk of its full length if it is one of the two
fastest varying (the first two in R's order), and 1 otherwise, so a
contiguous netCDF variable reads a whole grid per time step. `chunk`
overrides that, in R's dimension order.

Each batch of chunks altarr asks for is one GDAL read. The bounding
slice of the batch is first given to
[`advise_read()`](https://rgdal-dev.github.io/GDAL7/reference/advise_read.md),
so a Zarr array decodes every chunk in it on GDAL's threads at once,
then read in one call and cut into chunks in R. A batch spread so thinly
that its bounding slice holds more than `density` times as many chunks
as were asked for (points scattered over a large array, say) is read
chunk by chunk instead, so a few scattered chunks never cost the whole
slice between them.

Dimensions are in the order
[`read_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/read_mdarray.md)
gives, the reverse of GDAL's, with the names on `dimnames`: a
`(time, lat, lon)` array becomes `[lon, lat, time]`. A band is `[x, y]`,
the first row of the raster first, in the order
[`read_raster()`](https://rgdal-dev.github.io/GDAL7/reference/read_raster.md)
gives.

## Arguments

- `chunk`:

  The chunk shape, in R's dimension order. Defaults to the source's own,
  as above.

- `nodata_as_na`:

  Whether the source's nodata value reads as `NA`. TRUE by default, as
  for
  [`read_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/read_mdarray.md).

- `density`:

  How sparse a batch may be and still be read as one slice. Default 4.

- `array`, `options`:

  For a path: the array's name or its full path from the root, as for
  [`open_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/open_mdarray.md),
  and open options as for
  [`gdal_open()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_open.md).

## Saving

Given a path, the array keeps the path, the array's name and the
options, and opens the dataset on its first read, and again on the first
read in a new session. So
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html) writes a recipe of
about a kilobyte and [`readRDS()`](https://rdrr.io/r/base/readRDS.html)
gives back a working array anywhere the path still opens. Given an open
[GDALMDArray](https://rgdal-dev.github.io/GDAL7/reference/GDALMDArray.md)
or
[GDALRasterBand](https://rgdal-dev.github.io/GDAL7/reference/GDALRasterBand.md),
the array reads from that handle and works only while it is open and
only in this session.

As altarr's contract says, the source must not change underneath: values
are re-read after they leave the cache, and a recipe re-reads its
source.

## Examples

``` r
if (requireNamespace("altarr", quietly = TRUE)) {
  path <- system.file("extdata/multidim.zarr", package = "GDAL7")
  x <- as_altarr(path, array = "temperature")
  dim(x)
  x[2, 3, ]
  sum(x)
  altarr::altarr_stats(x)[["fetch_calls"]]
}
#> [1] 3
```
