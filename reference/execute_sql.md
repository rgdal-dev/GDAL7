# Run an SQL statement against a dataset

Run an SQL statement against a dataset

## Usage

``` r
execute_sql(x, sql, dialect = NULL)
```

## Arguments

- x:

  A GDALDataset object.

- sql:

  The statement.

- dialect:

  The SQL dialect: `NULL` for the driver's own, `"SQLITE"` for GDAL's
  SQLite dialect, `"OGRSQL"` for GDAL's built-in one.

## Value

A GDALLayer holding the result set, or `NULL` for a statement that
returns none. The result set is released when the layer is garbage
collected, or when the dataset is closed.

## Examples

``` r
ds <- gdal_open(system.file("extdata/test.gpkg", package = "GDAL7"))
read_vector(execute_sql(ds, "SELECT name FROM places WHERE population > 1e6"))
#>   OGC_FID      name
#> 1       1 Melbourne
#> 2       2    Sydney
#> 3       3     Perth
gdal_close(ds)
```
