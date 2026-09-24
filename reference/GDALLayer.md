# GDAL layer class

S7 class wrapping an OGRLayer. A layer belongs to the dataset it came
from, and stops working when that dataset is closed.

`fid_column` and `geometry_column` are the names those two columns have
when the layer is read with
[`read_vector()`](https://rgdal-dev.github.io/GDAL7/reference/read_vector.md)
or
[`arrow_stream()`](https://rgdal-dev.github.io/GDAL7/reference/arrow_stream.md):
the names the format declares when it stores them as named columns, and
GDAL's own `OGC_FID` and `wkb_geometry` when it does not.
`geometry_column` is `NA` for a layer with no geometry.

## Usage

``` r
GDALLayer(.ptr = NULL)
```

## Arguments

- .ptr:

  Internal. External pointer to the underlying GDAL object.
