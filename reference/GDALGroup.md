# GDALGroup class

Represents a group in a multidimensional dataset (NetCDF, Zarr, HDF5,
and the rest). Groups hold arrays
([GDALMDArray](https://rgdal-dev.github.io/GDAL7/reference/GDALMDArray.md))
and subgroups. What a group holds is a property of it: `name` and
`full_name`, the path from the root; `mdarray_names` and `group_names`,
what is in it; and `attributes`, the format's own annotations. Opening
one of them by name is
[`open_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/open_mdarray.md)
or
[`open_group()`](https://rgdal-dev.github.io/GDAL7/reference/open_group.md).

## Usage

``` r
GDALGroup(.ptr = NULL)
```

## Arguments

- .ptr:

  Internal. External pointer to the underlying GDAL object.
