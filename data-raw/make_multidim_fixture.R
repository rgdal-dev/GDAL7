# data-raw/make_multidim_fixture.R
# Build inst/extdata/multidim.zarr, the fixture the multidimensional tests read.
#
# Zarr is written by GDAL itself with no external library, so the fixture can be
# rebuilt anywhere GDAL7 builds, and V3 is used because its layout has no
# dot-prefixed files for R CMD build to object to. The source is a
# multidimensional VRT, which is plain text and is the readable record of what
# the fixture contains.
#
# Usage: Rscript data-raw/make_multidim_fixture.R
#   Needs gdalmdimtranslate on the PATH.

out <- "inst/extdata/multidim.zarr"
vrt <- tempfile(fileext = ".vrt")

# A 3 by 4 by 5 array over time, latitude and longitude, holding 1 to 60 in
# reading order with one cell set to the nodata value. Small enough to assert
# every value, big enough that a step and an offset have somewhere to go.
values <- seq_len(60)
values[8] <- -999

writeLines(c(
  '<VRTDataset>',
  '  <Group name="/">',
  '    <Dimension name="time" size="3" type="TEMPORAL" indexingVariable="time"/>',
  '    <Dimension name="lat" size="4" type="HORIZONTAL_Y" direction="NORTH" indexingVariable="lat"/>',
  '    <Dimension name="lon" size="5" type="HORIZONTAL_X" direction="EAST" indexingVariable="lon"/>',
  '    <Array name="time">',
  '      <DataType>Float64</DataType>',
  '      <DimensionRef ref="time"/>',
  '      <RegularlySpacedValues start="0" increment="1"/>',
  '      <Attribute name="units"><DataType>String</DataType><Value>days since 2026-01-01</Value></Attribute>',
  '      <Attribute name="standard_name"><DataType>String</DataType><Value>time</Value></Attribute>',
  '    </Array>',
  '    <Array name="lat">',
  '      <DataType>Float64</DataType>',
  '      <DimensionRef ref="lat"/>',
  '      <RegularlySpacedValues start="-40" increment="-1"/>',
  '      <Attribute name="units"><DataType>String</DataType><Value>degrees_north</Value></Attribute>',
  '      <Attribute name="standard_name"><DataType>String</DataType><Value>latitude</Value></Attribute>',
  '    </Array>',
  '    <Array name="lon">',
  '      <DataType>Float64</DataType>',
  '      <DimensionRef ref="lon"/>',
  '      <RegularlySpacedValues start="140" increment="1"/>',
  '      <Attribute name="units"><DataType>String</DataType><Value>degrees_east</Value></Attribute>',
  '      <Attribute name="standard_name"><DataType>String</DataType><Value>longitude</Value></Attribute>',
  '    </Array>',
  '    <Array name="temperature">',
  '      <DataType>Float64</DataType>',
  '      <DimensionRef ref="time"/>',
  '      <DimensionRef ref="lat"/>',
  '      <DimensionRef ref="lon"/>',
  '      <NoDataValue>-999</NoDataValue>',
  '      <Unit>degC</Unit>',
  '      <Offset>0.5</Offset>',
  '      <Scale>2</Scale>',
  '      <Attribute name="long_name"><DataType>String</DataType><Value>air temperature</Value></Attribute>',
  '      <Attribute name="coordinates"><DataType>String</DataType><Value>lat lon</Value></Attribute>',
  '      <Attribute name="valid_range"><DataType>Float64</DataType><Value>-50</Value><Value>50</Value></Attribute>',
  '      <InlineValues>',
  paste("       ", paste(values, collapse = " ")),
  '      </InlineValues>',
  '    </Array>',
  '  </Group>',
  '</VRTDataset>'
), vrt)

unlink(out, recursive = TRUE)
status <- system2("gdalmdimtranslate",
                  c("-of", "Zarr", "-co", "FORMAT=ZARR_V3", shQuote(vrt), shQuote(out)))
if (status != 0) {
  stop("gdalmdimtranslate failed")
}

cat("Wrote", out, "\n")
cat(sum(file.size(list.files(out, recursive = TRUE, full.names = TRUE))), "bytes\n")
