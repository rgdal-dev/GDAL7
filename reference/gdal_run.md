# Run one of GDAL's algorithms

Arguments are given by name, exactly as
[`gdal_algorithm_info()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_algorithm_info.md)
reports them, and are converted according to the type GDAL declares for
each. A dataset argument takes either a GDALDataset, which is handed
over as it stands, or a string for GDAL to open.

## Usage

``` r
gdal_run(path, args = list(), progress = interactive())
```

## Arguments

- path:

  The algorithm, as for
  [`gdal_algorithms()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_algorithms.md).

- args:

  A named list of arguments.

- progress:

  Whether to draw a progress bar. Interactive sessions do by default.

## Value

Invisibly: the output GDALDataset for an in-memory result, the path for
one written to a file, or NULL for an algorithm that produces no dataset
at all. A file has been written and closed by the time this returns, so
it can be opened straight away.

## Details

What comes back depends on where the algorithm was told to put its
result. Given an output format of `"MEM"` and an empty output name it
works in memory and hands back the GDALDataset, with nothing touching
disk. Given a file name it writes the file, closes it properly, and
hands back the path.

A long algorithm draws a progress bar and can be interrupted with
Ctrl-C. The interrupt is passed to GDAL, which stops at the next step it
checks, so it takes effect at the algorithm's own granularity rather
than instantly.

## Examples

``` r
if (gdal_has_algorithms()) {
  ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))

  # Reprojected into memory: no file is written. The bounding box is given
  # because the fixture covers the whole globe, which Web Mercator does not.
  out <- gdal_run("raster reproject", list(
    input = ds,
    output = "",
    "output-format" = "MEM",
    "dst-crs" = "EPSG:3857",
    bbox = c(-180, -85, 180, 85),
    "bbox-crs" = "EPSG:4326"
  ), progress = FALSE)

  out@projection
  gdal_close(out)
  gdal_close(ds)
}
```
