# Open an array from a group

Open an array from a group

## Usage

``` r
open_mdarray(x, name)
```

## Arguments

- x:

  A GDALGroup object

- name:

  The array's name within this group, or a path from the root of the
  dataset such as `"/weather/temperature"`.

## Value

A GDALMDArray object, or NULL if not found
