# Regenerates the table in inst/design/extent-transformation.md.
#
# The mesh is computed by shelling out to gdaltransform rather than by calling
# GDAL7, so that the comparison does not check GDAL's boundary walk against a
# mesh built from the same code path. Needs gdaltransform on the PATH.

library(GDAL7)

gdaltransform <- Sys.which("gdaltransform")
if (!nzchar(gdaltransform)) {
  stop("gdaltransform is not on the PATH")
}

mesh_extent <- function(extent, from, to, n = 64) {
  grid <- expand.grid(
    x = seq(extent[1], extent[3], length.out = n + 1),
    y = seq(extent[2], extent[4], length.out = n + 1)
  )
  input <- tempfile()
  on.exit(unlink(input), add = TRUE)
  writeLines(sprintf("%.10f %.10f", grid$x, grid$y), input)

  lines <- system2(
    gdaltransform,
    c("-s_srs", shQuote(from), "-t_srs", shQuote(to)),
    stdin = input, stdout = TRUE, stderr = FALSE
  )
  # gdaltransform prints something non-numeric for a point it could not
  # transform, so the coercion warns; the is.finite filter below is what
  # actually handles those.
  xy <- suppressWarnings(do.call(rbind, lapply(
    strsplit(trimws(lines), "[ ]+"),
    function(z) as.numeric(z[1:2])
  )))

  keep <- is.finite(xy[, 1]) & is.finite(xy[, 2])
  if (!any(keep)) {
    return(c(xmin = NA, ymin = NA, xmax = NA, ymax = NA))
  }
  c(xmin = min(xy[keep, 1]), ymin = min(xy[keep, 2]),
    xmax = max(xy[keep, 1]), ymax = max(xy[keep, 2]))
}

cases <- list(
  list(extent = c(-175, -50, -165, -40), from = "EPSG:4326",
       to = "+proj=aeqd +lat_0=45 +lon_0=10 +datum=WGS84"),
  list(extent = c(90, -10, 130, 30), from = "EPSG:4326",
       to = "+proj=ortho +lat_0=45 +lon_0=10 +datum=WGS84"),
  list(extent = c(110, -45, 155, -10), from = "EPSG:4326", to = "EPSG:3577"),
  list(extent = c(-180, -85, 180, 85), from = "EPSG:4326", to = "EPSG:3857"),
  list(extent = c(60, -70, 120, -60), from = "EPSG:4326", to = "EPSG:3031"),
  list(extent = c(-40, 80, 40, 89.9), from = "EPSG:4326", to = "EPSG:3413")
)

for (case in cases) {
  walk <- transform_extent(case$extent, case$from, case$to, mesh = 0)
  mesh <- mesh_extent(case$extent, case$from, case$to)

  cat("\n", paste(case$extent, collapse = ", "), " -> ", case$to, "\n", sep = "")
  cat("  walk: ", paste(format(walk, digits = 9), collapse = " "), "\n", sep = "")
  cat("  mesh: ", paste(format(mesh, digits = 9), collapse = " "), "\n", sep = "")
  cat("  miss (metres, per edge): ",
      paste(round(c(walk[1] - mesh[1], walk[2] - mesh[2],
                    mesh[3] - walk[3], mesh[4] - walk[4])), collapse = " "),
      "\n", sep = "")
}
