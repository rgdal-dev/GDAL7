// Vector access, by way of GDAL's column-oriented Arrow API (RFC 86).
//
// OGR_L_GetArrowStream fills an ArrowArrayStream with whole record batches, so
// a layer reaches R as a data frame without a per-feature binding surface at
// all. Feature and geometry classes become an optional convenience rather than
// a prerequisite for reading.

#include "gdal7.h"

#include <ogr_recordbatch.h>

using namespace cpp11;

namespace {

inline GDALDatasetH dataset(SEXP xp) {
    return gdal7::get<GDALDatasetH>(xp, gdal7::Kind::Dataset);
}

// The name GDAL gives a geometry type, so that a layer listing reads as
// "Point" rather than as 1.
inline strings geometry_type_name(OGRwkbGeometryType type) {
    return gdal7::chr(OGRGeometryTypeToName(type));
}

// And back again. The name-to-type direction only exists in GDAL's C++ header,
// so it is recovered by asking GDAL for the name of each type it defines. That
// keeps the two directions in step when GDAL adds a type, which a table here
// would not.
OGRwkbGeometryType geometry_type_from_name(const std::string& name) {
    if (name.empty() || EQUAL(name.c_str(), "Unknown")) {
        return wkbUnknown;
    }

    // The base types, then the same set again as Z, M and ZM.
    const int dimensions[] = {0, 1000, 2000, 3000};
    for (int dimension : dimensions) {
        for (int base = 0; base <= 17; ++base) {
            const auto type = static_cast<OGRwkbGeometryType>(base + dimension);
            const char* candidate = OGRGeometryTypeToName(type);
            if (candidate != nullptr && EQUAL(candidate, name.c_str())) {
                return type;
            }
        }
    }
    if (EQUAL(name.c_str(), "None")) {
        return wkbNone;
    }

    cpp11::stop("%s is not a geometry type GDAL knows", name.c_str());
}

// GDAL frees an ArrowArrayStream through its own release callback, and a
// released stream marks itself by nulling it. nanoarrow expects exactly this
// shape behind an external pointer of class "nanoarrow_array_stream".
void finalize_stream(SEXP xp) {
    auto* stream = static_cast<ArrowArrayStream*>(R_ExternalPtrAddr(xp));
    if (stream == nullptr) {
        return;
    }
    R_ClearExternalPtr(xp);
    if (stream->release != nullptr) {
        stream->release(stream);
    }
    delete stream;
}

}  // namespace

// ---------------------------------------------------------------------------
// Layers
// ---------------------------------------------------------------------------

[[cpp11::register]]
strings GDAL7_dataset_layer_names(SEXP xp) {
    GDALDatasetH h = dataset(xp);
    const int count = GDALDatasetGetLayerCount(h);

    writable::strings out(count);
    for (int i = 0; i < count; ++i) {
        OGRLayerH lyr = GDALDatasetGetLayer(h, i);
        const char* name = lyr == nullptr ? nullptr : OGR_L_GetName(lyr);
        if (name == nullptr) {
            out[i] = NA_STRING;
        } else {
            out[i] = r_string(name);
        }
    }
    return out;
}

[[cpp11::register]]
SEXP GDAL7_dataset_layer(SEXP xp, int index) {
    GDALDatasetH h = dataset(xp);

    gdal7::ErrorScope err;
    OGRLayerH lyr = GDALDatasetGetLayer(h, index);
    if (lyr == nullptr) {
        err.stop("There is no layer at that index");
    }
    SEXP out = PROTECT(gdal7::wrap(lyr, gdal7::Kind::Layer, xp));
    err.flush();
    UNPROTECT(1);
    return out;
}

[[cpp11::register]]
SEXP GDAL7_dataset_layer_by_name(SEXP xp, std::string name) {
    GDALDatasetH h = dataset(xp);

    gdal7::ErrorScope err;
    OGRLayerH lyr = GDALDatasetGetLayerByName(h, name.c_str());
    if (lyr == nullptr) {
        err.stop("There is no layer called " + name);
    }
    SEXP out = PROTECT(gdal7::wrap(lyr, gdal7::Kind::Layer, xp));
    err.flush();
    UNPROTECT(1);
    return out;
}

[[cpp11::register]]
SEXP GDAL7_dataset_execute_sql(SEXP xp, std::string sql, strings dialect) {
    GDALDatasetH h = dataset(xp);
    const bool default_dialect = dialect.size() == 0 || dialect[0] == NA_STRING;
    const std::string dialect_name =
        default_dialect ? std::string() : static_cast<std::string>(dialect[0]);

    gdal7::ErrorScope err;
    OGRLayerH lyr = GDALDatasetExecuteSQL(
        h, sql.c_str(), nullptr, default_dialect ? nullptr : dialect_name.c_str());
    if (lyr == nullptr) {
        // A statement with no result set is not a failure; DELETE and CREATE
        // both return nothing and both worked.
        if (err.failed()) {
            err.stop("The SQL statement failed");
        }
        err.flush();
        return R_NilValue;
    }

    SEXP out = PROTECT(gdal7::wrap(lyr, gdal7::Kind::SQLResult, xp));
    err.flush();
    UNPROTECT(1);
    return out;
}

[[cpp11::register]]
strings GDAL7_layer_name(SEXP xp) {
    return gdal7::chr(OGR_L_GetName(gdal7::layer(xp)));
}

[[cpp11::register]]
double GDAL7_layer_feature_count(SEXP xp, bool force) {
    gdal7::ErrorScope err;
    const GIntBig count = OGR_L_GetFeatureCount(gdal7::layer(xp), force ? TRUE : FALSE);
    err.flush();
    // -1 is GDAL's "I would have to count them", which is not a count.
    return count < 0 ? NA_REAL : static_cast<double>(count);
}

[[cpp11::register]]
strings GDAL7_layer_geometry_type(SEXP xp) {
    return geometry_type_name(OGR_L_GetGeomType(gdal7::layer(xp)));
}

[[cpp11::register]]
strings GDAL7_layer_crs(SEXP xp) {
    OGRSpatialReferenceH srs = OGR_L_GetSpatialRef(gdal7::layer(xp));
    if (srs == nullptr) {
        return gdal7::chr(nullptr);
    }

    char* wkt = nullptr;
    gdal7::ErrorScope err;
    const OGRErr status = OSRExportToWkt(srs, &wkt);
    if (status != OGRERR_NONE || wkt == nullptr) {
        CPLFree(wkt);
        err.flush();
        return gdal7::chr(nullptr);
    }
    strings out = gdal7::chr(wkt);
    CPLFree(wkt);
    err.flush();
    return out;
}

[[cpp11::register]]
bool GDAL7_layer_test_capability(SEXP xp, std::string capability) {
    return OGR_L_TestCapability(gdal7::layer(xp), capability.c_str()) != 0;
}

[[cpp11::register]]
doubles GDAL7_layer_extent(SEXP xp, bool force) {
    OGREnvelope envelope;
    gdal7::ErrorScope err;
    const OGRErr status = OGR_L_GetExtent(gdal7::layer(xp), &envelope, force ? TRUE : FALSE);
    if (status != OGRERR_NONE) {
        // An empty layer, or one that would have to be scanned, has no extent
        // to report. That is an answer, not a failure.
        err.flush();
        return writable::doubles({NA_REAL, NA_REAL, NA_REAL, NA_REAL});
    }
    err.flush();
    return writable::doubles({envelope.MinX, envelope.MinY,
                              envelope.MaxX, envelope.MaxY});
}

[[cpp11::register]]
void GDAL7_layer_set_attribute_filter(SEXP xp, strings where) {
    const bool clear = where.size() == 0 || where[0] == NA_STRING;
    const std::string text = clear ? std::string() : static_cast<std::string>(where[0]);

    gdal7::ErrorScope err;
    const OGRErr status = OGR_L_SetAttributeFilter(gdal7::layer(xp),
                                                   clear ? nullptr : text.c_str());
    if (status != OGRERR_NONE) {
        err.stop("The attribute filter was not accepted");
    }
    err.flush();
}

[[cpp11::register]]
void GDAL7_layer_set_spatial_filter(SEXP xp, doubles bbox) {
    OGRLayerH lyr = gdal7::layer(xp);

    gdal7::ErrorScope err;
    if (bbox.size() == 0) {
        OGR_L_SetSpatialFilter(lyr, nullptr);
    } else {
        OGR_L_SetSpatialFilterRect(lyr, bbox[0], bbox[1], bbox[2], bbox[3]);
    }
    err.flush();
}

[[cpp11::register]]
void GDAL7_layer_reset_reading(SEXP xp) {
    OGR_L_ResetReading(gdal7::layer(xp));
}

// ---------------------------------------------------------------------------
// The Arrow stream
// ---------------------------------------------------------------------------

[[cpp11::register]]
SEXP GDAL7_layer_arrow_stream(SEXP xp, strings options) {
    OGRLayerH lyr = gdal7::layer(xp);
    CPLStringList csl = gdal7::to_csl(options);

    std::unique_ptr<ArrowArrayStream> stream(new ArrowArrayStream());
    stream->release = nullptr;

    gdal7::ErrorScope err;
    if (!OGR_L_GetArrowStream(lyr, stream.get(), csl.List())) {
        err.stop("This layer would not open an Arrow stream");
    }
    err.flush();

    SEXP out = PROTECT(cpp11::safe[R_MakeExternalPtr](
        stream.get(), Rf_install("GDAL7_arrow_stream"), xp));
    cpp11::safe[R_RegisterCFinalizerEx](out, finalize_stream, static_cast<Rboolean>(1));
    stream.release();

    // nanoarrow reads a stream from any external pointer of this class, so the
    // batches travel to R without GDAL7 touching a single value.
    SEXP klass = PROTECT(cpp11::safe[Rf_mkString]("nanoarrow_array_stream"));
    Rf_setAttrib(out, R_ClassSymbol, klass);
    UNPROTECT(2);
    return out;
}

// A layer will only have one Arrow stream open at a time, so a stream has to
// be given back before the layer can be read again. Waiting for the garbage
// collector to do it would make the second read fail for no reason the caller
// can see.
[[cpp11::register]]
void GDAL7_release_arrow_stream(SEXP xp) {
    auto* stream = static_cast<ArrowArrayStream*>(R_ExternalPtrAddr(xp));
    if (stream == nullptr || stream->release == nullptr) {
        return;
    }
    // The producer nulls its own release callback, so the finalizer that frees
    // the box later will not release it twice.
    stream->release(stream);
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

[[cpp11::register]]
SEXP GDAL7_dataset_create_layer(SEXP xp, std::string name, strings crs,
                                std::string geometry_type, strings options) {
    GDALDatasetH h = dataset(xp);
    CPLStringList csl = gdal7::to_csl(options);

    const OGRwkbGeometryType type = geometry_type_from_name(geometry_type);

    gdal7::ErrorScope err;

    OGRSpatialReferenceH srs = nullptr;
    if (crs.size() > 0 && crs[0] != NA_STRING) {
        const std::string wkt = crs[0];
        srs = OSRNewSpatialReference(nullptr);
        if (OSRSetFromUserInput(srs, wkt.c_str()) != OGRERR_NONE) {
            OSRDestroySpatialReference(srs);
            err.stop("The coordinate reference system was not understood");
        }
    }

    OGRLayerH lyr = GDALDatasetCreateLayer(h, name.c_str(), srs, type, csl.List());
    if (srs != nullptr) {
        OSRDestroySpatialReference(srs);
    }
    if (lyr == nullptr) {
        err.stop("The layer could not be created");
    }

    SEXP out = PROTECT(gdal7::wrap(lyr, gdal7::Kind::Layer, xp));
    err.flush();
    UNPROTECT(1);
    return out;
}

[[cpp11::register]]
void GDAL7_layer_create_fields(SEXP xp, SEXP schema, strings skip, strings options) {
    OGRLayerH lyr = gdal7::layer(xp);
    CPLStringList csl = gdal7::to_csl(options);
    CPLStringList skipped = gdal7::to_csl(skip);

    auto* arrow_schema = static_cast<ArrowSchema*>(R_ExternalPtrAddr(schema));
    if (arrow_schema == nullptr || arrow_schema->release == nullptr) {
        cpp11::stop("The Arrow schema has already been released");
    }

    gdal7::ErrorScope err;
    // The top-level schema is the struct of all columns; each child is a field.
    // The geometry and the feature id are not fields: the layer already has
    // them, and asking the driver to create one is an error.
    for (int64_t i = 0; i < arrow_schema->n_children; ++i) {
        ArrowSchema* child = arrow_schema->children[i];
        const char* name = child->name == nullptr ? "" : child->name;
        if (skipped.FindString(name) >= 0) {
            continue;
        }
        if (!OGR_L_CreateFieldFromArrowSchema(lyr, child, csl.List())) {
            err.stop(std::string("The driver would not create a field for ") +
                     (child->name == nullptr ? "an unnamed column" : child->name));
        }
    }
    err.flush();
}

[[cpp11::register]]
void GDAL7_layer_write_arrow_batch(SEXP xp, SEXP schema, SEXP array, strings options) {
    OGRLayerH lyr = gdal7::layer(xp);
    CPLStringList csl = gdal7::to_csl(options);

    auto* arrow_schema = static_cast<ArrowSchema*>(R_ExternalPtrAddr(schema));
    auto* arrow_array = static_cast<ArrowArray*>(R_ExternalPtrAddr(array));
    if (arrow_schema == nullptr || arrow_schema->release == nullptr ||
        arrow_array == nullptr || arrow_array->release == nullptr) {
        cpp11::stop("The Arrow batch has already been released");
    }

    gdal7::ErrorScope err;
    if (!OGR_L_WriteArrowBatch(lyr, arrow_schema, arrow_array, csl.List())) {
        err.stop("The batch was not written");
    }
    err.flush();
}

[[cpp11::register]]
SEXP GDAL7_create_vector_dataset(std::string driver_name, std::string path,
                                 strings options) {
    CPLStringList csl = gdal7::to_csl(options);

    gdal7::ErrorScope err;
    GDALDriverH drv = GDALGetDriverByName(driver_name.c_str());
    if (drv == nullptr) {
        err.stop("There is no driver called " + driver_name);
    }

    // A vector dataset is a raster dataset with no raster in it, which is how
    // GDAL has modelled the two since they were merged.
    GDALDatasetH h = GDALCreate(drv, path.c_str(), 0, 0, 0, GDT_Unknown, csl.List());
    if (h == nullptr) {
        err.stop("The dataset could not be created");
    }

    SEXP out = PROTECT(gdal7::wrap(h, gdal7::Kind::Dataset));
    err.flush();
    UNPROTECT(1);
    return out;
}
