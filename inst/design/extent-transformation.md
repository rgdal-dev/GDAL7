# Transforming an extent between coordinate reference systems

Status: a draft, parked deliberately. It records why `transform_extent()`
samples the way it does, and what is still unresolved. Written 2026-09-20
against GDAL 3.12.4.

## The question

Given a rectangle in one CRS, what is the smallest rectangle in another CRS
that contains its image? This is not a warp. Nothing is resampled. It is four
numbers in and four numbers out, and it is what turns a query rectangle given
in one CRS into a pixel window on a raster held in another.

Getting it wrong in the small direction is the dangerous failure: a window
picked from an extent that is too small clips data the caller asked for, and
nothing downstream can tell that it happened.

## Walking the boundary is right, until it is not

`OCTTransformBounds()`, which is GDAL's port of PROJ's `proj_trans_bounds()`,
walks the boundary of the box with `densify_pts` extra points along each edge
and takes the envelope of the result.

For a transform that is a diffeomorphism over the box, that is provably
sufficient. Let `u(p)` be the easting of `f(p)`. Then `grad u` is the first row
of the Jacobian of `f`. A non-singular Jacobian has no zero row, so `grad u` is
never zero in the interior, so `u` has no interior critical point, so its
extremes over a compact box lie on the boundary. The same argument holds for
the northing. There is nothing inside to find.

That is why the walk is exact, to the digit, for the cases anyone tries first:
longlat to Albers, longlat to Web Mercator, longlat to polar stereographic,
longlat to oblique Mercator.

The argument needs `f` to be defined and continuously differentiable on the
whole closed box. Where that fails, the conclusion fails with it:

- **a pole interior to the box**, where longitude is undefined and the Jacobian
  is singular;
- **a branch cut interior to the box**, where the map is discontinuous;
- **the antipode of an azimuthal projection**, where every direction maps to
  the same distance;
- **the limb of a projection that only covers part of the globe**, where `f` is
  undefined beyond it.

GDAL knows this and patches the cases it enumerated (`ogr/ogrct.cpp`, from
about line 3474): the pole at the target's central meridian, plus or minus 180
degrees from that meridian, and Mercator's latitude limit. Those patches work.
A longlat box containing the north pole transformed to EPSG:3413 comes back
exactly right.

The ones nobody enumerated fall through.

## What the walk misses, measured

Each row is the boundary walk at `densify = 21` against a 65 by 65 mesh over
the same box, both through GDAL 3.12.4.

| source box | target | walk misses |
| --- | --- | --- |
| `c(-175, -50, -165, -40)` longlat | `+proj=aeqd +lat_0=45 +lon_0=10` | 365 km in xmin and xmax, 539 km in ymin, 555 km in ymax |
| `c(90, -10, 130, 30)` longlat | `+proj=ortho +lat_0=45 +lon_0=10` | 98 km in xmax, 90 km in ymin, 8 percent of area |
| `c(110, -45, 155, -10)` longlat | EPSG:3577 | 92 m in ymax |
| `c(-180, -85, 180, 85)` longlat | EPSG:3857 | nothing |
| `c(60, -70, 120, -60)` longlat | EPSG:3031 | nothing |
| `c(-40, 80, 40, 89.9)` longlat | EPSG:3413 | nothing |

The first box surrounds the antipode of the projection's centre. The second
straddles the limb, where the maximum easting is the limb radius itself,
attained at an interior point.

The 92 m in the Albers row is a different thing and worth separating out. That
extreme is on the boundary, where the argument above says it should be; the
walk misses it only because 22 points along an edge is a coarser sample of that
arc than 65 is. It is the walk's own density showing, not interior structure,
and raising `densify` closes it while no amount of `densify` closes the first
two rows.

## A mesh is not a replacement

The obvious fix is to drop the walk and sample a grid, which is what
`reproj::reproj_extent()` does: a 65 by 65 grid, `range(..., finite = TRUE)`.
Its own history shows the change, since the commented-out `old_reproj_extent`
in that package walks the boundary and the current one does not.

But a mesh is a different sampling, not a better one. A 65 by 65 mesh spends
4097 of its 4225 points in the interior, where for a well-behaved transform
nothing is happening, and puts only 256 on the boundary, where everything is.
On a `c(-60, -60, 60, 60)` longlat box into an oblique Mercator, the mesh alone
comes back 2.4 km inside the walk's answer, because 65 points along an edge is
coarser than the walk's 22 per side.

So `transform_extent()` does both and takes the envelope of the two. It builds
one `OGRCoordinateTransformation`, which is most of the cost of the call, and
then moves `4 * (densify + 1)` points around the boundary and `(mesh + 1)^2`
through the interior. The union dominates either sampling alone by
construction, and the package tests assert exactly that.

## What is still unresolved

**The mesh size has no justification.** 64 is taken from `reproj`, where it was
picked by raising the number until the failures stopped rather than by
analysis. Nothing here establishes that 64 is enough, and nothing establishes
that it is not too many. The honest statement is that both samplings are
heuristics over a problem whose exact answer needs the geometry of the
particular transform.

**A better method probably exists.** The failures are all at known singular
points of the target projection: the antipode, the limb, the poles, the branch
cut. A transform that could be asked where its singularities are could be
sampled adaptively around them and proved correct everywhere else by the
Jacobian argument above. PROJ knows this about each projection; the C API does
not expose it. Short of that, refining the mesh where neighbouring samples
disagree by more than a tolerance would find the same places without knowing
their names in advance.

**Boxes crossing the antimeridian are refused.** GDAL reads `xmax < xmin` as a
crossing and answers in the same wrapped form. That form cannot survive a
union: a minimum and a maximum over two samplings turn 20 degrees across the
dateline into the 340 degrees the other way round. Supporting it properly means
carrying the wrapped convention through every comparison, or returning two
extents. Splitting the box is left to the caller, who has to split it anyway to
turn the answer into raster windows.

**Partial failure is reported but not described.** When part of a box has no
image in the target, the result is the envelope of the part that does, and the
`"outside"` attribute gives the fraction of the mesh that failed. That says how
much was lost but not where, and a caller that wanted to draw the valid region
would need more. When nothing transforms at all, this raises an error rather
than returning an envelope of infinities.

## Reproducing the numbers

`data-raw/measure-extent-transformation.R` regenerates the table. It needs
`gdaltransform` on the path for the independent mesh, so that the comparison
does not check GDAL against itself through the same code path.
