# data-raw/localize-refs.py
# Copy a kerchunk Parquet reference store, rewriting the start of every
# reference path. This is how the BRAN2023 store in mdsumner/virtualized,
# whose references point at NCI's THREDDS server, is pointed back at the
# files on disk at NCI, so the virtual references article can be knitted
# in place:
#
#   python3 data-raw/localize-refs.py ocean_temp_2023.parq /scratch/.../ocean_temp_local.parq \
#     https://thredds.nci.org.au/thredds/fileServer/gb6/ /g/data/gb6/
#
# Usage: localize-refs.py SOURCE_STORE DEST_STORE OLD_PREFIX NEW_PREFIX
#   SOURCE_STORE is a local directory (clone the repository, or download the
#   store). Needs pyarrow.

import os
import shutil
import sys

import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.parquet as pq

src, dst, old, new = sys.argv[1:5]
if os.path.exists(dst):
    sys.exit(f"{dst} exists; remove it first")

shutil.copytree(src, dst)
count = 0
for root, _, files in os.walk(dst):
    for name in files:
        if not name.endswith(".parq"):
            continue
        path = os.path.join(root, name)
        table = pq.read_table(path)
        if "path" not in table.column_names:
            continue
        i = table.column_names.index("path")
        column = table.column(i)
        starts = pc.starts_with(column, old)
        rewritten = pc.if_else(
            starts,
            pc.binary_join_element_wise(pa.scalar(new),
                                        pc.utf8_slice_codeunits(column, len(old)), ""),
            column)
        table = table.set_column(i, table.schema.field(i), rewritten.cast(column.type))
        pq.write_table(table, path)
        count += 1
print(f"rewrote {count} reference files into {dst}")
