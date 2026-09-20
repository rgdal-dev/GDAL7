# Package index

## The package

- [`GDAL7`](https://rgdal-dev.github.io/GDAL7/reference/GDAL7-package.md)
  [`GDAL7-package`](https://rgdal-dev.github.io/GDAL7/reference/GDAL7-package.md)
  : GDAL7: Modern GDAL Bindings for R Using S7

## Classes

Every GDAL handle reaches R as one of these S7 classes. Their accessors
are properties rather than get\_/set\_ functions, so a dataset’s size,
projection and geotransform are read with \$ and set the same way where
GDAL allows it.

- [`GDALMajorObject()`](https://rgdal-dev.github.io/GDAL7/reference/GDALMajorObject.md)
  : GDAL MajorObject class
- [`GDALDataset()`](https://rgdal-dev.github.io/GDAL7/reference/GDALDataset.md)
  : GDAL Dataset class
- [`GDALDriver()`](https://rgdal-dev.github.io/GDAL7/reference/GDALDriver.md)
  : GDALDriver class
- [`GDALRasterBand()`](https://rgdal-dev.github.io/GDAL7/reference/GDALRasterBand.md)
  : GDALRasterBand class
- [`GDALLayer()`](https://rgdal-dev.github.io/GDAL7/reference/GDALLayer.md)
  : GDAL layer class
- [`GDALGroup()`](https://rgdal-dev.github.io/GDAL7/reference/GDALGroup.md)
  : GDALGroup class
- [`GDALMDArray()`](https://rgdal-dev.github.io/GDAL7/reference/GDALMDArray.md)
  : GDALMDArray class

## Open and close a dataset

Opening is where a source is told what its own metadata does not say,
and closing is where a written dataset is actually finished. A dataset
closes itself when R garbage collects it, so gdal_close() is for closing
it sooner rather than for avoiding a leak.

- [`gdal_open()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_open.md)
  : Open a GDAL dataset
- [`gdal_close()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_close.md)
  : Close a GDAL dataset
- [`gdal_flush()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_flush.md)
  : Write out everything held in memory
- [`gdal_info()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_info.md)
  : Summarise a dataset in one call
- [`mark_suppress_on_close()`](https://rgdal-dev.github.io/GDAL7/reference/mark_suppress_on_close.md)
  : MarkSuppressOnClose
- [`get_thread_safe_dataset()`](https://rgdal-dev.github.io/GDAL7/reference/get_thread_safe_dataset.md)
  [`is_thread_safe()`](https://rgdal-dev.github.io/GDAL7/reference/get_thread_safe_dataset.md)
  : A view of a dataset that several threads may read at once
- [`get_close_reports_progress()`](https://rgdal-dev.github.io/GDAL7/reference/get_close_reports_progress.md)
  : GetCloseReportsProgress

## Drivers

What this build of GDAL can read and write, and what a given driver will
accept. Asking the library beats trusting a version number, because a
driver is only present if it was compiled in.

- [`gdal_drivers()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_drivers.md)
  : Every driver this GDAL has
- [`gdal_get_driver_count()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_get_driver_count.md)
  : Get the number of registered GDAL drivers
- [`gdal_get_driver()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_get_driver.md)
  : Get a driver by index
- [`gdal_get_driver_by_name()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_get_driver_by_name.md)
  : Get a driver by name
- [`get_driver()`](https://rgdal-dev.github.io/GDAL7/reference/get_driver.md)
  : Get the driver that opened a dataset
- [`driver_options()`](https://rgdal-dev.github.io/GDAL7/reference/driver_options.md)
  : What a driver will accept
- [`has_open_option()`](https://rgdal-dev.github.io/GDAL7/reference/has_open_option.md)
  : Check if driver has an open option
- [`validate_creation_options()`](https://rgdal-dev.github.io/GDAL7/reference/validate_creation_options.md)
  : Check creation options against a driver
- [`test_capability()`](https://rgdal-dev.github.io/GDAL7/reference/test_capability.md)
  : Test driver capability

## Raster I/O

read_raster() is one call onto GDALRasterIOEx: a fractional source
window, an output size chosen independently of it, a resampling
algorithm, and the values read straight into the R vector of the
requested type. Overviews are reached explicitly when a band’s own
pyramid is wanted.

- [`read_raster()`](https://rgdal-dev.github.io/GDAL7/reference/read_raster.md)
  : Read a window of raster data
- [`get_raster_band()`](https://rgdal-dev.github.io/GDAL7/reference/get_raster_band.md)
  : Get a raster band from a dataset
- [`get_overview()`](https://rgdal-dev.github.io/GDAL7/reference/get_overview.md)
  : Get one overview of a band
- [`flush_cache()`](https://rgdal-dev.github.io/GDAL7/reference/flush_cache.md)
  : FlushCache
- [`clear_statistics()`](https://rgdal-dev.github.io/GDAL7/reference/clear_statistics.md)
  : ClearStatistics

## Vector

Features come back over GDAL’s own Arrow stream rather than feature by
feature, so a layer read is a columnar transfer. The filters and the SQL
are set on the layer before the stream is asked for, and transactions
wrap edits on drivers that support them.

- [`read_vector()`](https://rgdal-dev.github.io/GDAL7/reference/read_vector.md)
  : Read a vector layer into a data frame
- [`get_layer()`](https://rgdal-dev.github.io/GDAL7/reference/get_layer.md)
  : Get a layer from a dataset
- [`feature_count()`](https://rgdal-dev.github.io/GDAL7/reference/feature_count.md)
  : Count the features of a layer
- [`get_extent()`](https://rgdal-dev.github.io/GDAL7/reference/get_extent.md)
  : The bounding box of a layer
- [`set_filter()`](https://rgdal-dev.github.io/GDAL7/reference/set_filter.md)
  : Restrict which features a layer returns
- [`reset_reading()`](https://rgdal-dev.github.io/GDAL7/reference/reset_reading.md)
  : ResetReading
- [`arrow_stream()`](https://rgdal-dev.github.io/GDAL7/reference/arrow_stream.md)
  : The Arrow stream of a layer
- [`release_arrow_stream()`](https://rgdal-dev.github.io/GDAL7/reference/release_arrow_stream.md)
  : Give an Arrow stream back to its layer
- [`execute_sql()`](https://rgdal-dev.github.io/GDAL7/reference/execute_sql.md)
  : Run an SQL statement against a dataset
- [`abort_sql()`](https://rgdal-dev.github.io/GDAL7/reference/abort_sql.md)
  : AbortSQL
- [`start_transaction()`](https://rgdal-dev.github.io/GDAL7/reference/start_transaction.md)
  : StartTransaction
- [`commit_transaction()`](https://rgdal-dev.github.io/GDAL7/reference/commit_transaction.md)
  : CommitTransaction
- [`rollback_transaction()`](https://rgdal-dev.github.io/GDAL7/reference/rollback_transaction.md)
  : RollbackTransaction
- [`get_field_domain_names()`](https://rgdal-dev.github.io/GDAL7/reference/get_field_domain_names.md)
  : GetFieldDomainNames
- [`delete_field_domain()`](https://rgdal-dev.github.io/GDAL7/reference/delete_field_domain.md)
  : DeleteFieldDomain
- [`get_relationship_names()`](https://rgdal-dev.github.io/GDAL7/reference/get_relationship_names.md)
  : GetRelationshipNames
- [`delete_relationship()`](https://rgdal-dev.github.io/GDAL7/reference/delete_relationship.md)
  : DeleteRelationship

## Multidimensional

GDAL’s multidimensional model, for the sources that have more than two
dimensions: netCDF, Zarr, HDF5. read_mdarray() returns dim in the order
the values arrive in, which is the reverse of GDAL’s own dimension
order; the array’s dimensions property still reports GDAL’s.

- [`get_root_group()`](https://rgdal-dev.github.io/GDAL7/reference/get_root_group.md)
  : Get root group from a multidimensional dataset
- [`open_group()`](https://rgdal-dev.github.io/GDAL7/reference/open_group.md)
  : Open a subgroup from a group
- [`open_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/open_mdarray.md)
  : Open an array from a group
- [`read_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/read_mdarray.md)
  : Read from a multidimensional array
- [`mdarray_info()`](https://rgdal-dev.github.io/GDAL7/reference/mdarray_info.md)
  : Everything about an array in one call
- [`get_view()`](https://rgdal-dev.github.io/GDAL7/reference/get_view.md)
  : Take a view of an array
- [`as_classic_dataset()`](https://rgdal-dev.github.io/GDAL7/reference/as_classic_dataset.md)
  : See a two-dimensional slice of an array as an ordinary raster
- [`as_mdarray()`](https://rgdal-dev.github.io/GDAL7/reference/as_mdarray.md)
  : AsMDArray

## Algorithms and pipelines

GDAL’s own algorithm registry, the C API behind the gdal command line. A
pipeline is named and its arguments passed as a list, so anything the
installed GDAL registers is callable without a wrapper being written for
it here. Not every build has it: ask gdal_has_algorithms() first.

- [`gdal_has_algorithms()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_has_algorithms.md)
  : Whether this GDAL has algorithms to run
- [`gdal_algorithms()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_algorithms.md)
  : List GDAL's algorithms
- [`gdal_algorithm_info()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_algorithm_info.md)
  : Describe one of GDAL's algorithms
- [`gdal_run()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_run.md)
  : Run one of GDAL's algorithms

## Creating and writing

The write side. A dataset is created empty and filled, or copied from an
existing one in a single driver call, and creation options are validated
against the driver rather than discovered by the write failing.

- [`gdal_create()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_create.md)
  : Create a new raster dataset
- [`gdal_create_copy()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_create_copy.md)
  : Copy a dataset, in another format or with other options
- [`gdal_delete()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_delete.md)
  : Delete a dataset
- [`write_raster()`](https://rgdal-dev.github.io/GDAL7/reference/write_raster.md)
  : Write a raster window
- [`write_vector()`](https://rgdal-dev.github.io/GDAL7/reference/write_vector.md)
  : Write a data frame to a vector dataset
- [`add_band()`](https://rgdal-dev.github.io/GDAL7/reference/add_band.md)
  : AddBand
- [`create_mask_band()`](https://rgdal-dev.github.io/GDAL7/reference/create_mask_band.md)
  : CreateMaskBand

## Metadata

Metadata on any major object, in GDAL’s domains. The same six functions
serve a dataset, a band, a layer, a group and an array.

- [`get_metadata_list()`](https://rgdal-dev.github.io/GDAL7/reference/get_metadata_list.md)
  : GetMetadata_List
- [`get_metadata_dict()`](https://rgdal-dev.github.io/GDAL7/reference/get_metadata_dict.md)
  : GetMetadata_Dict
- [`get_metadata_item()`](https://rgdal-dev.github.io/GDAL7/reference/get_metadata_item.md)
  : GetMetadataItem
- [`set_metadata()`](https://rgdal-dev.github.io/GDAL7/reference/set_metadata.md)
  : SetMetadata
- [`set_metadata_2()`](https://rgdal-dev.github.io/GDAL7/reference/set_metadata_2.md)
  : SetMetadata (overload 2)
- [`set_metadata_item()`](https://rgdal-dev.github.io/GDAL7/reference/set_metadata_item.md)
  : SetMetadataItem

## Coordinates and extents

Moving between pixel space, projected space and another coordinate
reference system. transform_extent() walks the edges of a box rather
than transforming its four corners, which is the difference between a
correct box and a wrong one wherever an edge is not monotonic.

- [`crs_to_wkt()`](https://rgdal-dev.github.io/GDAL7/reference/crs_to_wkt.md)
  : A coordinate reference system as WKT
- [`pixel_to_xy()`](https://rgdal-dev.github.io/GDAL7/reference/pixel_to_xy.md)
  [`xy_to_pixel()`](https://rgdal-dev.github.io/GDAL7/reference/pixel_to_xy.md)
  : Convert between pixel and georeferenced coordinates
- [`transform_extent()`](https://rgdal-dev.github.io/GDAL7/reference/transform_extent.md)
  : Move an extent between coordinate reference systems

## File systems

GDAL’s virtual file system, which is how a path into a zip, an S3 bucket
or an HTTP range request is read like a local file. These work on any
/vsi… path as well as on ordinary ones.

- [`vfs_list()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_list.md)
  [`vfs_stat()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_list.md)
  [`vfs_exists()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_list.md)
  : GDAL's virtual file systems
- [`vfs_read_file()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_read_file.md)
  [`vfs_write_file()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_read_file.md)
  : Read and write bytes over a GDAL virtual file system
- [`vfs_unlink()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_unlink.md)
  [`vfs_mkdir()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_unlink.md)
  [`vfs_rmdir()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_unlink.md)
  [`vfs_rename()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_unlink.md)
  [`vfs_copy()`](https://rgdal-dev.github.io/GDAL7/reference/vfs_unlink.md)
  : Change a GDAL virtual file system

## Configuration and capabilities

What this build can do, and how to change how it behaves. GDAL’s
configuration options are process-global, so with_gdal_config() sets
them for one expression and restores them afterwards.

- [`gdal_config()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_config.md)
  [`gdal_config_options()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_config.md)
  [`with_gdal_config()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_config.md)
  : GDAL's configuration options
- [`gdal7_capabilities()`](https://rgdal-dev.github.io/GDAL7/reference/gdal7_capabilities.md)
  : What this build of GDAL7 can reach
- [`gdal_release()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_release.md)
  : The GDAL library GDAL7 is running against
- [`gdal_constants()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_constants.md)
  : GDAL's integer constants
- [`gdal_data_types()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_data_types.md)
  [`gdal_color_interpretations()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_data_types.md)
  : GDAL enum tables
- [`gdal_string_constants()`](https://rgdal-dev.github.io/GDAL7/reference/gdal_string_constants.md)
  : GDAL's string constants
