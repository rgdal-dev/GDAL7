# parse_swig.R
# Minimal SWIG .i file parser for GDAL7 generator
# Proof of concept using MajorObject.i

# Null coalesce operator
`%||%` <- function(x, y) if (is.null(x) || (length(x) == 1 && is.na(x))) y else x

# ============================================================================
# Data structures
# ============================================================================

new_class_def <- function() {
  list(
    public_name = NA_character_,
    internal_name = NA_character_,
    parent = NA_character_,
    properties = list(),
    methods = list()
  )
}

new_method_def <- function() {
  list(
    name = NA_character_,
    return_type = NA_character_,
    params = list(),
    body = NA_character_,
    newobject = FALSE,
    apply_context = list()  # Active %apply directives
  )
}

new_param_def <- function() {
  list(
    name = NA_character_,
    type = NA_character_,
    default = NULL,
    nonnull = FALSE,
    output = FALSE,
    typemap = NA_character_  # e.g., "CSL", "dict", "options"
  )
}

# ============================================================================
# Utility functions
# ============================================================================

# Count net braces in a line (handles strings naively for now)
count_braces <- function(line) {
  # Remove string literals (simple approach)
  line <- gsub('"[^"]*"', '', line)
  line <- gsub("'[^']*'", '', line)
  sum(strsplit(line, "")[[1]] == "{") - sum(strsplit(line, "")[[1]] == "}")
}

# Remove C-style comments from a line
strip_comments <- function(line) {
  # Remove // comments
  line <- sub("//.*$", "", line)
  # Remove /* */ on same line (simplified)
  line <- gsub("/\\*.*?\\*/", "", line)
  trimws(line)
}

# Check if line looks like start of a method definition
is_method_start <- function(line) {
  line <- trimws(line)
  if (line == "") return(FALSE)
  if (grepl("^[#%]", line)) return(FALSE)
  if (grepl("^(class|struct|typedef|private|public|protected)", line)) return(FALSE)
  if (grepl("^~", line)) return(FALSE)  # Destructor
  if (grepl("^return\\s", line)) return(FALSE)  # Return statement
  if (grepl(";\\s*$", line)) return(FALSE)  # Ends with semicolon = statement

  # Exclude C control flow statements
  if (grepl("^(if|else|while|for|switch|do)\\s*\\(", line)) return(FALSE)

  # Must have a ( for function call/definition
  if (!grepl("\\(", line)) return(FALSE)

  # Simple heuristic: line should start with a type keyword
  # Type keywords: void, int, char, bool, const, unsigned, signed,
  #               or a capitalized identifier (class name like GDALDatasetShadow)
  # Then eventually an identifier followed by (

  # Check for typical return type patterns at start
  type_start <- grepl("^(void|int|char|bool|const|unsigned|signed|float|double|long|short|size_t|CPLErr|OGRErr|GIntBig|GByte|[A-Z]\\w*)", line)
  if (!type_start) return(FALSE)

  # Check there's a name before the (
  # Pattern: stuff followed by identifier followed by (
  # Use a simpler non-catastrophic pattern
  if (!grepl("\\w+\\s*\\(", line)) return(FALSE)

  TRUE
}

# ============================================================================
# Parse individual constructs
# ============================================================================

# Parse: %rename (PublicName) InternalName;
parse_rename <- function(line) {
  m <- regmatches(line, regexec("%rename\\s*\\(\\s*(\\w+)\\s*\\)\\s*(\\w+)", line))[[1]]
  if (length(m) == 3) {
    list(public = m[2], internal = m[3])
  } else {
    NULL
  }
}

# Parse: %constant NAME = VALUE;
parse_constant <- function(line) {
  m <- regmatches(line, regexec("%constant\\s+(\\w+)\\s*=\\s*(\\w+)", line))[[1]]
  if (length(m) == 3) {
    list(name = m[2], value = m[3])
  } else {
    NULL
  }
}

# Parse: class ClassName : public ParentClass {
parse_class_header <- function(line) {
  cls <- new_class_def()

  # With parent
  m <- regmatches(line, regexec("class\\s+(\\w+)\\s*:\\s*public\\s+(\\w+)", line))[[1]]
  if (length(m) == 3) {
    cls$internal_name <- m[2]
    cls$parent <- m[3]
    return(cls)
  }

  # Without parent
  m <- regmatches(line, regexec("class\\s+(\\w+)", line))[[1]]
  if (length(m) == 2) {
    cls$internal_name <- m[2]
    return(cls)
  }

  NULL
}

# Parse: %apply (typemap) {pattern};
parse_apply <- function(line) {
  # %apply (char **CSL) {(char **)};
  # %apply Pointer NONNULL {const char * pszNewDesc};
  # %apply (int *OUTPUT){int *pnBlockXSize, int *pnBlockYSize}

  # Try pattern with parens: %apply (typemap) {targets}
  m <- regmatches(line, regexec("%apply\\s*\\(([^)]+)\\)\\s*\\{([^}]+)\\}", line))[[1]]
  if (length(m) == 3) {
    typemap <- trimws(m[2])
    targets <- trimws(m[3])
    # Split targets by comma
    target_list <- trimws(strsplit(targets, ",")[[1]])
    return(list(typemap = typemap, targets = target_list))
  }

  # Try pattern without parens: %apply Pointer NONNULL {targets}
  m <- regmatches(line, regexec("%apply\\s+([^{]+)\\{([^}]+)\\}", line))[[1]]
  if (length(m) == 3) {
    typemap <- trimws(m[2])
    targets <- trimws(m[3])
    target_list <- trimws(strsplit(targets, ",")[[1]])
    return(list(typemap = typemap, targets = target_list))
  }

  NULL
}

# Parse: %clear pattern;
parse_clear <- function(line) {
  m <- regmatches(line, regexec("%clear\\s+([^;]+)", line))[[1]]
  if (length(m) == 2) {
    trimws(m[2])
  } else {
    NULL
  }
}

# Parse a method signature and body
# Input: vector of lines starting from method, returns list(method, lines_consumed)
parse_method <- function(lines, apply_context) {
  method <- new_method_def()

  # Accumulate lines until we have complete signature (ends with {)
  sig_lines <- c()
  i <- 1
  brace_count <- 0

  # First, get the signature (up to and including first {)
  while (i <= length(lines)) {
    line <- lines[i]
    sig_lines <- c(sig_lines, line)
    brace_count <- brace_count + count_braces(line)
    if (brace_count > 0) break  # Found opening brace
    i <- i + 1
  }

  signature <- paste(sig_lines, collapse = " ")
  signature <- gsub("\\s+", " ", signature)  # Normalize whitespace

  # Now get the body (until braces balance)
  body_lines <- c()
  while (i <= length(lines) && brace_count > 0) {
    i <- i + 1
    if (i > length(lines)) break
    line <- lines[i]
    brace_count <- brace_count + count_braces(line)
    body_lines <- c(body_lines, line)
  }

  method$body <- paste(trimws(body_lines), collapse = "\n")

  # Parse signature: return_type name(params) {
  # Remove the trailing {
  sig_clean <- sub("\\{\\s*$", "", signature)
  sig_clean <- trimws(sig_clean)

  # Extract parts: return_type might include *, name might have * prefix
  # Pattern: everything before last identifier followed by (
  # Strategy: find the ( position, work backwards to find name

  # Split at the opening (
  paren_pos <- regexpr("\\(", sig_clean)
  if (paren_pos > 0) {
    before_paren <- trimws(substr(sig_clean, 1, paren_pos - 1))
    params_and_close <- substr(sig_clean, paren_pos + 1, nchar(sig_clean))
    # Remove trailing )
    params_str <- sub("\\)\\s*$", "", params_and_close)
    params_str <- trimws(params_str)

    # Now parse "return_type name" from before_paren
    # The name is the last word (identifier)
    # Return type is everything before the name

    # Find last word by splitting on non-identifier chars
    parts <- strsplit(before_paren, "[^a-zA-Z0-9_]+")[[1]]
    parts <- parts[parts != ""]

    if (length(parts) > 0) {
      method$name <- tail(parts, 1)

      # Return type is everything before the name
      name_pos <- regexpr(paste0(method$name, "$"), before_paren)
      if (name_pos > 1) {
        method$return_type <- trimws(substr(before_paren, 1, name_pos - 1))
      } else {
        method$return_type <- "void"  # fallback
      }
    }

    # Parse parameters
    if (params_str != "") {
      method$params <- parse_params(params_str, apply_context)
    }
  }

  method$apply_context <- apply_context

  list(method = method, lines_consumed = i)
}

# Parse parameter list string into param definitions
parse_params <- function(params_str, apply_context) {
  # Split by comma, but respect nested parens (for things like function pointers)
  # Simple approach: split by comma, handle common cases

  params <- list()

  # Split carefully - commas not inside parens
  param_strs <- split_params(params_str)

  for (ps in param_strs) {
    ps <- trimws(ps)
    if (ps == "") next

    param <- new_param_def()

    # Check for default value
    if (grepl("=", ps)) {
      parts <- strsplit(ps, "=")[[1]]
      ps <- trimws(parts[1])
      param$default <- trimws(parts[2])
      # Clean up default - remove quotes if string
      param$default <- gsub('^""|""$', '', param$default)
    }

    # Parse type and name
    # Common patterns:
    #   const char *pszName
    #   int nBand
    #   char ** papszMetadata
    #   GDALDataType eBufType

    # The name is the last word, everything else is type
    tokens <- strsplit(ps, "\\s+")[[1]]
    tokens <- tokens[tokens != ""]  # Remove empty

    if (length(tokens) >= 2) {
      param$name <- tail(tokens, 1)
      # Handle pointer attached to name: *pszName -> pszName, type gets *
      if (grepl("^\\*+", param$name)) {
        stars <- regmatches(param$name, regexec("^(\\*+)", param$name))[[1]][2]
        param$name <- sub("^\\*+", "", param$name)
        tokens[length(tokens)] <- stars
      }
      param$type <- paste(tokens[-length(tokens)], collapse = " ")
      # Clean up type
      param$type <- gsub("\\s+", " ", param$type)
      param$type <- sub("\\s*\\*\\s*$", "*", param$type)  # Normalize trailing *
    } else if (length(tokens) == 1) {
      # Just a type with no name? Or name with no type?
      param$name <- tokens[1]
      param$type <- "unknown"
    }

    # Apply typemap context
    for (apply in apply_context) {
      for (target in apply$targets) {
        # Check if this param matches the target pattern
        # Target might be: "const char * pszNewDesc" or "(char **)" or "int *pnBlockXSize"
        target_clean <- gsub("[()]", "", target)
        target_clean <- trimws(target_clean)

        # Match by name if present in target
        if (grepl(paste0("\\b", param$name, "\\b"), target_clean)) {
          param <- apply_typemap(param, apply$typemap)
        }
        # Match by type pattern
        else if (types_match(param$type, target_clean)) {
          param <- apply_typemap(param, apply$typemap)
        }
      }
    }

    params <- c(params, list(param))
  }

  params
}

# Split parameter string by commas, respecting parens
split_params <- function(s) {
  result <- c()
  current <- ""
  depth <- 0

  for (ch in strsplit(s, "")[[1]]) {
    if (ch == "(") depth <- depth + 1
    if (ch == ")") depth <- depth - 1
    if (ch == "," && depth == 0) {
      result <- c(result, current)
      current <- ""
    } else {
      current <- paste0(current, ch)
    }
  }
  result <- c(result, current)
  result
}

# Apply a typemap annotation to a parameter
apply_typemap <- function(param, typemap) {
  typemap_lower <- tolower(typemap)

  if (grepl("nonnull", typemap_lower)) {
    param$nonnull <- TRUE
  }
  if (grepl("output", typemap_lower)) {
    param$output <- TRUE
  }
  if (grepl("csl", typemap_lower)) {
    param$typemap <- "CSL"
  } else if (grepl("dict", typemap_lower)) {
    param$typemap <- "dict"
  } else if (grepl("options", typemap_lower)) {
    param$typemap <- "options"
  }

  param
}

# Check if two type strings match (loosely)
types_match <- function(type1, type2) {
  # Normalize and compare
  normalize <- function(t) {
    t <- gsub("\\s+", " ", t)
    t <- gsub("\\s*\\*", "*", t)
    t <- trimws(t)
    t
  }
  normalize(type1) == normalize(type2)
}

# ============================================================================
# Main parser
# ============================================================================

parse_swig_file <- function(filepath, debug = FALSE) {
  lines <- readLines(filepath, warn = FALSE)

  # Result structure
  result <- list(
    renames = list(),
    constants = list(),
    classes = list()
  )

  # Parser state
  state <- "TOP_LEVEL"
  current_class <- NULL
  apply_context <- list()
  brace_depth <- 0
  skip_depth <- 0
  i <- 1

  dbg <- function(...) if (debug) cat(sprintf(...))

  while (i <= length(lines)) {
    raw_line <- lines[i]
    line <- strip_comments(raw_line)

    # Skip empty lines
    if (line == "") {
      i <- i + 1
      next
    }

    dbg("L%03d [%-15s] bd=%d: %s\n", i, state, brace_depth, substr(line, 1, 50))

    # State machine
    if (state == "TOP_LEVEL") {

      # Check for %{ raw block - skip entire block
      if (grepl("^%\\{", line)) {
        state <- "RAW_BLOCK"
        i <- i + 1
        next
      }

      # Check for language-specific ifdef blocks - skip these
      # We want to skip: #ifdef SWIGPYTHON, #if defined(SWIGJAVA), etc.
      # But NOT: #ifndef FROM_PYTHON_OGR_I (those are include guards)
      if (grepl("^#if.*SWIG(PYTHON|JAVA|CSHARP|PERL)", line) ||
          grepl("^#ifdef\\s+SWIG", line)) {
        state <- "SKIP_IFDEF"
        skip_depth <- 1
        i <- i + 1
        next
      }

      # Skip #if defined(SWIGXXX) blocks
      if (grepl("^#if\\s+defined\\s*\\(\\s*SWIG", line)) {
        state <- "SKIP_IFDEF"
        skip_depth <- 1
        i <- i + 1
        next
      }

      # For other preprocessor directives, just skip the line itself
      if (grepl("^#", line)) {
        i <- i + 1
        next
      }

      # %rename directive
      if (grepl("^%rename", line)) {
        rename <- parse_rename(line)
        if (!is.null(rename)) {
          result$renames[[rename$internal]] <- rename$public
        }
        i <- i + 1
        next
      }

      # %constant directive
      if (grepl("^%constant", line)) {
        const <- parse_constant(line)
        if (!is.null(const)) {
          result$constants <- c(result$constants, list(const))
        }
        i <- i + 1
        next
      }

      # Class definition
      if (grepl("^class\\s+\\w+", line)) {
        current_class <- parse_class_header(line)
        if (!is.null(current_class)) {
          # Look up public name from renames
          if (current_class$internal_name %in% names(result$renames)) {
            current_class$public_name <- result$renames[[current_class$internal_name]]
          } else {
            current_class$public_name <- current_class$internal_name
          }
          state <- "IN_CLASS"
          brace_depth <- count_braces(line)
          apply_context <- list()  # Reset apply context for new class
          dbg("  -> Found class %s, entering IN_CLASS, bd=%d\n", current_class$internal_name, brace_depth)
        }
        i <- i + 1
        next
      }

      i <- i + 1

    } else if (state == "RAW_BLOCK") {

      # Skip until we see %}
      if (grepl("%\\}", line)) {
        state <- "TOP_LEVEL"
      }
      i <- i + 1

    } else if (state == "SKIP_IFDEF") {

      if (grepl("^#if", line)) {
        skip_depth <- skip_depth + 1
      }
      if (grepl("^#endif", line)) {
        skip_depth <- skip_depth - 1
        if (skip_depth == 0) {
          state <- "TOP_LEVEL"
        }
      }
      # Handle #else/#elif - for SWIG blocks, just continue skipping
      i <- i + 1

    } else if (state == "IN_CLASS") {

      brace_depth <- brace_depth + count_braces(line)

      # Enter %extend block
      if (grepl("^%extend", line)) {
        state <- "IN_EXTEND"
        i <- i + 1
        next
      }

      # End of class
      if (brace_depth == 0 && grepl("};", line)) {
        result$classes[[current_class$internal_name]] <- current_class
        current_class <- NULL
        state <- "TOP_LEVEL"
        apply_context <- list()
      }

      i <- i + 1

    } else if (state == "IN_EXTEND") {

      # Check for method definition FIRST, before counting braces
      # (parse_method handles its own brace counting internally)
      if (is_method_start(line)) {
        dbg("  -> Found method start: %s\n", substr(line, 1, 40))
        remaining <- lines[i:length(lines)]
        parsed <- parse_method(remaining, apply_context)

        dbg("  -> Parsed method: %s, consumed %d lines\n",
            parsed$method$name %||% "NULL", parsed$lines_consumed)

        if (!is.null(parsed$method$name) && !is.na(parsed$method$name)) {
          current_class$methods <- c(current_class$methods, list(parsed$method))
        }

        i <- i + parsed$lines_consumed
        next
      }

      # Now count braces for non-method lines
      line_braces <- count_braces(line)
      brace_depth <- brace_depth + line_braces

      # Handle %apply
      if (grepl("^%apply", line)) {
        apply <- parse_apply(line)
        if (!is.null(apply)) {
          apply_context <- c(apply_context, list(apply))
        }
        i <- i + 1
        next
      }

      # Handle %clear
      if (grepl("^%clear", line)) {
        i <- i + 1
        next
      }

      # Handle %newobject (marks next method)
      if (grepl("^%newobject", line)) {
        i <- i + 1
        next
      }

      # Skip other SWIG directives
      if (grepl("^%", line)) {
        i <- i + 1
        next
      }

      # Skip #ifdef blocks within extend
      if (grepl("^#if", line)) {
        state <- "SKIP_IFDEF_IN_EXTEND"
        skip_depth <- 1
        i <- i + 1
        next
      }

      # End of extend block - } /* %extend */ or depth returning to class level
      if (grepl("\\}\\s*/\\*.*%extend", line)) {
        dbg("  -> End of %%extend (comment marker)\n")
        state <- "IN_CLASS"
        i <- i + 1
        next
      }

      # If brace closed and we're at class depth (1), %extend is done
      if (line_braces < 0 && brace_depth == 1) {
        dbg("  -> End of %%extend (depth=%d)\n", brace_depth)
        state <- "IN_CLASS"
        i <- i + 1
        next
      }

      i <- i + 1

    } else if (state == "SKIP_IFDEF_IN_EXTEND") {

      if (grepl("^#if", line)) {
        skip_depth <- skip_depth + 1
      } else if (grepl("^#else", line) && skip_depth == 1) {
        # The #else branch is the generic (non-language-specific) code
        # We should process it, not skip it
        state <- "IN_EXTEND"
        # Don't increment i here - let IN_EXTEND handle the line naturally
        # Actually, skip this #else line itself
        i <- i + 1
        next
      } else if (grepl("^#endif", line)) {
        skip_depth <- skip_depth - 1
        if (skip_depth == 0) {
          state <- "IN_EXTEND"
        }
      }
      i <- i + 1

    } else {
      i <- i + 1
    }
  }

  result
}

# ============================================================================
# Pretty printing
# ============================================================================

print_parsed <- function(result) {
  cat("=" |> rep(60) |> paste(collapse = ""), "\n")
  cat("PARSED SWIG FILE\n")
  cat("=" |> rep(60) |> paste(collapse = ""), "\n\n")

  # Renames
  if (length(result$renames) > 0) {
    cat("RENAMES:\n")
    for (internal in names(result$renames)) {
      cat(sprintf("  %s -> %s\n", internal, result$renames[[internal]]))
    }
    cat("\n")
  }

  # Constants
  if (length(result$constants) > 0) {
    cat("CONSTANTS:\n")
    for (const in result$constants) {
      cat(sprintf("  %s = %s\n", const$name, const$value))
    }
    cat("\n")
  }

  # Classes
  for (cls in result$classes) {
    cat(sprintf("CLASS: %s (internal: %s)\n", cls$public_name, cls$internal_name))
    if (!is.na(cls$parent)) {
      cat(sprintf("  Parent: %s\n", cls$parent))
    }

    if (length(cls$methods) > 0) {
      cat("  METHODS:\n")
      for (method in cls$methods) {
        # Format params
        param_strs <- sapply(method$params, function(p) {
          s <- sprintf("%s %s", p$type, p$name)
          if (!is.null(p$default)) {
            s <- sprintf("%s = %s", s, p$default)
          }
          annotations <- c()
          if (p$nonnull) annotations <- c(annotations, "NONNULL")
          if (p$output) annotations <- c(annotations, "OUTPUT")
          if (!is.na(p$typemap)) annotations <- c(annotations, p$typemap)
          if (length(annotations) > 0) {
            s <- sprintf("%s [%s]", s, paste(annotations, collapse = ", "))
          }
          s
        })
        params_str <- paste(param_strs, collapse = ", ")

        cat(sprintf("    %s %s(%s)\n",
                    method$return_type,
                    method$name,
                    params_str))
      }
    }
    cat("\n")
  }
}

# ============================================================================
# Test it!
# ============================================================================

if (interactive() || !exists("SOURCED")) {
  cat("Parsing MajorObject.i...\n\n")
  result <- parse_swig_file("/home/claude/swig/include/MajorObject.i", debug = FALSE)
  print_parsed(result)
}

# Also test with Dataset.i
if (FALSE) {  # Change to TRUE to test
  cat("\n\n")
  cat("Parsing Dataset.i...\n\n")
  result2 <- parse_swig_file("/home/claude/swig/include/Dataset.i", debug = FALSE)
  print_parsed(result2)
}
