
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
source("data-raw/fix_cpp11.R")
fix_cpp11()

devtools::load_all()
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

That’s all for now.

## Code of Conduct

Please note that the GDAL7 project is released with a [Contributor Code
of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
