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
    "const char*" = "std::string",
    "char const*" = "std::string",
    "char*" = "std::string",
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

  sprintf('// Auto-generated by GDAL7 generator - do not edit
#include <cpp11.hpp>
#include "gdal.h"
#include "cpl_string.h"

using namespace cpp11;

// -----------------------------------------------------------------------------
// %s bindings
// -----------------------------------------------------------------------------

// Helper to extract and validate pointer
inline %s get_%s_handle(SEXP xp) {
    external_pointer<%s> ptr(xp);
    if (!ptr || !*ptr) {
        stop("Invalid %s pointer (NULL or already closed)");
    }
    return *ptr;
}

// Helper to convert R named character vector to char** (KEY=VALUE format)
inline char** strings_to_csl(cpp11::strings strs) {
    char** result = NULL;
    for (auto s : strs) {
        result = CSLAddString(result, std::string(s).c_str());
    }
    return result;
}

// Helper to convert R named list to char** (KEY=VALUE format)
inline char** list_to_csl(cpp11::list lst) {
    char** result = NULL;
    cpp11::strings names = lst.names();
    for (int i = 0; i < lst.size(); i++) {
        std::string key = std::string(names[i]);
        std::string val = cpp11::as_cpp<std::string>(lst[i]);
        std::string kv = key + "=" + val;
        result = CSLAddString(result, kv.c_str());
    }
    return result;
}
', class_name, handle_type, class_lower, handle_type, class_name)
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
  } else if (return_type == "std::string") {
    body_lines <- c(body_lines, sprintf("    const char* result = %s;", gdal_call))
    body_lines <- c(body_lines, "    return result ? std::string(result) : std::string(\"\");")
  } else if (return_type == "cpp11::strings") {
    # Check if borrowed reference (GetMetadata) vs owned (GetMetadataDomainList, GetFileList)
    is_borrowed <- grepl("^GetMetadata$|^GetMetadata_", method$name)

    if (is_borrowed) {
      body_lines <- c(body_lines, sprintf("    CSLConstList result = %s;", gdal_call))
    } else {
      body_lines <- c(body_lines, sprintf("    char** result = %s;", gdal_call))
    }
    body_lines <- c(body_lines, "    writable::strings out;")
    body_lines <- c(body_lines, "    if (result) {")
    body_lines <- c(body_lines, "        for (int i = 0; result[i] != NULL; i++) {")
    body_lines <- c(body_lines, "            out.push_back(result[i]);")
    body_lines <- c(body_lines, "        }")
    if (is_borrowed) {
      body_lines <- c(body_lines, "        // Borrowed reference - do not free")
    } else {
      body_lines <- c(body_lines, "        CSLDestroy(result);")
    }
    body_lines <- c(body_lines, "    }")
    body_lines <- c(body_lines, "    return out;")
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

    if (has_csl || is_single_string_setmetadata) {
      if (is_single_string_setmetadata && !has_csl) {
        domain_arg <- if (length(method$params) > 1) {
          sprintf("%s.c_str()", param_names[2])
        } else { '""' }
        body_lines <- c(body_lines, sprintf("    char** csl = CSLAddString(NULL, %s.c_str());", param_names[1]))
        body_lines <- c(body_lines, sprintf("    CPLErr err = GDALSetMetadata(h, csl, %s);", domain_arg))
      } else if (has_csl) {
        csl_param <- which(sapply(method$params, function(p) {
          map_param_type(p) %in% c("cpp11::list", "cpp11::strings")
        }))[1]
        csl_name <- param_names[csl_param]
        csl_convert <- if (map_param_type(method$params[[csl_param]]) == "cpp11::list") {
          sprintf("list_to_csl(%s)", csl_name)
        } else {
          sprintf("strings_to_csl(%s)", csl_name)
        }
        domain_arg <- if (length(param_names) > csl_param) {
          sprintf("%s.c_str()", param_names[length(param_names)])
        } else { '""' }
        body_lines <- c(body_lines, sprintf("    char** csl = %s;", csl_convert))
        body_lines <- c(body_lines, sprintf("    CPLErr err = GDALSetMetadata(h, csl, %s);", domain_arg))
      }
      body_lines <- c(body_lines, "    CSLDestroy(csl);")
    } else {
      body_lines <- c(body_lines, sprintf("    CPLErr err = %s;", gdal_call))
    }
    body_lines <- c(body_lines, "    if (err != CE_None) {")
    body_lines <- c(body_lines, sprintf('        stop("%s failed: %%s", CPLGetLastErrorMsg());', base_name))
    body_lines <- c(body_lines, "    }")
    body_lines <- c(body_lines, "    return static_cast<int>(err);")
  } else if (return_type == "SEXP") {
    # GDAL object return - need to wrap in external_pointer
    # Extract the handle type from the SWIG return type
    swig_ret <- method$return_type
    handle_type <- swig_to_handle_type(swig_ret)

    body_lines <- c(body_lines, sprintf("    %s result = %s;", handle_type, gdal_call))
    body_lines <- c(body_lines, "    if (!result) {")
    body_lines <- c(body_lines, "        return R_NilValue;")
    body_lines <- c(body_lines, "    }")
    body_lines <- c(body_lines, sprintf("    return external_pointer<%s>(new %s(result));",
                                        handle_type, handle_type))
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
      return(sprintf("GDALSetMetadata(h, CSLAddString(NULL, %s.c_str()), %s)",
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
    } else if (map_param_type(p) == "cpp11::list") {
      # Convert list to char** using helper
      args <- c(args, sprintf("list_to_csl(%s)", pname))
    } else if (map_param_type(p) == "cpp11::strings") {
      # Convert strings to char** using helper
      args <- c(args, sprintf("strings_to_csl(%s)", pname))
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
