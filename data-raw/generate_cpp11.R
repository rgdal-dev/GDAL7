# generate_cpp11.R
# Generate cpp11 bindings from parsed SWIG class definitions

# ============================================================================
# Type mapping utilities
# ============================================================================

# Map SWIG/C return types to cpp11 return types
map_return_type <- function(swig_type) {
  swig_type <- trimws(swig_type)

  # Normalize pointer spacing
  swig_type <- gsub("\\s*\\*", "*", swig_type)

  mapping <- list(
    "void" = "void",
    "int" = "int",
    "double" = "double",
    "bool" = "bool",
    "const char*" = "cpp11::strings",
    "char const*" = "cpp11::strings",
    "char*" = "cpp11::strings",
    "char**" = "cpp11::strings",
    "char **" = "cpp11::strings",
    "CPLErr" = "int",
    "OGRErr" = "int",
    "GIntBig" = "double"
  )

  # Check direct mapping
  if (swig_type %in% names(mapping)) {
    return(mapping[[swig_type]])
  }

  # GDAL object pointers -> SEXP (external pointer)
  if (grepl("Shadow\\*$|HS\\*$|ShadowH\\*$", swig_type)) {
    return("SEXP")
  }

  # Default: pass through (might need manual fix)
  swig_type
}

# Map parameter types to cpp11 parameter types
map_param_type <- function(param) {
  swig_type <- trimws(param$type)
  swig_type <- gsub("\\s*\\*", "*", swig_type)

  # String types
  if (swig_type %in% c("const char*", "char const*", "char*", "const char")) {
    return("std::string")
  }

  # String list with typemap
  if (grepl("char\\s*\\*\\*", swig_type)) {
    if (!is.na(param$typemap)) {
      if (param$typemap == "dict") {
        return("cpp11::list")  # Named list for KEY=VALUE
      }
    }
    return("cpp11::strings")  # Default string vector
  }

  # Primitives
  if (swig_type == "int") return("int")
  if (swig_type == "double") return("double")
  if (swig_type == "bool") return("bool")

  # GDAL objects
  if (grepl("Shadow\\*$|HS\\*$", swig_type)) {
    return("SEXP")
  }

  swig_type
}

# Get the GDAL C API handle type for a class
get_handle_type <- function(class_name) {
  handles <- list(
    "MajorObject" = "GDALMajorObjectH",
    "Dataset" = "GDALDatasetH",
    "RasterBand" = "GDALRasterBandH",
    "Driver" = "GDALDriverH",
    "Group" = "GDALGroupH",
    "MDArray" = "GDALMDArrayH",
    "Attribute" = "GDALAttributeH",
    "Dimension" = "GDALDimensionH",
    "Layer" = "OGRLayerH",
    "Feature" = "OGRFeatureH",
    "Geometry" = "OGRGeometryH",
    "SpatialReference" = "OGRSpatialReferenceH",
    "CoordinateTransformation" = "OGRCoordinateTransformationH"
  )

  if (class_name %in% names(handles)) {
    handles[[class_name]]
  } else {
    paste0("GDAL", class_name, "H")  # Guess
  }
}

# The gdal7::Kind an object of this class is wrapped as. Kinds drive both the
# external pointer tag and the ownership chain in inst/include/gdal7.h.
get_kind <- function(class_name) {
  kinds <- list(
    "Dataset" = "Dataset",
    "RasterBand" = "Band",
    "Driver" = "Driver",
    "Group" = "Group",
    "MDArray" = "MDArray",
    "SpatialReference" = "SpatialRef"
  )
  if (class_name %in% names(kinds)) kinds[[class_name]] else NA_character_
}

# The Kind to wrap a returned GDAL handle as, and whether the object it came
# out of is its parent. A band or a spatial reference is borrowed from the
# dataset and must not outlive it; a driver belongs to GDAL's driver manager
# and outlives everything, so it has no parent at all.
handle_to_kind <- function(handle_type) {
  kinds <- list(
    "GDALDatasetH" = list(kind = "Dataset", parent = TRUE),
    "GDALRasterBandH" = list(kind = "Band", parent = TRUE),
    "GDALDriverH" = list(kind = "Driver", parent = FALSE),
    "GDALGroupH" = list(kind = "Group", parent = TRUE),
    "GDALMDArrayH" = list(kind = "MDArray", parent = TRUE),
    "OGRSpatialReferenceH" = list(kind = "SpatialRef", parent = TRUE)
  )
  if (handle_type %in% names(kinds)) kinds[[handle_type]] else NULL
}

# Map SWIG return type to GDAL handle type
swig_to_handle_type <- function(swig_type) {
  swig_type <- trimws(swig_type)
  swig_type <- gsub("\\s*\\*", "*", swig_type)

  # Map common SWIG shadow types to handles
  mappings <- list(
    "GDALDatasetShadow*" = "GDALDatasetH",
    "GDALRasterBandShadow*" = "GDALRasterBandH",
    "GDALDriverShadow*" = "GDALDriverH",
    "OGRLayerShadow*" = "OGRLayerH",
    "OGRFeatureShadow*" = "OGRFeatureH",
    "OGRGeometryShadow*" = "OGRGeometryH",
    "OSRSpatialReferenceShadow*" = "OGRSpatialReferenceH",
    "OGRCoordinateTransformationShadow*" = "OGRCoordinateTransformationH",
    "GDALGroupHS*" = "GDALGroupH",
    "GDALMDArrayHS*" = "GDALMDArrayH",
    "GDALAttributeHS*" = "GDALAttributeH",
    "GDALDimensionHS*" = "GDALDimensionH",
    "GDALExtendedDataTypeHS*" = "GDALExtendedDataTypeH",
    "OGRFieldDomainShadow*" = "OGRFieldDomainH",
    "GDALRelationshipShadow*" = "GDALRelationshipH"
  )

  if (swig_type %in% names(mappings)) {
    return(mappings[[swig_type]])
  }

  # Fallback: try to guess from pattern
  if (grepl("Shadow\\*$", swig_type)) {
    base <- sub("Shadow\\*$", "", swig_type)
    return(paste0(base, "H"))
  }
  if (grepl("HS\\*$", swig_type)) {
    base <- sub("HS\\*$", "", swig_type)
    return(paste0(base, "H"))
  }

  # Default
  "void*"
}

# Get the GDAL C API function prefix for a class
get_api_prefix <- function(class_name) {
  prefixes <- list(
    "MajorObject" = "GDALMajorObject",
    "Dataset" = "GDAL",
    "RasterBand" = "GDALRasterBand",
    "Driver" = "GDALDriver",
    "Group" = "GDALGroup",
    "MDArray" = "GDALMDArray",
    "Attribute" = "GDALAttribute",
    "Dimension" = "GDALDimension",
    "Layer" = "OGR_L",
    "Feature" = "OGR_F",
    "Geometry" = "OGR_G",
    "SpatialReference" = "OSR",
    "CoordinateTransformation" = "OCT"
  )

  if (class_name %in% names(prefixes)) {
    prefixes[[class_name]]
  } else {
    paste0("GDAL", class_name)
  }
}

# Convert CamelCase to snake_case
to_snake_case <- function(name) {
  # Insert underscore before capitals, then lowercase
  name <- gsub("([a-z])([A-Z])", "\\1_\\2", name)
  tolower(name)
}

# ============================================================================
# Code generation
# ============================================================================

# Generate the file header
generate_header <- function(class_name) {
  handle_type <- get_handle_type(class_name)
  class_lower <- tolower(class_name)
  kind <- get_kind(class_name)

  # MajorObject is the base of the hierarchy rather than a class of its own, so
  # its bindings are handed a dataset, a band or a driver and only the shared
  # part of the API is reachable through them.
  accessor <- if (class_name == "MajorObject") {
    sprintf('inline %s get_%s_handle(SEXP xp) {
    return gdal7::major_object(xp);
}', handle_type, class_lower)
  } else if (is.na(kind)) {
    stop(sprintf("No gdal7::Kind is defined for class %s", class_name))
  } else {
    sprintf('inline %s get_%s_handle(SEXP xp) {
    return gdal7::get<%s>(xp, gdal7::Kind::%s);
}', handle_type, class_lower, handle_type, kind)
  }

  sprintf('// Auto-generated by GDAL7 generator - do not edit
#include "gdal7.h"

using namespace cpp11;

// -----------------------------------------------------------------------------
// %s bindings
// -----------------------------------------------------------------------------

namespace {

// Fetch the handle, checking both that the external pointer is of the right
// kind and that nothing it depends on has been closed.
%s

}  // namespace
', class_name, accessor)
}

# Generate a single method binding
generate_method <- function(method, class_name) {
  class_lower <- tolower(class_name)
  method_lower <- to_snake_case(method$name)
  handle_type <- get_handle_type(class_name)
  return_type <- map_return_type(method$return_type)

  # Build parameter list
  params <- list()
  params[[1]] <- "SEXP xp"  # Always have the object pointer first

  param_names <- c()
  for (p in method$params) {
    cpp_type <- map_param_type(p)
    params <- c(params, sprintf("%s %s", cpp_type, p$name))
    param_names <- c(param_names, p$name)
  }

  param_str <- paste(params, collapse = ", ")

  # Build function body
  body_lines <- c()
  body_lines <- c(body_lines, sprintf("    %s h = get_%s_handle(xp);",
                                      handle_type, class_lower))

  # Generate the GDAL C API call
  gdal_call <- generate_gdal_call(method, class_name, param_names)

  # Handle return type
  if (return_type == "void") {
    body_lines <- c(body_lines, sprintf("    %s;", gdal_call))
  } else if (return_type == "cpp11::strings" && !grepl("\\*\\*", method$return_type)) {
    # A single string. NULL from GDAL means "not set", which reaches R as NA
    # rather than being flattened into "".
    body_lines <- c(body_lines, sprintf("    return gdal7::chr(%s);", gdal_call))
  } else if (return_type == "cpp11::strings") {
    # Check if borrowed reference (GetMetadata) vs owned (GetMetadataDomainList, GetFileList)
    is_borrowed <- grepl("^GetMetadata$|^GetMetadata_", method$name)
    is_dict <- grepl("^GetMetadata_Dict", method$name)

    if (is_borrowed) {
      # Borrowed from the object - do not free
      if (is_dict) {
        body_lines <- c(body_lines, sprintf("    return gdal7::named_from_csl(%s);", gdal_call))
      } else {
        body_lines <- c(body_lines, sprintf("    return gdal7::from_csl(%s);", gdal_call))
      }
    } else {
      body_lines <- c(body_lines, sprintf("    char** result = %s;", gdal_call))
      body_lines <- c(body_lines, "    strings out = gdal7::from_csl(result);")
      body_lines <- c(body_lines, "    CSLDestroy(result);")
      body_lines <- c(body_lines, "    return out;")
    }
  } else if (return_type == "int" && method$return_type == "CPLErr") {
    base_name <- sub("_[0-9]+$", "", method$name)

    # Check if we have a CSL that needs freeing (only for SetMetadata, not SetMetadataItem)
    has_csl <- base_name == "SetMetadata" && any(sapply(method$params, function(p) {
      map_param_type(p) %in% c("cpp11::list", "cpp11::strings")
    }))

    # Also check for single-string SetMetadata (char* not char**)
    is_single_string_setmetadata <- base_name == "SetMetadata" &&
      length(method$params) >= 1 &&
      !grepl("\\*\\*", method$params[[1]]$type) &&
      grepl("char", method$params[[1]]$type)

    # The scope collects what GDAL says about this call, so a failure is
    # reported with its own message rather than whatever was left over from an
    # earlier one.
    body_lines <- c(body_lines, "    gdal7::ErrorScope err;")

    if (has_csl || is_single_string_setmetadata) {
      if (is_single_string_setmetadata && !has_csl) {
        domain_arg <- if (length(method$params) > 1) {
          sprintf("%s.c_str()", param_names[2])
        } else { '""' }
        body_lines <- c(body_lines, "    CPLStringList csl;")
        body_lines <- c(body_lines, sprintf("    csl.AddString(%s.c_str());", param_names[1]))
        body_lines <- c(body_lines, sprintf("    CPLErr status = GDALSetMetadata(h, csl.List(), %s);", domain_arg))
      } else if (has_csl) {
        csl_param <- which(sapply(method$params, function(p) {
          map_param_type(p) %in% c("cpp11::list", "cpp11::strings")
        }))[1]
        csl_name <- param_names[csl_param]
        domain_arg <- if (length(param_names) > csl_param) {
          sprintf("%s.c_str()", param_names[length(param_names)])
        } else { '""' }
        body_lines <- c(body_lines, sprintf("    CPLStringList csl = gdal7::to_csl(%s);", csl_name))
        body_lines <- c(body_lines, sprintf("    CPLErr status = GDALSetMetadata(h, csl.List(), %s);", domain_arg))
      }
    } else {
      body_lines <- c(body_lines, sprintf("    CPLErr status = %s;", gdal_call))
    }
    body_lines <- c(body_lines, "    if (status != CE_None) {")
    body_lines <- c(body_lines, sprintf('        err.stop("%s failed");', base_name))
    body_lines <- c(body_lines, "    }")
    body_lines <- c(body_lines, "    err.flush();")
    body_lines <- c(body_lines, "    return static_cast<int>(status);")
  } else if (return_type == "SEXP") {
    # GDAL object return - wrap it with the ownership chain that keeps whatever
    # it was taken out of alive for as long as R can still reach it.
    handle_type <- swig_to_handle_type(method$return_type)
    wrapping <- handle_to_kind(handle_type)
    if (is.null(wrapping)) {
      stop(sprintf("No gdal7::Kind is defined for handle type %s", handle_type))
    }

    parent_arg <- if (wrapping$parent) ", xp" else ""
    body_lines <- c(body_lines, sprintf("    %s result = %s;", handle_type, gdal_call))
    body_lines <- c(body_lines, sprintf("    return gdal7::wrap(result, gdal7::Kind::%s%s);",
                                        wrapping$kind, parent_arg))
  } else {
    body_lines <- c(body_lines, sprintf("    return %s;", gdal_call))
  }

  body <- paste(body_lines, collapse = "\n")

  # Assemble function
  sprintf('
[[cpp11::register]]
%s GDAL7_%s_%s(%s) {
%s
}
', return_type, class_lower, method_lower, param_str, body)
}

# Generate the GDAL C API call for a method
generate_gdal_call <- function(method, class_name, param_names) {
  # Map method name to GDAL C API function
  # MajorObject methods use GDALGetDescription(h), GDALSetDescription(h, val), etc.

  base_name <- sub("_[0-9]+$", "", method$name)  # Strip overload suffix
  gdal_func <- map_method_to_gdal_func(method$name, class_name)

  # Special case: SetMetadata with single string needs array wrapping
  if (base_name == "SetMetadata" && length(method$params) >= 1) {
    first_param <- method$params[[1]]
    # Check if first param is a single string (not char**)
    if (!grepl("\\*\\*", first_param$type) && grepl("char", first_param$type)) {
      # Single string variant - return special call
      domain_param <- if (length(method$params) > 1) {
        sprintf("%s.c_str()", param_names[2])
      } else {
        '""'
      }
      return(sprintf("GDALSetMetadata(h, CPLStringList().AddString(%s.c_str()).List(), %s)",
                     param_names[1], domain_param))
    }
  }

  # Build argument list
  args <- c("h")  # Handle is always first

  for (i in seq_along(method$params)) {
    p <- method$params[[i]]
    pname <- param_names[i]

    # Convert cpp11 types to C types where needed
    if (map_param_type(p) == "std::string") {
      args <- c(args, sprintf("%s.c_str()", pname))
    } else if (map_param_type(p) %in% c("cpp11::list", "cpp11::strings")) {
      # The CPLStringList temporary lives until the call returns and then frees
      # itself, which the CSLAddString loops this replaces did not.
      args <- c(args, sprintf("gdal7::to_csl(%s).List()", pname))
    } else {
      args <- c(args, pname)
    }
  }

  sprintf("%s(%s)", gdal_func, paste(args, collapse = ", "))
}

# Map SWIG method name to GDAL C API function name
map_method_to_gdal_func <- function(method_name, class_name) {
  # Strip overload suffix for lookup
  base_name <- sub("_[0-9]+$", "", method_name)

  # Class-specific method mappings
  # These map SWIG method names to actual GDAL C API function names
  dataset_methods <- list(
    "GetDriver" = "GDALGetDatasetDriver",
    "GetRasterBand" = "GDALGetRasterBand",
    "GetProjection" = "GDALGetProjectionRef",
    "GetProjectionRef" = "GDALGetProjectionRef",
    "SetProjection" = "GDALSetProjection",
    "GetSpatialRef" = "GDALGetSpatialRef",
    "SetSpatialRef" = "GDALSetSpatialRef",
    "GetGeoTransform" = "GDALGetGeoTransform",
    "SetGeoTransform" = "GDALSetGeoTransform",
    "GetGCPCount" = "GDALGetGCPCount",
    "GetGCPProjection" = "GDALGetGCPProjection",
    "GetGCPSpatialRef" = "GDALGetGCPSpatialRef",
    "FlushCache" = "GDALFlushCache",
    "AddBand" = "GDALAddBand",
    "CreateMaskBand" = "GDALCreateMaskBand",
    "GetFileList" = "GDALGetFileList",
    "GetLayerCount" = "GDALDatasetGetLayerCount",
    "GetLayer" = "GDALDatasetGetLayer",
    "GetLayerByName" = "GDALDatasetGetLayerByName",
    "GetLayerByIndex" = "GDALDatasetGetLayer",
    "Close" = "GDALClose",
    "GetRasterXSize" = "GDALGetRasterXSize",
    "GetRasterYSize" = "GDALGetRasterYSize",
    "GetRasterCount" = "GDALGetRasterCount"
  )

  majorobject_methods <- list(
    "GetDescription" = "GDALGetDescription",
    "SetDescription" = "GDALSetDescription",
    "GetMetadata_Dict" = "GDALGetMetadata",
    "GetMetadata_List" = "GDALGetMetadata",
    "GetMetadataDomainList" = "GDALGetMetadataDomainList",
    "SetMetadata" = "GDALSetMetadata",
    "GetMetadataItem" = "GDALGetMetadataItem",
    "SetMetadataItem" = "GDALSetMetadataItem"
  )

  # Select mapping based on class
  if (class_name == "Dataset") {
    if (base_name %in% names(dataset_methods)) {
      return(dataset_methods[[base_name]])
    }
  }

  # Check common MajorObject methods (inherited)
  if (base_name %in% names(majorobject_methods)) {
    return(majorobject_methods[[base_name]])
  }

  # Default: prepend GDAL (this may need fixing for specific methods)
  paste0("GDAL", base_name)
}

# Generate all bindings for a class
generate_class_bindings <- function(parsed_class) {
  class_name <- parsed_class$public_name

  output <- generate_header(class_name)

  # Skip list - methods that don't generate correctly yet
  # (GDAL 3.9+ functions, complex signatures, callbacks, etc.)
  skip_methods <- c(
    "MarkSuppressOnClose",        # GDAL 3.9+
    "Close",                      # Callback params
    "GetCloseReportsProgress",    # GDAL 3.9+
    "IsThreadSafe",               # GDAL 3.9+
    "GetThreadSafeDataset",       # GDAL 3.9+
    "GetRootGroup",               # Complex return
    "SetProjection",              # Parser issue with param type
    "SetSpatialRef",              # Complex param
    "GetGeoTransform",            # Array output param
    "SetGeoTransform",            # Array input param
    "GetExtent",                  # Array output param
    "GetExtentWGS84LongLat",      # Array output param
    "BuildOverviews",             # Complex params
    "AddBand",                   # Complex params
    "CreateMaskBand",            # Complex params
    "AdviseRead",                # Complex params
    "GetFieldDomainNames",        # GDAL 3.3+
    "GetRelationshipNames",       # GDAL 3.6+
    "GetFieldDomain",             # Complex return
    "AddFieldDomain",             # Complex param
    "DeleteFieldDomain",          # GDAL 3.3+
    "UpdateFieldDomain",          # GDAL 3.3+
    "GetRelationship",            # Complex return
    "AddRelationship",            # Complex param
    "DeleteRelationship",         # GDAL 3.6+
    "UpdateRelationship",         # GDAL 3.6+
    "AsMDArray",                  # Complex return
    "StartTransaction",           # Needs OGR include
    "CommitTransaction",          # Needs OGR include
    "RollbackTransaction",        # Needs OGR include
    "AbortSQL",                   # Needs OGR include
    "ResetReading",               # Part of layer iteration
    "GetLayer",                   # Needs OGR include
    "GetLayerByName",             # Needs OGR include
    "ClearStatistics"             # GDAL 3.2+
  )

  # Track method names to handle overloads
  method_counts <- list()

  for (method in parsed_class$methods) {
    base_name <- sub("_[0-9]+$", "", method$name)

    # Skip problematic methods
    if (base_name %in% skip_methods) {
      next
    }

    # Handle overloaded methods by adding suffix
    if (is.null(method_counts[[base_name]])) {
      method_counts[[base_name]] <- 1
    } else {
      method_counts[[base_name]] <- method_counts[[base_name]] + 1
      # Mark this as an overload for special handling
      method$overload_num <- method_counts[[base_name]]
      method$name <- sprintf("%s_%d", base_name, method_counts[[base_name]])
    }

    output <- paste0(output, generate_method(method, class_name))
  }

  output
}

# ============================================================================
# Main entry point
# ============================================================================

generate_cpp11_file <- function(parsed_class, output_path = NULL) {
  code <- generate_class_bindings(parsed_class)

  if (!is.null(output_path)) {
    writeLines(code, output_path)
    message(sprintf("Generated %s", output_path))
  }

  invisible(code)
}

# ============================================================================
# Test (only runs in interactive mode when not sourced from orchestrate)
# ============================================================================

if (FALSE) {  # Set to TRUE to test standalone
  swig_dir <- "~/gdal/swig/include"
  source("data-raw/parse_swig.R", local = TRUE)

  result <- parse_swig_file(file.path(swig_dir, "MajorObject.i"), debug = FALSE)
  cls <- result$classes[[1]]

  code <- generate_cpp11_file(cls)
  cat(code)
}
