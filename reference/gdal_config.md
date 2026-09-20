# GDAL's configuration options

GDAL reads these at the moment it needs them, so setting one changes how
the next call behaves. They steer caching, credentials, and a good deal
of per-driver behaviour: `GDAL_CACHEMAX` is the block cache size,
`CPL_VSIL_CURL_ALLOWED_EXTENSIONS` limits what `/vsicurl/` will fetch,
`AWS_NO_SIGN_REQUEST` makes an S3 bucket public.

## Usage

``` r
gdal_config(name, value)

gdal_config_options()

with_gdal_config(options, expr)
```

## Arguments

- name:

  The option's name.

- value:

  Its value, or NULL to unset it. A logical is written as GDAL writes
  them, `"YES"` or `"NO"`.

- options:

  A named character vector or list of options to set.

- expr:

  The expression to evaluate with them set.

## Value

`gdal_config()` reading returns a string or NULL, and setting returns
the previous value invisibly. `gdal_config_options()` returns every
option that is set, as a named character vector. `with_gdal_config()`
returns what `expr` returned.

## Details

`gdal_config()` with a value sets one; with only a name it reads one,
and returns NULL when it is not set, which is not the same as being set
to the empty string. `with_gdal_config()` sets options for one
expression and puts back exactly what was there, including unsetting
what was unset.

## Examples

``` r
# Read a raster with GDAL's block cache set small, then leave it as it was.
with_gdal_config(c(GDAL_CACHEMAX = "16"), {
  gdal_config("GDAL_CACHEMAX")
})
#> [1] "16"

gdal_config("GDAL_CACHEMAX")
#> NULL
```
