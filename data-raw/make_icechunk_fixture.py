# data-raw/make_icechunk_fixture.py
# Build inst/extdata/temperature.icechunk, the Icechunk repository the
# Icechunk article and its tests read.
#
# GDAL reads Icechunk (from 3.14) but does not write it, so the fixture is made
# with the icechunk Python library. It is small on purpose and has a history
# worth reading: two commits on main, a tag on the first, and a branch that
# diverges from the tag.
#
#   main        "first version of temperature" (tagged v1)
#               "correct the second time step" (time step 2 raised by 100)
#   experiment  "first version of temperature"
#               "try an offset on a branch"    (every value lowered by 50)
#
# Usage: python3 data-raw/make_icechunk_fixture.py
#   Needs: pip install icechunk zarr numpy

import os
import shutil
import sys

import icechunk
import numpy as np
import zarr

out = sys.argv[1] if len(sys.argv) > 1 else "inst/extdata/temperature.icechunk"
shutil.rmtree(out, ignore_errors=True)
repo = icechunk.Repository.create(icechunk.local_filesystem_storage(out))

ny, nx, nt = 18, 36, 3
lat = np.linspace(85, -85, ny)
lon = np.linspace(-175, 175, nx)
def field(t, bump=0.0):
    la, lo = np.meshgrid(np.deg2rad(lat), np.deg2rad(lon), indexing="ij")
    return (15 + 25*np.cos(la) - 10 + 5*np.sin(lo + t) + bump).astype("float32")

s = repo.writable_session("main")
root = zarr.group(store=s.store)
root.attrs["title"] = "GDAL7 Icechunk fixture"
# Zarr gives every array a fill value, and GDAL reads it as nodata, so the
# coordinates are given one they never hold (the default 0 is a valid time).
def coord(name, vals, attrs, fill):
    a = root.create_array(name, shape=vals.shape, dtype=vals.dtype, chunks=vals.shape,
                          dimension_names=[name], fill_value=fill)
    a[:] = vals; a.attrs.update(attrs)
coord("time", np.arange(nt, dtype="int32"), {"standard_name": "time", "units": "days since 2026-01-01", "axis": "T"}, -1)
coord("lat", lat, {"standard_name": "latitude", "units": "degrees_north", "axis": "Y"}, np.nan)
coord("lon", lon, {"standard_name": "longitude", "units": "degrees_east", "axis": "X"}, np.nan)
t = root.create_array("temperature", shape=(nt, ny, nx), dtype="float32", chunks=(1, 9, 18),
                      dimension_names=["time", "lat", "lon"], fill_value=np.float32("nan"))
t.attrs.update({"units": "degC", "long_name": "synthetic air temperature"})
t[:] = np.stack([field(i) for i in range(nt)])
first = s.commit("first version of temperature")
repo.create_tag("v1", first)

s = repo.writable_session("main")
root = zarr.open_group(store=s.store)
root["temperature"][1] = field(1, bump=100.0)
s.commit("correct the second time step")

repo.create_branch("experiment", first)
s = repo.writable_session("experiment")
root = zarr.open_group(store=s.store)
root["temperature"][:] = np.stack([field(i, bump=-50.0) for i in range(nt)])
s.commit("try an offset on a branch")
for b in ("main", "experiment"):
    print(b, [a.message for a in repo.ancestry(branch=b)])

# Earlier copies of the repo file, kept by local storage on every update. GDAL
# reads only the current one.
shutil.rmtree(os.path.join(out, "overwritten"), ignore_errors=True)
