
<!-- README.md is generated from README.Rmd. Please edit that file -->

# GDAL7

<!-- badges: start -->

<!-- badges: end -->

The goal of GDAL7 is to model the GDAL api in R via SWIG.

## Installation

You can work with the (very) development version of GDAL7 like this:

``` r
#git clone https://github.com/rgdal-dev/GDAL7 \
#     && cd GDAL7 \ 
#     && R
cpp11::cpp_register()
#source("data-raw/fix_cpp11.R")
#fix_cpp11()

system("R CMD INSTALL --no-staged-install .")
```

If that doesn’t work, have a look through `data-raw/orchestrate.R`
because it did work.

## Example

This is a basic example.

``` r
library(GDAL7)
dsn <- "/vsicurl/https://projects.pawsey.org.au/idea-gebco-tif/GEBCO_2024.tif"
dsn2 <- "WMTS:https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/WMTS/1.0.0/WMTSCapabilities.xml,layer=World_Imagery"
#dsn <- "/vsicurl/https://raw.githubusercontent.com/mdsumner/rema-ovr/main/REMA-2m_dem_ovr.vrt"

ds <- gdal_open(dsn)
get_description(ds)                          #` - Get object description
#> [1] "/vsicurl/https://projects.pawsey.org.au/idea-gebco-tif/GEBCO_2024.tif"
set_description(ds, dsn2)                    #` - Set object description
gdal_close(ds)
ds <- gdal_open(dsn2)
get_metadata_domain_list(ds)                 #` - List metadata domains
#> [1] "SUBDATASETS"         ""                    "IMAGE_STRUCTURE"    
#> [4] "DERIVED_SUBDATASETS"
get_metadata_list(ds, "DERIVED_SUBDATASETS") #` - Get metadata as character vector
#> [1] "DERIVED_SUBDATASET_1_NAME=DERIVED_SUBDATASET:LOGAMPLITUDE:WMTS:https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/WMTS/1.0.0/WMTSCapabilities.xml,layer=World_Imagery"       
#> [2] "DERIVED_SUBDATASET_1_DESC=log10 of amplitude of input bands from WMTS:https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/WMTS/1.0.0/WMTSCapabilities.xml,layer=World_Imagery"
get_metadata_dict(ds, "IMAGE_STRUCTURE")     #` - Get metadata as key=value pairs
#> [1] "INTERLEAVE=PIXEL"
get_metadata_item(ds, "AREA_OR_POINT", "")   #` - Get single metadata item
#> [1] ""
#set_metadata(ds, metadata, domain)          #` - Set metadata
#set_metadata_item(ds, "AREA_OR_POINT", 
#                             "Point", "")   #` - Set single item

#### Dataset methods
get_projection(ds)      #` - Get projection as WKT string
#> [1] "PROJCS[\"WGS 84 / Pseudo-Mercator\",GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"4326\"]],PROJECTION[\"Mercator_1SP\"],PARAMETER[\"central_meridian\",0],PARAMETER[\"scale_factor\",1],PARAMETER[\"false_easting\",0],PARAMETER[\"false_northing\",0],UNIT[\"metre\",1,AUTHORITY[\"EPSG\",\"9001\"]],AXIS[\"Easting\",EAST],AXIS[\"Northing\",NORTH],EXTENSION[\"PROJ4\",\"+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs\"],AUTHORITY[\"EPSG\",\"3857\"]]"
get_projection_ref(ds)  #` - Alias for get_projection
#> [1] "PROJCS[\"WGS 84 / Pseudo-Mercator\",GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"4326\"]],PROJECTION[\"Mercator_1SP\"],PARAMETER[\"central_meridian\",0],PARAMETER[\"scale_factor\",1],PARAMETER[\"false_easting\",0],PARAMETER[\"false_northing\",0],UNIT[\"metre\",1,AUTHORITY[\"EPSG\",\"9001\"]],AXIS[\"Easting\",EAST],AXIS[\"Northing\",NORTH],EXTENSION[\"PROJ4\",\"+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs\"],AUTHORITY[\"EPSG\",\"3857\"]]"
get_file_list(ds)       #` - Get list of files comprising dataset
#> character(0)
get_gcpcount(ds)        #` - Get number of GCPs
#> [1] 0
get_gcpprojection(ds)   #` - Get GCP projection string
#> [1] ""
get_layer_count(ds)     #` - Get number of vector layers
#> [1] 0
#flush_cache(ds)         #` - Flush pending writes

c(get_raster_xsize(ds), get_raster_ysize(ds))
#> [1] 1073741766 1070224430

get_raster_count(ds)
#> [1] 4

#### bands

## do not use this after ds has been gdal_close(ds)

band <- get_raster_band(ds, 1L)
band
#> <GDAL7::GDALRasterBand>
#>  @ .ptr:<externalptr>
get_color_interpretation_name(band)
#> [1] "Red"
get_block_size(band)
#>   x   y 
#> 128 128
gdal_close(ds)
```

## Run a test/demo script

``` r
source("inst/examples/test_raster_info.R")
#> Test file: /perm_storage/home/mdsumner/gdal/autotest/gcore/data/byte.tif 
#> 
#> === Dataset Dimensions ===
#> Width:  20 pixels
#> Height: 20 pixels
#> Bands:  1
#> 
#> === Band 1 ===
#> <GDAL7::GDALRasterBand>
#>  @ .ptr:<externalptr> 
#> 
#> === Test with multi-band file ===
#> File: /perm_storage/home/mdsumner/gdal/autotest/gcore/data/rgbsmall.tif 
#> Size: 50 x 50 
#> Bands: 3 
#> 
#> Band 1 : Byte - Red 
#> Band 2 : Byte - Green 
#> Band 3 : Byte - Blue 
#> 
#> Success!

source("inst/examples/test_driver.R")
#> === Driver Count ===
#> Registered drivers: 204 
#> 
#> === Get Driver by Name ===
#> <GDAL7::GDALDriver>
#>  @ .ptr:<externalptr> 
#> 
#> === Get Driver from Dataset ===
#> Driver for byte.tif :
#> <GDAL7::GDALDriver>
#>  @ .ptr:<externalptr> 
#> 
#> === Common Drivers ===
#>   GTiff      GeoTIFF                        [RC]
#>   GPKG       GeoPackage                     [RVC]
#>   GeoJSON    GeoJSON                        [VC]
#>   PNG        Portable Network Graphics      [R]
#>   JPEG       JPEG JFIF                      [R]
#>   netCDF     Network Common Data Format     [RVC]
#>   Zarr       Zarr                           [RC]
#>   COG        Cloud optimized GeoTIFF generator [RC]
#> 
#> === List Raster Drivers ===
#> Total raster drivers: 145 
#> First 10:
#>    short_name                                  long_name create
#> 1     DERIVED Derived datasets using VRT pixel functions  FALSE
#> 2         GTI                     GDAL Raster Tile Index  FALSE
#> 3   SNAP_TIFF    Sentinel Application Processing GeoTIFF  FALSE
#> 4       GTiff                                    GeoTIFF   TRUE
#> 5         COG          Cloud optimized GeoTIFF generator   TRUE
#> 6   LIBERTIFF          GeoTIFF (using LIBERTIFF library)  FALSE
#> 7         VRT                             Virtual Raster   TRUE
#> 8        NITF       National Imagery Transmission Format   TRUE
#> 9      RPFTOC           Raster Product Format TOC format  FALSE
#> 10    ECRGTOC                            ECRG TOC format  FALSE
#> 
#> === List Vector Drivers ===
#> Total vector drivers: 75 
#> First 10:
#>      short_name                                            long_name create
#> 24          MEM In Memory raster, vector and multidimensional raster   TRUE
#> 35       PCIDSK                                 PCIDSK Database File   TRUE
#> 41       netCDF                           Network Common Data Format   TRUE
#> 47         PDS4                         NASA Planetary Data System 4   TRUE
#> 48        VICAR                                      MIPL VICAR file   TRUE
#> 51  JP2OpenJPEG        JPEG-2000 driver based on JP2OpenJPEG library  FALSE
#> 68          PDF                                       Geospatial PDF   TRUE
#> 69      MBTiles                                              MBTiles   TRUE
#> 102         BAG                           Bathymetry Attributed Grid   TRUE
#> 121        EEDA                                Earth Engine Data API  FALSE
#> 
#> Success!

source("inst/examples/test_multidim.R")
#> === Test Multidimensional API ===
#> 
#> Zarr driver: Zarr
#> netCDF driver: Network Common Data Format
#> 
#> 
#> === Opening in multidim mode: ===
#> /perm_storage/home/mdsumner/gdal/autotest/gdrivers/data/netcdf/alldatatypes.nc 
#> 
#> Root group:
#> <GDAL7::GDALGroup>
#>  @ .ptr:<externalptr> 
#> 
#> Subgroups:  group 
#> 
#> === Arrays ===
#> <GDAL7::GDALMDArray>
#>  @ .ptr:<externalptr> 
#> 
#> <GDAL7::GDALMDArray>
#>  @ .ptr:<externalptr> 
#> 
#> <GDAL7::GDALMDArray>
#>  @ .ptr:<externalptr> 
#> 
#> <GDAL7::GDALMDArray>
#>  @ .ptr:<externalptr> 
#> 
#> <GDAL7::GDALMDArray>
#>  @ .ptr:<externalptr> 
#> 
#> 
#> === Test with remote Zarr ===
#> Opening: ZARR:"/vsicurl/https://raw.githubusercontent.com/mdsumner/virtualized/refs/heads/main/remote/ocean_salt_2023.parq" 
#> <GDAL7::GDALGroup>
#>  @ .ptr:<externalptr> 
#> [1] "/"
#> [1] "/"
#> character(0)
#> 
#> First array:
#> <GDAL7::GDALMDArray>
#>  @ .ptr:<externalptr> 
#> [1] 1
#>   name size
#> 1 Time 5479
#> 
#> Success!
```

## Code of Conduct

Please note that the GDAL7 project is released with a [Contributor Code
of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
