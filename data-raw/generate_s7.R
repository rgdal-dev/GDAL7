# generate_s7.R
# Generate S7 class definitions from parsed SWIG class definitions

# ============================================================================
# Utilities
# ============================================================================

# Convert CamelCase to snake_case
to_snake_case <- function(name) {
  name <- gsub("([a-z])([A-Z])", "\\1_\\2", name)
  tolower(name)
}

# Map SWIG/C return types to R types for documentation
map_r_type <- function(swig_type) {
  swig_type <- trimws(swig_type)
  swig_type <- gsub("\\s*\\*", "*", swig_type)

  mapping <- list(
    "void" = "NULL",
    "int" = "integer",
    "double" = "numeric",
    "bool" = "logical",
    "const char*" = "character",
    "char const*" = "character",
    "char*" = "character",
    "const char" = "character",
    "char**" = "character",
    "CPLErr" = "integer",
    "OGRErr" = "integer"
  )

  if (swig_type %in% names(mapping)) {
    return(mapping[[swig_type]])
  }

  # GDAL objects
  if (grepl("Shadow\\*$|HS\\*$", swig_type)) {
    # Extract class name: GDALDatasetShadow* -> GDALDataset
    cls <- sub("Shadow\\*$", "", swig_type)
    cls <- sub("HS\\*$", "", cls)
    return(cls)
  }

  "ANY"
}

# How a parameter's value travels from R into the binding. The binding's cpp11
# type decides this, so it is read off the SWIG type the same way the C++ side
# reads it.
r_arg_kind <- function(param) {
  type <- gsub("\\s*\\*", "*", trimws(param$type))

  if (grepl("char\\*\\*", type)) {
    if (!is.na(param$typemap) && param$typemap == "dict") return("list")
    return("strings")
  }
  if (type %in% c("const char*", "char const*", "char*", "const char")) return("string")
  if (type == "int" || type %in% ENUM_PARAM_TYPES) return("integer")
  if (type == "double") return("double")
  if (type == "bool") return("logical")
  "other"
}

# The R default for a parameter, or NULL when there is none to render. SWIG
# spells an absent string list as 0 or NULL; in R that is NULL, and writing it
# as 0 would hand the binding a number where it wants strings.
r_default <- function(param) {
  kind <- r_arg_kind(param)
  if (kind %in% c("strings", "list")) return("NULL")
  if (is.null(param$default)) return(NULL)

  default <- trimws(param$default)
  if (identical(default, "")) return('""')
  if (grepl('^(-?[0-9.]+|TRUE|FALSE|NULL|".*")$', default)) return(default)
  NULL
}

# Render an S7 generic's formals from the parsed parameters. Giving the generic
# real formals (rather than just `x`) is what lets SWIG's defaults reach R, and
# what keeps the generated roxygen @param tags matching the \usage section.
generic_formals <- function(method) {
  args <- "x"
  for (p in method$params) {
    default <- r_default(p)
    args <- c(args, if (is.null(default)) p$name else sprintf("%s = %s", p$name, default))
  }
  paste(args, collapse = ", ")
}

# Render the new_generic() call. A method that takes nothing but the object
# keeps S7's own `...` formal, which is what the generated @param ... documents;
# spelling out `function(x) S7::S7_dispatch()` would drop it and leave the
# roxygen block describing an argument that is not in the usage.
new_generic_call <- function(name, method) {
  if (length(method$params) == 0) {
    sprintf('%s <- S7::new_generic("%s", "x")', name, name)
  } else {
    sprintf('%s <- S7::new_generic("%s", "x", function(%s) S7::S7_dispatch())',
            name, name, generic_formals(method))
  }
}

# The S7 class an immutable member's value belongs to.
s7_class_for <- function(swig_type) {
  switch(map_r_type(swig_type),
    integer = "S7::class_integer",
    numeric = "S7::class_double",
    logical = "S7::class_logical",
    character = "S7::class_character",
    "S7::class_any")
}

# Get cpp11 function name
get_cpp11_func <- function(class_name, method_name) {
  sprintf("GDAL7_%s_%s", tolower(class_name), to_snake_case(method_name))
}

# ============================================================================
# Properties
#
# A method that takes nothing but the object and gives back a value is not a
# verb; it is something the object knows about itself, so it is emitted as an
# S7 property rather than as a generic. Where GDAL has a matching Set method
# taking exactly that one value, the property is settable, and assigning to it
# calls that method. Reading always calls GDAL, so a property is never a stale
# copy taken when the object was made.
#
# Three kinds of getter are deliberately left as generics: one that gives back
# a GDAL object, because handing one over allocates and that should look like
# work rather than like reading a field; one whose C symbol is newer than the
# package floor, because reading a property must never raise and printing an
# object reads them all; and anything named in `not_properties`.
# ============================================================================

returns_gdal_object <- function(type) {
  grepl("Shadow ?\\*$|HS ?\\*$", type)
}

# to_snake_case runs acronyms together, which is what a binding name wants and
# not what someone typing a property name wants. Only these two come up.
PROPERTY_NAME_FIXES <- c(gcpcount = "gcp_count", gcpprojection = "gcp_projection")

property_name_for <- function(method_name) {
  name <- sub("^get_", "", to_snake_case(method_name))
  fixed <- PROPERTY_NAME_FIXES[name]
  if (is.na(fixed)) name else unname(fixed)
}

# The properties a class gets from its methods, each with the Set method that
# makes it settable where there is one.
class_properties <- function(methods, not_properties = character()) {
  names_of <- vapply(methods, function(m) m$name, character(1))

  specs <- list()
  for (method in methods) {
    if (!grepl("^Get[A-Z]", method$name)) next
    if (length(method$params) != 0) next
    if (grepl("_[0-9]+$", method$name)) next
    if (method$return_type == "void") next
    if (returns_gdal_object(method$return_type)) next
    if (method$name %in% not_properties) next

    setter <- NULL
    match <- which(names_of == sub("^Get", "Set", method$name))
    if (length(match) == 1 && length(methods[[match]]$params) == 1) {
      setter <- methods[[match]]
    }

    specs[[length(specs) + 1]] <- list(
      name = property_name_for(method$name),
      getter = method,
      setter = setter
    )
  }
  specs
}

# The method names a property has taken over, which the generics and methods
# below must then not emit a second time.
property_method_names <- function(specs) {
  unlist(lapply(specs, function(spec) {
    c(spec$getter$name, if (is.null(spec$setter)) NULL else spec$setter$name)
  }))
}

render_property <- function(class_name, spec) {
  lines <- c(
    sprintf('    %s = S7::new_property(', spec$name),
    sprintf('      %s,', s7_class_for(spec$getter$return_type)),
    sprintf('      getter = function(self) %s(self@.ptr)%s',
            get_cpp11_func(class_name, spec$getter$name),
            if (is.null(spec$setter)) '' else ',')
  )

  if (!is.null(spec$setter)) {
    param <- spec$setter$params[[1]]
    value <- switch(r_arg_kind(param),
      integer = "as.integer(value)",
      double = "as.double(value)",
      logical = "as.logical(value)",
      strings = "as.character(value)",
      list = "as.list(value)",
      "value")
    lines <- c(lines,
      '      setter = function(self, value) {',
      sprintf('        %s(self@.ptr, %s)',
              get_cpp11_func(class_name, spec$setter$name), value),
      '        self',
      '      }')
  }

  paste(c(lines, '    )'), collapse = "\n")
}

# A property the generator cannot derive, written down in orchestrate.R as a
# name, an S7 class and the helper functions that read and write it. The
# helpers live beside the rest of their subject in the hand-written R files, so
# the generated file carries no logic of its own.
render_hand_written_property <- function(spec) {
  lines <- c(
    sprintf('    %s = S7::new_property(', spec$name),
    sprintf('      %s,', spec$class),
    sprintf('      getter = function(self) %s(self)%s',
            spec$getter, if (is.null(spec$setter)) '' else ',')
  )

  if (!is.null(spec$setter)) {
    lines <- c(lines,
      '      setter = function(self, value) {',
      sprintf('        %s(self, value)', spec$setter),
      '        self',
      '      }')
  }

  paste(c(lines, '    )'), collapse = "\n")
}

# ============================================================================
# Code generation
# ============================================================================

# Generate file header
generate_s7_header <- function(class_name) {
  sprintf('# Auto-generated by GDAL7 generator - do not edit
# S7 class definition for %s

#\' @importFrom S7 new_class new_property new_generic method class_any class_character class_integer class_double class_logical
NULL

', class_name)
}

# Generate S7 class definition
generate_s7_class <- function(parsed_class, members = list(),
                              properties = list(), hand_written = list()) {
  class_name <- parsed_class$public_name
  class_lower <- tolower(class_name)

  # Parent class
  parent <- if (!is.na(parsed_class$parent)) {
    # Map Shadow name to public name
    parent_public <- sub("Shadow$", "", parsed_class$parent)
    parent_public <- sub("^GDAL", "", parent_public)
    sprintf("GDAL%s", parent_public)
  } else {
    "S7::class_any"
  }

  # Start class definition
  lines <- c()
  lines <- c(lines, sprintf('#\' GDAL %s class', class_name))
  lines <- c(lines, '#\'')
  lines <- c(lines, sprintf('#\' @description S7 class wrapping GDAL%s', class_name))
  lines <- c(lines, '#\' @param .ptr Internal. External pointer to the underlying GDAL object.')
  lines <- c(lines, '#\' @export')
  lines <- c(lines, sprintf('GDAL%s <- S7::new_class(', class_name))
  lines <- c(lines, sprintf('  "GDAL%s",', class_name))
  lines <- c(lines, '  package = "GDAL7",')

  # Handle parent
  if (parent != "S7::class_any") {
    lines <- c(lines, sprintf('  parent = %s,', parent))
  }

  # Every one of these objects is built from a GDAL handle and nothing else.
  # S7's default constructor takes one argument per settable property and
  # assigns every one of them at construction, which would call the setters
  # with an empty value, so the constructor is written out rather than left to
  # be inferred.
  lines <- c(lines, '')
  lines <- c(lines, '  constructor = function(.ptr) {')
  lines <- c(lines, sprintf('    S7::new_object(%s, .ptr = .ptr)',
                            if (parent == "S7::class_any") "S7::S7_object()"
                            else sprintf("%s(.ptr = .ptr)", parent)))
  lines <- c(lines, '  },')

  lines <- c(lines, '')
  lines <- c(lines, '  properties = list(')
  lines <- c(lines, '    # Internal pointer - not for direct user access')

  # GDAL declares its read-only attributes with %immutable, which is an S7
  # property with a getter and no setter. Reading one calls GDAL, so the value
  # is never a stale copy taken when the object was made.
  property_lines <- vapply(members, function(member) {
    sprintf('    %s = S7::new_property(\n      %s,\n      getter = function(self) %s(self@.ptr)\n    )',
            to_snake_case(member$name),
            s7_class_for(member$type),
            get_cpp11_func(class_name, member$name))
  }, character(1))

  # Properties taken from the class's own zero-argument getters, and any
  # written by hand in orchestrate.R for the parts the generator cannot see.
  named <- c(vapply(members, function(m) to_snake_case(m$name), character(1)),
             ".ptr")
  from_methods <- vapply(properties, function(spec) spec$name, character(1))
  keep <- !(from_methods %in% named)
  method_lines <- vapply(properties[keep], function(spec) {
    render_property(class_name, spec)
  }, character(1))

  written_lines <- vapply(hand_written, render_hand_written_property, character(1))

  lines <- c(lines, paste(
    c('    .ptr = S7::class_any', property_lines, method_lines, written_lines),
    collapse = ",\n"))
  lines <- c(lines, '  ),')
  lines <- c(lines, '')
  lines <- c(lines, '  validator = function(self) {')
  lines <- c(lines, '    if (is.null(self@.ptr)) {')
  lines <- c(lines, sprintf('      "GDAL%s pointer cannot be NULL"', class_name))
  lines <- c(lines, '    }')
  lines <- c(lines, '  }')
  lines <- c(lines, ')')
  lines <- c(lines, '')

  paste(lines, collapse = "\n")
}

# Generate S7 generics
generate_s7_generics <- function(parsed_class, methods, skip = character()) {
  class_name <- parsed_class$public_name
  methods <- Filter(function(m) !(m$name %in% skip), methods)

  lines <- c()
  lines <- c(lines, '# -----------------------------------------------------------------------------')
  lines <- c(lines, sprintf('# Generics for GDAL%s', class_name))
  lines <- c(lines, '# -----------------------------------------------------------------------------')
  lines <- c(lines, '')

  # Track generated generics to avoid duplicates
  generated <- character()

  for (method in methods) {
    generic_name <- to_snake_case(method$name)

    # Skip overloads (already generated the generic)
    base_generic <- sub("_[0-9]+$", "", generic_name)
    if (base_generic %in% generated) next
    generated <- c(generated, base_generic)

    r_return <- map_r_type(method$return_type)

    lines <- c(lines, sprintf('#\' %s', method$name))
    lines <- c(lines, '#\'')
    lines <- c(lines, sprintf('#\' @param x A GDAL%s object', class_name))
    # Only a generic with no extra parameters keeps S7's default `...` formal.
    if (length(method$params) == 0) {
      lines <- c(lines, '#\' @param ... Arguments passed on to methods.')
    }

    # Document other parameters
    for (p in method$params) {
      r_type <- map_r_type(p$type)
      default <- r_default(p)
      default_str <- if (is.null(default)) '' else sprintf(' (default: %s)', default)
      lines <- c(lines, sprintf('#\' @param %s %s%s', p$name, r_type, default_str))
    }

    lines <- c(lines, sprintf('#\' @return %s', r_return))
    lines <- c(lines, '#\' @export')
    lines <- c(lines, new_generic_call(base_generic, method))
    lines <- c(lines, '')
  }

  paste(lines, collapse = "\n")
}

# Generate S7 methods
generate_s7_methods <- function(parsed_class, methods, skip = character()) {
  class_name <- parsed_class$public_name
  class_lower <- tolower(class_name)
  methods <- Filter(function(m) !(m$name %in% skip), methods)

  lines <- c()
  lines <- c(lines, '# -----------------------------------------------------------------------------')
  lines <- c(lines, sprintf('# Methods for GDAL%s', class_name))
  lines <- c(lines, '# -----------------------------------------------------------------------------')
  lines <- c(lines, '')

  for (method in methods) {
    base_name <- sub("_[0-9]+$", "", method$name)
    is_overload <- grepl("_[0-9]+$", method$name)
    overload <- if (is_overload) as.integer(sub("^.*_([0-9]+)$", "\\1", method$name)) else 1L

    # The cpp11 generator has already numbered the overloads, and its list is
    # what this reads, so the binding name always matches the one it emitted.
    cpp_func <- get_cpp11_func(class_name, method$name)
    r_func_name <- to_snake_case(method$name)

    # Build R parameter list (excluding 'x' which is the object). S7 requires a
    # method's formals to match its generic's exactly when the generic has no
    # `...`, defaults included, so both come from generic_formals().
    r_params <- c("x")
    call_args <- c("x@.ptr")

    for (p in method$params) {
      param_name <- p$name
      r_params <- c(r_params, param_name)

      # Coerce to what the binding's cpp11 type accepts. NULL for an absent
      # string list becomes character(0), which is an empty option list.
      call_args <- c(call_args, switch(r_arg_kind(p),
        integer = sprintf("as.integer(%s)", param_name),
        double = sprintf("as.double(%s)", param_name),
        logical = sprintf("as.logical(%s)", param_name),
        strings = sprintf("as.character(%s)", param_name),
        list = sprintf("as.list(%s)", param_name),
        param_name))
    }

    r_params_str <- generic_formals(method)
    call_args_str <- paste(call_args, collapse = ", ")
    r_return_doc <- map_r_type(method$return_type)

    # For overloads after the first, also create the generic
    if (is_overload) {
      lines <- c(lines, sprintf('#\' %s (overload %d)', base_name, overload))
      lines <- c(lines, '#\'')
      lines <- c(lines, sprintf('#\' @param x A GDAL%s object', class_name))
      if (length(method$params) == 0) {
        lines <- c(lines, '#\' @param ... Arguments passed on to methods.')
      }
      for (p in method$params) {
        lines <- c(lines, sprintf('#\' @param %s %s', p$name, map_r_type(p$type)))
      }
      lines <- c(lines, sprintf('#\' @return %s', r_return_doc))
      lines <- c(lines, '#\' @export')
      lines <- c(lines, new_generic_call(r_func_name, method))
      lines <- c(lines, '')
    }

    # Generate method
    lines <- c(lines, sprintf('S7::method(%s, GDAL%s) <- function(%s) {',
                              r_func_name,
                              class_name,
                              r_params_str))

    # Handle return type
    # Call the R wrapper function from cpp11.R (not .Call directly)
    r_return <- map_r_type(method$return_type)

    if (method$return_type == "void") {
      lines <- c(lines, sprintf('  %s(%s)', cpp_func, call_args_str))
      lines <- c(lines, '  invisible(x)')
    } else if (grepl("Shadow\\*$|HS\\*$", method$return_type)) {
      # Returns a GDAL object - wrap in S7 class
      return_class <- map_r_type(method$return_type)
      lines <- c(lines, sprintf('  ptr <- %s(%s)', cpp_func, call_args_str))
      lines <- c(lines, sprintf('  if (is.null(ptr)) return(NULL)'))
      lines <- c(lines, sprintf('  %s(.ptr = ptr)', return_class))
    } else {
      lines <- c(lines, sprintf('  %s(%s)', cpp_func, call_args_str))
    }

    lines <- c(lines, '}')
    lines <- c(lines, '')
  }

  paste(lines, collapse = "\n")
}

# Generate print method
generate_s7_print <- function(parsed_class) {
  class_name <- parsed_class$public_name

  sprintf('
#\' @export
S7::method(print, GDAL%s) <- function(x, ...) {
  cat("<GDAL%s>\\n")
  desc <- x@description
  if (nzchar(desc)) {
    cat("  Description:", desc, "\\n")
  }
  invisible(x)
}
', class_name, class_name)
}

# Generate complete S7 file for a class
generate_s7_file <- function(parsed_class, output_path = NULL,
                             methods = parsed_class$methods, members = list(),
                             not_properties = character(),
                             hand_written_properties = list()) {
  properties <- class_properties(methods, not_properties)
  consumed <- property_method_names(properties)

  code <- paste(
    generate_s7_header(parsed_class$public_name),
    generate_s7_class(parsed_class, members, properties, hand_written_properties),
    generate_s7_generics(parsed_class, methods, skip = consumed),
    generate_s7_methods(parsed_class, methods, skip = consumed),
    generate_s7_print(parsed_class),
    sep = "\n"
  )

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

  code <- generate_s7_file(cls)
  cat(code)
}
