#!/bin/sh
# String-array fixtures for read_mdarray() (run from the package root).
#
# inst/extdata/strings.nc: netCDF-4 `string` variables, from strings.cdl.
ncgen -4 -o inst/extdata/strings.nc data-raw/strings.cdl

# inst/extdata/strings.zarr: Zarr V3 written by zarr-python (3.2.1, numpy
# 2.5.1), zstd-compressed, chunks of 2 so every array has a short edge chunk:
#   u     fixed_length_utf32 (numpy <U6), dims n
#   s     null_terminated_bytes (numpy |S5), dims n
#   v     string + vlen-utf8, dims n
#   grid  fixed_length_utf32 (numpy <U4), dims (gy, gx), 3 x 2
rm -rf inst/extdata/strings.zarr
python3 - <<'PY'
import zarr, numpy as np
u = np.array(["alpha", "β-beta", "", "δέλτα", "e"], dtype="<U6")
s = np.array([b"ab", b"", b"cdef", b"g", b"hijkl"], dtype="|S5")
v = np.array(["one", "", "three", "日本語", "a longer string here"], dtype=object)
grid = np.array([["a", "bb"], ["ccc", "dddd"], ["e", "ff"]], dtype="<U4")
comp = zarr.codecs.ZstdCodec(level=1)
g = zarr.open_group("inst/extdata/strings.zarr", mode="w", zarr_format=3)
for name, data, dn in (("u", u, ["n"]), ("s", s, ["n"]), ("grid", grid, ["gy", "gx"])):
    a = g.create_array(name, shape=data.shape, dtype=data.dtype, chunks=(2,) * data.ndim,
                       compressors=comp, dimension_names=dn)
    a[...] = data
a = g.create_array("v", shape=v.shape, dtype=str, chunks=(2,), compressors=comp,
                   dimension_names=["n"])
a[...] = v
zarr.consolidate_metadata("inst/extdata/strings.zarr")
PY
