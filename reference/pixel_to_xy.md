# Convert between pixel and georeferenced coordinates

`pixel_to_xy()` takes pixel and line positions to georeferenced ones,
and `xy_to_pixel()` takes them back again.

## Usage

``` r
pixel_to_xy(geotransform, pixel, line)

xy_to_pixel(geotransform, x, y)
```

## Arguments

- geotransform:

  A numeric vector of length 6, as a dataset's `geotransform` property
  returns.

- pixel, line:

  Numeric vectors of the same length. Fractional positions are
  meaningful: whole numbers fall on pixel corners, so the centre of the
  first pixel is `pixel = 0.5, line = 0.5`.

- x, y:

  Numeric vectors of the same length, in the dataset's coordinate
  reference system.

## Value

`pixel_to_xy()` a list of `x` and `y`. `xy_to_pixel()` a list of `pixel`
and `line`.

## Details

Both are vectorised, so a whole set of positions is one call.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.tif", package = "GDAL7"))
gt <- ds@geotransform

# The centre of the first pixel, and back again.
pixel_to_xy(gt, 0.5, 0.5)
#> $x
#> [1] -171
#> 
#> $y
#> [1] 81
#> 
xy_to_pixel(gt, -180 + 9, 90 - 9)
#> $pixel
#> [1] 0.5
#> 
#> $line
#> [1] 0.5
#> 

gdal_close(ds)
```
