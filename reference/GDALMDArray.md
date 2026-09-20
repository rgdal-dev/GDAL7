# GDALMDArray class

Represents a multidimensional array in a GDAL dataset. What the array
says about itself is a property of it:

## Usage

``` r
GDALMDArray(.ptr = NULL)
```

## Arguments

- .ptr:

  Internal. External pointer to the underlying GDAL object.

## Details

- `name` and `full_name`, the path from the root of the dataset.

- `data_type_name`, `unit_type`, `nodata_value`, `scale`, `offset`.

- `crs`, as WKT2.

- `dimension_count`, and `dimensions`, a data frame with one row per
  dimension: its `name` and `size`, the `type` and `direction` the
  format gave it (both may be empty), and `indexed`, whether it has a
  coordinate variable. Dimensions are in GDAL's order, slowest varying
  first, which is the order a format declares them in.
  [`read_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/read_mdarray.md)
  returns its `dim` the other way round; see there for why.

- `attributes`, the format's own annotations: units, long names,
  conventions, valid ranges. They come back all at once because reading
  them one at a time is what makes inspecting a large NetCDF slow.

- `coordinate_variables`, the arrays a format names as this one's
  coordinates. That is not quite the same question as which dimensions
  are indexed: a swath carries latitude and longitude arrays that are
  two-dimensional and index no dimension at all.

- `dimension_values`, each dimension's coordinate variable read in full,
  in the array's own dimension order. For a gridded array this is the
  time, latitude and longitude the values are placed at, and it is the
  shorter road than `coordinate_variables`. A dimension with no
  coordinate variable is NULL.
