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

  # An enum reaches R as the integer it is.
  if (swig_type %in% ENUM_PARAM_TYPES) {
    return("int")
  }

  # GDAL object pointers -> SEXP (external pointer)
  if (grepl("Shadow\\*$|HS\\*$|ShadowH\\*$", swig_type)) {
    return("SEXP")
  }

  # Default: pass through (might need manual fix)
  swig_type
}

# Enum parameters. GDAL's C API takes these as their own enum type, so the
# binding takes an int from R and casts at the call.
ENUM_PARAM_TYPES <- c(
  "GDALAccess", "GDALColorInterp", "GDALDataType", "GDALPaletteInterp",
  "GDALRATFieldType", "GDALRATFieldUsage", "GDALRATTableType",
  "GDALRIOResampleAlg", "GDALRWFlag"
)

# Map a parameter to its cpp11 type, or NA when the generator cannot express
# it. NA is not a failure to be worked around; it is the honest answer, and it
# is what keeps an unrepresentable method out of the build.
map_param_type <- function(param) {
  swig_type <- trimws(param$type)
  swig_type <- gsub("\\s*\\*", "*", swig_type)

  # An array parameter arrives with its extent stuck to the name, as in
  # "double argout[6]". There is no cpp11 spelling for that.
  if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", param$name)) {
    return(NA_character_)
  }

  if (swig_type %in% c("const char*", "char const*", "char*", "const char")) {
    return("std::string")
  }

  if (grepl("char\\s*\\*\\*", swig_type)) {
    if (!is.na(param$typemap) && param$typemap == "dict") {
      return("cpp11::list")  # Named list for KEY=VALUE
    }
    return("cpp11::strings")  # Default string vector
  }

  if (swig_type == "int") return("int")
  if (swig_type == "double") return("double")
  if (swig_type == "bool") return("bool")
  if (swig_type %in% ENUM_PARAM_TYPES) return("int")

  NA_character_
}

# How the parameter reaches the derived C call.
param_arg_expr <- function(param) {
  cpp_type <- map_param_type(param)
  swig_type <- gsub("\\s*\\*", "*", trimws(param$type))

  if (identical(cpp_type, "std::string")) {
    return(sprintf("%s.c_str()", param$name))
  }
  if (cpp_type %in% c("cpp11::list", "cpp11::strings")) {
    # The CPLStringList temporary lives until the call returns and then frees
    # itself, which the CSLAddString loops this replaces did not.
    return(sprintf("gdal7::to_csl(%s).List()", param$name))
  }
  if (swig_type %in% ENUM_PARAM_TYPES) {
    return(sprintf("static_cast<%s>(%s)", swig_type, param$name))
  }
  param$name
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

  # Generate the GDAL C API call. The one hand-mapped method has no derived
  # call; its branch below writes the call out itself.
  gdal_call <- if (is.null(method$c_call)) {
    NA_character_
  } else {
    generate_gdal_call(method, class_name, param_names)
  }

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

# The single-string overload of SetMetadata builds a two-element array on the
# stack instead of calling one C function, so there is no call in its body to
# derive. It is the one method the generator maps by hand, and the mapping is
# here rather than in a lookup table so that it stays visible.
is_single_string_set_metadata <- function(method) {
  base_name <- sub("_[0-9]+$", "", method$name)
  base_name == "SetMetadata" &&
    length(method$params) >= 1 &&
    grepl("char", method$params[[1]]$type) &&
    !grepl("\\*\\*", method$params[[1]]$type)
}

# Literals a derived call may pass that are not parameters.
C_LITERALS <- c("NULL", "nullptr", "0", "1", "true", "false", "TRUE", "FALSE")

is_c_literal <- function(arg) {
  arg %in% C_LITERALS ||
    grepl("^-?[0-9]+(\\.[0-9]+)?$", arg) ||
    grepl('^".*"$', arg)
}

# Generate the GDAL C API call for a method, from the call derived out of its
# %extend body. SWIG's body is the mapping; nothing here guesses at it.
generate_gdal_call <- function(method, class_name, param_names) {
  call <- method$c_call
  if (is.null(call)) {
    stop(sprintf("No C call derived for %s::%s", class_name, method$name))
  }

  args <- vapply(call$args, function(arg) {
    if (arg == "self") return("h")
    index <- match(arg, param_names)
    if (!is.na(index)) return(param_arg_expr(method$params[[index]]))
    if (arg == "NULL") return("nullptr")
    arg
  }, character(1))

  sprintf("%s(%s)", call$func, paste(args, collapse = ", "))
}

# Can this method be generated, and if not, why not? The reasons are recorded
# in the generated file, so the skip list is something you read rather than
# something you maintain.
method_support <- function(method, class_name, symbol_versions) {
  unsupported <- function(reason) list(ok = FALSE, reason = reason)

  if (is_single_string_set_metadata(method)) {
    return(list(ok = TRUE, since = NA_character_))
  }

  call <- method$c_call
  if (is.null(call)) {
    return(unsupported("its SWIG body is not a single C call"))
  }
  if (length(call$args) == 0 || call$args[1] != "self") {
    return(unsupported(sprintf("%s does not take the object first", call$func)))
  }

  param_names <- vapply(method$params, function(p) p$name, character(1))
  for (arg in call$args[-1]) {
    if (arg %in% param_names || is_c_literal(arg)) next
    return(unsupported(sprintf("%s is passed %s, which is not a parameter",
                               call$func, arg)))
  }

  for (param in method$params) {
    if (is.na(map_param_type(param))) {
      return(unsupported(sprintf("parameter %s is %s", param$name, param$type)))
    }
  }

  return_type <- map_return_type(method$return_type)
  if (return_type == "SEXP") {
    handle_type <- swig_to_handle_type(method$return_type)
    if (is.null(handle_to_kind(handle_type))) {
      return(unsupported(sprintf("GDAL7 has no class for %s", handle_type)))
    }
  } else if (!return_type %in% c("void", "int", "double", "bool", "cpp11::strings")) {
    return(unsupported(sprintf("it returns %s", method$return_type)))
  }

  since <- symbol_versions[[call$func]]
  if (is.null(since)) {
    return(unsupported(sprintf("%s is in no GDAL release the symbol table covers",
                               call$func)))
  }

  list(ok = TRUE, since = since)
}

# The version a guard is measured against. A symbol recorded as first appearing
# in the oldest release the table covers has been there all along as far as the
# table knows, so it needs no guard; anything newer gets one.
guard_baseline <- function(symbol_versions) {
  versions <- unique(stats::na.omit(unname(symbol_versions)))
  as.character(min(package_version(versions)))
}

# "3.12.0" -> "GDAL_COMPUTE_VERSION(3, 12, 0)"
compute_version_macro <- function(version) {
  parts <- as.integer(strsplit(version, ".", fixed = TRUE)[[1]])
  parts <- c(parts, rep(0L, 3 - length(parts)))[1:3]
  sprintf("GDAL_COMPUTE_VERSION(%d, %d, %d)", parts[1], parts[2], parts[3])
}

# Wrap a binding body so that it compiles against a GDAL that predates the C
# function it calls, and says so at run time instead of failing to link.
apply_version_guard <- function(body, since, r_name, arg_names) {
  unused <- if (length(arg_names) == 0) "" else
    paste(sprintf("    (void)%s;", arg_names), collapse = "\n")
  paste(
    sprintf("#if GDAL_VERSION_NUM >= %s", compute_version_macro(since)),
    body,
    "#else",
    if (unused == "") NULL else unused,
    sprintf('    gdal7::unavailable("%s", "%s");', r_name, since),
    "#endif",
    sep = "\n"
  )
}

# Generate the binding for an immutable member, which SWIG implements as a
# <Shadow>_<Member>_get function whose body is the C call.
generate_member <- function(member, class_name) {
  class_lower <- tolower(class_name)
  handle_type <- get_handle_type(class_name)
  return_type <- map_return_type(member$type)

  call <- member$c_call
  args <- vapply(call$args, function(arg) if (arg %in% c("self", "h")) "h" else arg,
                 character(1))
  gdal_call <- sprintf("%s(%s)", call$func, paste(args, collapse = ", "))

  body <- sprintf("    %s h = get_%s_handle(xp);", handle_type, class_lower)
  body <- if (return_type == "cpp11::strings") {
    paste(body, sprintf("    return gdal7::chr(%s);", gdal_call), sep = "\n")
  } else {
    paste(body, sprintf("    return %s;", gdal_call), sep = "\n")
  }

  sprintf('
[[cpp11::register]]
%s GDAL7_%s_%s(SEXP xp) {
%s
}
', return_type, class_lower, to_snake_case(member$name), body)
}

# Can this member be generated?
member_support <- function(member, symbol_versions) {
  call <- member$c_call
  if (is.null(call)) {
    return(list(ok = FALSE, reason = "SWIG implements it without a single C call"))
  }
  if (length(call$args) != 1 || !call$args[1] %in% c("self", "h")) {
    return(list(ok = FALSE, reason = sprintf("%s takes more than the object", call$func)))
  }
  if (!map_return_type(member$type) %in% c("int", "double", "bool", "cpp11::strings")) {
    return(list(ok = FALSE, reason = sprintf("it is %s", member$type)))
  }
  since <- symbol_versions[[call$func]]
  if (is.null(since)) {
    return(list(ok = FALSE, reason = sprintf("%s is in no release the symbol table covers",
                                             call$func)))
  }
  list(ok = TRUE, since = since)
}

# Generate all bindings for a class.
#
# There is no skip list. A method is generated when the generator can express
# it and left out when it cannot, and every omission is written into the file
# with the reason, so what GDAL7 does not yet reach is readable from the
# generated source rather than kept in a list beside it.
generate_class_bindings <- function(parsed_class, symbol_versions,
                                    hand_written = character()) {
  class_name <- parsed_class$public_name
  baseline <- guard_baseline(symbol_versions)

  output <- generate_header(class_name)
  skipped <- list()
  capabilities <- list()
  generated_methods <- list()
  generated_members <- list()

  guard_since <- function(since) {
    if (is.na(since)) return(NA_character_)
    if (package_version(since) <= package_version(baseline)) NA_character_ else since
  }

  for (member in parsed_class$members) {
    support <- member_support(member, symbol_versions)
    if (!support$ok) {
      skipped[[length(skipped) + 1]] <- list(name = member$name, reason = support$reason)
      next
    }
    code <- generate_member(member, class_name)
    since <- guard_since(support$since)
    if (!is.na(since)) {
      r_name <- to_snake_case(member$name)
      body <- sub("(?s)^.*?\\{\\n(.*)\\n\\}\\n$", "\\1", code, perl = TRUE)
      code <- sub(body, apply_version_guard(body, since, r_name, "xp"), code, fixed = TRUE)
      capabilities[[length(capabilities) + 1]] <-
        list(name = sprintf("%s_%s", tolower(class_name), r_name), since = since)
    }
    generated_members[[length(generated_members) + 1]] <- member
    output <- paste0(output, code)
  }

  # Track method names to handle overloads
  method_counts <- list()

  for (method in parsed_class$methods) {
    base_name <- sub("_[0-9]+$", "", method$name)

    if (base_name %in% hand_written) {
      next
    }

    support <- method_support(method, class_name, symbol_versions)
    if (!support$ok) {
      skipped[[length(skipped) + 1]] <- list(name = base_name, reason = support$reason)
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

    code <- generate_method(method, class_name)
    since <- guard_since(support$since)
    if (!is.na(since)) {
      r_name <- to_snake_case(method$name)
      arg_names <- c("xp", vapply(method$params, function(p) p$name, character(1)))
      body <- sub("(?s)^.*?\\{\\n(.*)\\n\\}\\n$", "\\1", code, perl = TRUE)
      code <- sub(body, apply_version_guard(body, since, r_name, arg_names), code, fixed = TRUE)
      capabilities[[length(capabilities) + 1]] <-
        list(name = sprintf("%s_%s", tolower(class_name), r_name), since = since)
    }
    generated_methods[[length(generated_methods) + 1]] <- method
    output <- paste0(output, code)
  }

  # The S7 generator works from what was actually generated here, so the two
  # sides cannot disagree about which methods exist.
  list(code = paste0(output, format_skipped(skipped, class_name)),
       capabilities = capabilities,
       methods = generated_methods,
       members = generated_members,
       skipped = skipped)
}

# Record what was left out, and why, at the foot of the generated file.
format_skipped <- function(skipped, class_name) {
  if (length(skipped) == 0) {
    return(sprintf("\n// Every %s method GDAL declares is bound above.\n", class_name))
  }

  names <- vapply(skipped, function(x) x$name, character(1))
  reasons <- vapply(skipped, function(x) x$reason, character(1))
  keep <- !duplicated(names)
  lines <- sprintf("//   %-24s %s", names[keep], reasons[keep])

  paste0(
    sprintf("\n// Not generated (%d of GDAL's %s methods), with the reason the\n",
            sum(keep), class_name),
    "// generator gave. Each is a thing the generator cannot yet express, not a\n",
    "// thing GDAL7 has decided against.\n",
    paste(lines, collapse = "\n"), "\n"
  )
}

# ============================================================================
# Main entry point
# ============================================================================

generate_cpp11_file <- function(parsed_class, output_path = NULL,
                                symbol_versions = read_symbol_versions(),
                                hand_written = character()) {
  result <- generate_class_bindings(parsed_class, symbol_versions, hand_written)

  if (!is.null(output_path)) {
    writeLines(result$code, output_path)
    message(sprintf("Generated %s", output_path))
  }

  invisible(result)
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
