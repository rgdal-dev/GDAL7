# Test driver capability

Check if driver has a specific capability (DCAP\_\* metadata). Common
capabilities include:

- DCAP_RASTER: Can handle raster data

- DCAP_VECTOR: Can handle vector data

- DCAP_CREATE: Can create new datasets

- DCAP_CREATECOPY: Can create datasets via CreateCopy

- DCAP_VIRTUALIO: Supports /vsimem/ and other virtual filesystems

## Usage

``` r
test_capability(x, capability)
```

## Arguments

- x:

  A GDALDriver object

- capability:

  Capability name (e.g., "DCAP_RASTER")

## Value

Logical TRUE if driver has the capability
