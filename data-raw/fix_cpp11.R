# data-raw/fix_cpp11.R
# Fix cpp11::cpp_register() output which generates bad extern "C" declarations
#
# The problem: cpp11 generates duplicate function declarations with wrong types
# in an extern "C" block, causing compilation errors. This script removes those
# bad declarations while keeping the valid registration code.

fix_cpp11 <- function(path = "src/cpp11.cpp", verbose = TRUE) {
  if (!file.exists(path)) {
    if (verbose) message("No cpp11.cpp found at ", path)
    return(invisible(FALSE))
  }

  lines <- readLines(path)
  original_length <- length(lines)


  # Find the bad "extern C" block that declares wrong signatures
  # It contains: /* .Call calls */ followed by extern SEXP declarations
  call_comment <- grep("/\\* \\.Call calls \\*/", lines)
  call_entries <- grep("static const R_CallMethodDef CallEntries", lines)

  if (length(call_comment) > 0 && length(call_entries) > 0) {
    # Remove from after /* .Call calls */ to just before CallEntries
    bad_start <- call_comment[1] + 1
    bad_end <- call_entries[1] - 1

    if (bad_end >= bad_start) {
      lines <- lines[-(bad_start:bad_end)]
      if (verbose) {
        message("Removed ", bad_end - bad_start + 1, " bad extern declarations")
      }
    }
  }

  # Also remove duplicate entries in CallEntries
  # Keep only _GDAL7_ prefixed wrapper functions, not raw function names
  bad_entries <- grepl('^\\s*\\{"GDAL7_', lines)
  if (any(bad_entries)) {
    lines <- lines[!bad_entries]
    if (verbose) {
      message("Removed ", sum(bad_entries), " bad CallEntries")
    }
  }

  # Write fixed file
  writeLines(lines, path)

  if (verbose) {
    message("Fixed ", path, ": ", original_length, " -> ", length(lines), " lines")
  }

  invisible(TRUE)
}

# Run if called directly
if (sys.nframe() == 0 || !exists("SOURCED_FIX_CPP11")) {
  fix_cpp11()
}
