# See a two-dimensional slice of an array as an ordinary raster

This is the bridge back to the rest of the package: the result is a
GDALDataset, so
[`read_raster()`](https://rgdal-dev.github.io/GDAL7/reference/read_raster.md),
its `geotransform` property and the band properties all work on it. The
array must have exactly two dimensions; take a
[`get_view()`](https://rgdal-dev.github.io/GDAL7/reference/get_view.md)
of it first if it has more.

## Usage

``` r
as_classic_dataset(x, x_dim = NULL, y_dim = NULL)
```

## Arguments

- x:

  A GDALMDArray object

- x_dim, y_dim:

  Which dimension is the raster's X and which its Y, counting from 1 in
  the array's own dimension order. By default the format's own
  horizontal X and Y dimensions are used, falling back to the last two.

## Value

A GDALDataset object.
