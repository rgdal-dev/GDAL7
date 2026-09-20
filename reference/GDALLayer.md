# GDAL layer class

S7 class wrapping an OGRLayer. A layer belongs to the dataset it came
from, and stops working when that dataset is closed.

## Usage

``` r
GDALLayer(.ptr = NULL)
```

## Arguments

- .ptr:

  Internal. External pointer to the underlying GDAL object.
