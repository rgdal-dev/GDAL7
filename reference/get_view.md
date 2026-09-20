# Take a view of an array

A view is a slice, a transpose or a reordering expressed in GDAL's own
view syntax, evaluated lazily: nothing is read until the view itself is
read. `"[0,:,:]"` is the first slice along the first dimension,
`"[:,::-1,:]"` flips the second, and `"[...]"` is the whole array.
Indices in a view expression are GDAL's, counting from 0.

## Usage

``` r
get_view(x, expr)
```

## Arguments

- x:

  A GDALMDArray object

- expr:

  The view expression.

## Value

A GDALMDArray object, which reads like any other.

## Examples

``` r
path <- system.file("extdata/multidim.zarr", package = "GDAL7")
ds <- gdal_open(path, multidim = TRUE)
arr <- open_mdarray(get_root_group(ds), "temperature")

# Drop the time dimension by taking its first slice.
first <- get_view(arr, "[0,:,:]")
first@dimensions
#>   name size         type direction indexed
#> 1  lat    4 HORIZONTAL_Y     NORTH    TRUE
#> 2  lon    5 HORIZONTAL_X      EAST    TRUE

gdal_close(ds)
```
