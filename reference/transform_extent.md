# Move an extent between coordinate reference systems

The four numbers of an extent, in another CRS, sampled two ways and
unioned.

## Usage

``` r
transform_extent(extent, from, to, densify = 21L, mesh = 64L)
```

## Arguments

- extent:

  Numeric of length 4: `c(xmin, ymin, xmax, ymax)`.

- from, to:

  Coordinate reference systems, as anything GDAL reads: an authority
  code like `"EPSG:4326"`, a PROJ string, WKT, or the contents of a
  `.prj` file.

- densify:

  How many points to add along each edge of the boundary walk. 21 is
  GDAL's own default. Zero walks the corners only, which is faster and
  wrong for any box wide enough that its edges bow.

- mesh:

  The interior mesh is `mesh + 1` points on a side, so 64 is a 65 by 65
  grid, which is what `reproj::reproj_extent()` uses. Zero skips the
  mesh and leaves only the walk.

## Value

A named numeric of length 4: `xmin`, `ymin`, `xmax`, `ymax`, with an
`"outside"` attribute giving the fraction of the mesh that has no image
in `to`. Zero is the ordinary case. Anything above it means the extent
returned is the envelope of the part that survived, which is narrower
than the box that was asked for.

## Details

GDAL walks the boundary of the box. For a transform that is well behaved
over the box that is provably enough, because an extreme of the easting
can only occur where the transform stops being locally invertible, and
that cannot happen in the interior. GDAL then patches the places it
knows the assumption fails: the pole at the target's central meridian,
plus or minus 180 from it, and Mercator's latitude limit.

It does not patch the ones nobody enumerated, so an interior mesh goes
in as well. A box around the antipode of an oblique azimuthal
equidistant comes back 365 km short in easting from the walk alone; a
box straddling an orthographic's limb comes back 8 percent short in
area. The mesh is not a replacement either: it spends almost all its
points in the interior and samples the boundary more coarsely than the
walk does. The union of the two is what this returns.
`inst/design/extent-transformation.md` has the measurements.

Both sides are read in x, y order whatever their authority says, so
`"EPSG:4326"` here means longitude then latitude.

An `xmax` below `xmin` is refused rather than read as an antimeridian
crossing. GDAL returns a crossing in the same wrapped form it was given,
and that form cannot be unioned: a minimum and a maximum over the two
samplings would turn 20 degrees across the dateline into the 340 degrees
the other way round. Split the box at the antimeridian and transform the
halves, which is what turning the answer into raster windows needs
anyway.

This is a transformation of four numbers, not a warp. It is what turns a
query rectangle given in one CRS into a window on a raster held in
another; it does not reproject any pixels.

## Examples

``` r
# An Antarctic box in longlat, as polar stereographic metres.
transform_extent(c(60, -70, 120, -60), "EPSG:4326", "EPSG:3031")
#>     xmin     ymin     xmax     ymax 
#>  1900488 -1666567  3333134  1666567 
#> attr(,"outside")
#> [1] 0

# What the corners alone would have given: the same box, half as wide,
# because the easting of a parallel peaks in the middle of that edge.
transform_extent(c(60, -70, 120, -60), "EPSG:4326", "EPSG:3031",
                 densify = 0, mesh = 0)
#>     xmin     ymin     xmax     ymax 
#>  1900488 -1666567  2886579  1666567 
#> attr(,"outside")
#> [1] 0
```
