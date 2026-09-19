# data-raw

Everything here is development material. `.Rbuildignore` keeps the whole
directory out of the built package.

`ROADMAP.md` at the root of the repository is the plan of record: what is done,
what is next, and why. This file only says what the scripts here are and how to
run them.

## The generator

GDAL7's bindings are generated from GDAL's own SWIG interface files rather than
written by hand. The pipeline is:

```
GDAL's swig/include/*.i
        |
        v
  parse_swig.R          reads classes, methods, members, constants and the
        |               %extend bodies that say which C function each one calls
        v
  api_model.R           vendors the result as inst/api/gdal-api.json
        |
        +--> generate_cpp11.R      src/GDAL7_majorobject.cpp
        |                          src/GDAL7_dataset.cpp
        |
        +--> generate_s7.R         R/aaa-class-majorobject.R
        |                          R/aab-class-dataset.R
        |
        +--> generate_constants.R  src/GDAL7_constants.cpp
                                   src/GDAL7_capabilities.cpp
```

`cpp11::cpp_register()` then writes `src/cpp11.cpp` and `R/cpp11.R`.

Run the whole thing with:

```sh
Rscript data-raw/orchestrate.R
R CMD INSTALL --no-staged-install .
```

That needs no GDAL checkout, because the API model is vendored. It is also what
`.github/workflows/regenerate.yaml` runs on every commit before diffing the
working tree, so a hand edit to a generated file fails CI rather than surviving
until the next regeneration.

When GDAL itself moves on:

```sh
Rscript data-raw/orchestrate.R --refresh    # re-reads ~/gdal/swig/include
```

The change that makes to the generated code is then a reviewable diff.

## Version guards

`refresh_symbol_versions.R` fetches GDAL's public headers at each release tag
from GitHub and records, in `gdal-symbol-versions.csv`, the first release each C
symbol GDAL7 calls appears in. The generator wraps any binding newer than the
oldest release scanned in a `#if GDAL_VERSION_NUM` guard whose `#else` raises an
R error naming the release it would need. The binding itself always exists, so
registration and dispatch never depend on which GDAL the package was built
against, and `gdal7_capabilities()` reports the same thing at run time.

This is the one script that needs network access. Nothing else here does.

## Fixtures

`make_multidim_fixture.R` builds `inst/extdata/multidim.zarr` from a
multidimensional VRT, which is the readable record of what the fixture
contains. It needs `gdalmdimtranslate` on the PATH.

## Design documents

`GDAL7-rationale.md` and `GDAL7-dev-guide.md` are the original design notes: why
a generator, and how the pieces fit together. They are history rather than
specification, and the roadmap cites them where they still decide something.
