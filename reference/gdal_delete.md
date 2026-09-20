# Delete a dataset

Through the driver rather than the file system, so the sidecar files a
format keeps beside its main one go too: a `.aux.xml`, a shapefile's
`.dbf` and `.shx`, a world file.

## Usage

``` r
gdal_delete(dsn, driver = "GTiff")
```

## Arguments

- dsn:

  The dataset to delete.

- driver:

  The driver's short name.

## Value

Nothing, invisibly.
