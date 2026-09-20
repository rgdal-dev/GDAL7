# Open a GDAL dataset

Open a GDAL dataset

## Usage

``` r
gdal_open(
  path,
  update = FALSE,
  multidim = FALSE,
  options = NULL,
  drivers = NULL
)
```

## Arguments

- path:

  Path to the dataset (file, URL, or connection string)

- update:

  Logical. If TRUE, open for update (read/write). Default FALSE.

- multidim:

  Logical. If TRUE, open in multidimensional mode (for NetCDF, Zarr,
  HDF5, etc.). Use get_root_group() to access the multidimensional
  structure. Default FALSE.

- options:

  Character vector of `KEY=VALUE` open options, or `NULL` for none.
  These are the driver's own, and are how a source is told what its own
  metadata does not say: a CSV's `X_POSSIBLE_NAMES=lon`, a raster's
  `OVERVIEW_LEVEL=2`.
  [`driver_options()`](https://rgdal-dev.github.io/GDAL7/reference/driver_options.md)
  lists what a driver accepts and
  [`has_open_option()`](https://rgdal-dev.github.io/GDAL7/reference/has_open_option.md)
  asks about one by name. An option a driver does not recognise is a
  warning from GDAL, not an error.

- drivers:

  Character vector of driver short names to try, or `NULL` to let every
  driver try, which is the default. Naming the driver skips the probing
  and stops a second driver claiming a file the first should have had.
  `character(0)` is not the same as `NULL`: it would allow no driver at
  all, so it is rejected.

## Value

A GDALDataset object

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))
ds@raster_count
#> [1] 2
gdal_close(ds)

# Naming the driver, and reading the first overview instead of full size.
ds <- gdal_open(system.file("extdata/overviews.tif", package = "GDAL7"),
                options = "OVERVIEW_LEVEL=0", drivers = "GTiff")
c(ds@raster_xsize, ds@raster_ysize)
#> [1] 256 128
gdal_close(ds)
if (FALSE) { # \dontrun{
# Multidimensional mode
ds <- gdal_open("/path/to/data.zarr", multidim = TRUE)
grp <- get_root_group(ds)
grp@mdarray_names
gdal_close(ds)
} # }
```
