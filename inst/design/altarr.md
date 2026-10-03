# altarr in GDAL7: GDAL sources as lazy R arrays

Status: the map of record for using hypertidy/altarr from GDAL7. Stage A is
built and tested; the rest is staged. Written 2026-10-03 against GDAL 3.12.4
and altarr at a5297cb.

## Where altarr sits

altarr makes an ordinary R vector with a `dim` and no class whose values come
from a `fetch(chunks)` function, a batch of chunks per call. Base R's `x[i]`,
`x[cbind(i, j, k)]`, `sum()`, `mean()` and the rest plan their reads and ask
for those batches; `x[i, j, k]` still goes element by element until R offers
an array-subset hook. altarr's contract says concurrency belongs inside the
fetch. GDAL already has it: that is the whole reason for this integration.

GDAL7's side of the contract is three things:

1. The chunk grid to plan on: the source's own storage chunking.
2. A way to make one batch one read, with the decoding spread over GDAL's
   threads rather than done one chunk at a time on R's.
3. A fetch that turns a batch of chunk coordinates into those reads.

The dimension order already agrees. `read_mdarray()` returns `dim` reversed
from GDAL's order, which is altarr's (and ncdf4's) order and the order the
values arrive in, so a fetch never transposes.

altarr stays in Suggests. GDAL7 does not depend on it to load or to check,
and nothing else in GDAL7 knows it exists.

## Stage A, built: block size, read advice, `as_altarr()`

- `arr@block_size`, from `GDALMDArrayGetBlockSize()`. GDAL's order, named like
  `arr@dimensions`, 0 where the format does not chunk (a contiguous netCDF
  variable). A band already had `band@block_size`.
- `advise_read()`, one generic over `GDALMDArrayAdviseReadEx()`,
  `GDALRasterAdviseRead()` and `GDALDatasetAdviseRead()`, taking the same
  slice or window as the matching read, plus `options`.
- `as_altarr()`, methods for a `GDALMDArray`, a path plus an array name, and a
  `GDALRasterBand`. The chunk shape is the source's, reversed into R's order;
  an unchunked dimension gets its full length if it is one of the two fastest
  varying and 1 otherwise, so a contiguous variable reads a grid per step.

The fetch, `chunk_fetch()` in `R/zz-altarr.R`, works per batch:

- It takes the bounding slice of the batch's chunks. If that slice holds at
  most `density` (default 4) times as many chunks as were asked for, it calls
  `advise_read()` on the slice, reads it with one `read_mdarray()` (or
  `read_raster()`), and cuts it into chunks in R.
- Otherwise, the batch is scattered (track points across a big cube) and it
  reads chunk by chunk, so two opposite corners never cost everything between
  them.

What advice does depends on the driver, read from GDAL 3.12.4's source:

| Driver | `AdviseRead` does | Without it |
| --- | --- | --- |
| Zarr (v2, v3) | decodes every chunk the slice touches on `NUM_THREADS` / `GDAL_NUM_THREADS` threads (all cores by default) into a cache the next reads use | `IRead` decodes chunk after chunk on the calling thread |
| netCDF | reads the slice into an in-memory array in one `nc_get_vara` | the read is already one call; advice costs a copy |
| GTiff / COG | nothing (the base class no-op) | `IRasterIO` already gathers a window's byte ranges into one multi-range request over `/vsicurl/` |
| others | the base no-op, which succeeds | |

So for Zarr the advice is the parallel read. For GeoTIFF the read is already
one request per window, and the advice is harmless.

Zarr cautions, both from `ZarrArray::IAdviseReadCommon()`: each advice
replaces the last (the cache is cleared), and the advice fails if the slice's
chunks will not fit in `CACHE_SIZE`, which defaults to half of GDAL's free
block cache. altarr batches 64 chunks for whole-array passes by default
(`altarr.batch_chunks`), which keeps the slice small; a user raising that
option on a big-chunk store may need `GDAL_CACHEMAX` raised too.

Saving: given a path, the fetch holds the path, array name and open options
and opens the dataset on first use, and again when a session stamp says the
handle came from a different session. `saveRDS()` writes a recipe of a few
kilobytes and `readRDS()` works in a fresh R. That is the first item on
altarr's own list ("a recipe pattern for fetches that close over external
handles") done for GDAL; given a handle, the array is session-bound, as
documented.

Measured in the sandbox (4 cores, local disk, GDAL 3.12.4): a 24 x 1024 x
1024 Float64 Zarr v2 array in 384 zlib chunks reads in 0.31 s plain and 0.21 s
advised (0.09 s advice, 0.12 s read). The gain locally is decode only; the
case advice is for is a remote store, where each of the threads also makes
its own range request. That case is not measurable from here
(`data.source.coop` and object stores are not reachable from the sandbox) and
is the first thing to time on a real machine.

Tests: `tests/testthat/test-altarr.R` writes a Zarr v2 store byte by byte (no
writer needed, any GDAL with the Zarr driver) chunked along every dimension,
and checks values against base R, that 27 neighbouring chunks are one fetch,
that scattered chunks are still right, nodata, the recipe round trip, and a
band.

## Stage B: types

`read_mdarray()` reads Float64 whatever the array holds, so `as_altarr()`
makes double arrays only. altarr supports integer and logical. Give
`read_mdarray()` a `type =` as `read_raster()` has (read straight into the R
vector, refuse rather than clamp), then pass it through. Raw needs altarr to
gain a raw type first (on its own list).

Also decide unpacking here: `read_mdarray()` applies nodata but not `scale`
and `offset`. One rule for both readers, then `as_altarr()` inherits it.

## Stage C: the classic raster side

- `as_altarr(band)` from a path, using the same reopening recipe.
- `as_altarr(dataset)` as `[x, y, band]`, one `GDALDatasetRasterIO` per batch
  over the bands asked for.
- Overviews: `as_altarr(band, overview = k)`, and a list of them for a
  pyramid. The list's shape (arrays plus scale factors) is altarr's
  `altarr_overviews()` convention to define; GDAL7 should fill it, not invent
  it.

## Stage D: scattered batches

Chunk-by-chunk is correct but serial for the case the survey calls the killer
demonstration: `x[cbind(lon_i, lat_i, time_i)]` along a track against a
multi-terabyte cube. Two steps, cheapest first:

1. Cluster the batch: split it into groups whose bounding slices are dense,
   and advise and read each. Pure R in `chunk_fetch()`.
2. Concurrent reads of disjoint slices in C++: one call taking a list of
   slices, read on a pool. For classic rasters this can go through
   `GDALGetThreadSafeDataset()` (3.10, already used by GDAL7). For
   multidimensional arrays GDAL has no thread-safe equivalent, so this needs a
   handle per thread, opened from the path the recipe already holds.

Showcase: BRAN2023 through kerchunk-parquet, which ndr already uses.

## Stage E: downstream

The dependency order from the survey, with GDAL7's part now in place:

1. ndr: put an `as_altarr()` result in `Variable@data`, make `isel()` call
   `altarr::altarr_extract()` when `altarr::is_altarr(data)`. GDAL7 is then an
   ndr backend.
2. adgl: `collect(as = "altarr")` for a full-resolution lazy grid, and
   multidimensional sources returning ndr objects backed by GDAL7 altarrs.
   adgl's own plot proxy stays: it decimates through overviews in one
   `RasterIO`, which a chunk contract cannot express.

## Not here, on purpose

- Strided or decimated reads: altarr's contract is chunk-granular; overview
  reads are adgl's proxy's job.
- Lazy computation: arithmetic on an altarr materialises; that is altarr's or
  a DelayedArray-style layer's concern.
- Coordinates: `arr@dimension_values` already reads them; joining them to the
  array is ndr's job.

## Open points

- `as_altarr` is GDAL7's name. If altarr itself grows an `as_altarr()`
  generic, the two should become one: altarr owns the generic, GDAL7
  registers methods.
- netCDF advice reads the slice twice into memory (the driver's cache, then
  the read). For netCDF the fetch could skip the advice; it needs measuring
  first.
- GDAL's own block cache also holds what a read touched. altarr's cache and
  GDAL's together can hold the same chunk twice; `GDAL_CACHEMAX` is the knob.
