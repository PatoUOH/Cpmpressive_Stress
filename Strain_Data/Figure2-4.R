library(magick)
library(patchwork)
library(ggplot2)
library(systemfonts)

fuentes <- systemfonts::system_fonts()
arial_disponible <- any(grepl("^Arial$", fuentes$family, ignore.case = TRUE))

if (!arial_disponible) {
  message("Arial no está instalada en este sistema.")
  message("Opciones: instalar Arial, o usar 'Liberation Sans' como sustituto métricamente compatible.")
}

fuente_uso <- if (arial_disponible) "Arial" else "Liberation Sans"
basename_sin_ext <- function(path) tools::file_path_sans_ext(basename(path))

reordenar_archivos <- function(archivos, orden_prioritario) {
  base <- tolower(basename_sin_ext(archivos))
  orden_prioritario <- tolower(orden_prioritario)

  idx_prioritario <- unlist(lapply(orden_prioritario, function(nombre) {
    idx <- which(base == nombre)
    if (length(idx) == 0) {
      warning("No se encontró ningún archivo llamado '", nombre, "' -- revisa el nombre exacto")
    }
    idx
  }))

  idx_resto <- setdiff(seq_along(archivos), idx_prioritario)
  archivos[c(idx_prioritario, idx_resto)]
}

igualar_tamano <- function(imgs, color_fondo = "white") {
  if (length(imgs) <= 1) return(imgs)
  info <- do.call(rbind, lapply(imgs, image_info))
  ancho_max <- max(info$width)
  alto_max  <- max(info$height)
  geom <- sprintf("%dx%d", ancho_max, alto_max)
  lapply(imgs, image_extent, geometry = geom, color = color_fondo, gravity = "center")
}

calcular_alturas_ajustadas <- function(imgs, ncol, ancho) {
  info <- do.call(rbind, lapply(imgs, image_info))
  ancho_columna <- ancho / ncol
  alto_necesario <- ancho_columna * (info$height / info$width)

  n <- length(imgs)
  n_filas <- ceiling(n / ncol)
  alturas <- numeric(n_filas)
  for (i in seq_len(n_filas)) {
    idx_ini <- (i - 1) * ncol + 1
    idx_fin <- min(i * ncol, n)
    alturas[i] <- max(alto_necesario[idx_ini:idx_fin])
  }
  alturas
}

armar_panel <- function(archivos, ncol = 2, dpi = 600,
                         ancho = 10, alto = NULL,
                         alturas = NULL,
                         nombres_especiales = character(0),
                         fuzz_trim = 2,
                         margen_panel_pt = 1,
                         margen_tag_pt = 0,
                         nombre_salida = "figura_panel.pdf") {

  stopifnot(all(file.exists(archivos)))

  base <- tolower(basename_sin_ext(archivos))
  es_especial <- base %in% tolower(nombres_especiales)

  imgs <- lapply(archivos, function(f) {
    img <- image_read_pdf(f, density = dpi)
    image_trim(img, fuzz = fuzz_trim)
  })

  idx_uniformes <- which(!es_especial)
  if (length(idx_uniformes) > 1) {
    imgs[idx_uniformes] <- igualar_tamano(imgs[idx_uniformes])
  }

  if (is.null(alturas)) {
    alturas <- calcular_alturas_ajustadas(imgs, ncol = ncol, ancho = ancho)
  }
  # El alto total de la figura se ajusta automáticamente a la suma
  # de esas alturas, salvo que se especifique manualmente
  if (is.null(alto)) {
    alto <- sum(alturas)
  }

  paneles <- lapply(imgs, function(im) {
    magick::image_ggplot(im) +
      theme(plot.margin = margin(margen_panel_pt, margen_panel_pt,
                                  margen_panel_pt, margen_panel_pt))
  })

  combinado <- wrap_plots(paneles, ncol = ncol) +
    plot_layout(heights = alturas)

  combinado <- combinado +
    plot_annotation(tag_levels = "A") &
    theme(
      plot.tag = element_text(
        family = fuente_uso,
        face   = "bold",
        size   = 14,
        margin = margin(t = 0, r = margen_tag_pt, b = margen_tag_pt, l = 0)
      ),
      plot.tag.position = "topleft"
    )

  ggsave(
    filename = nombre_salida,
    plot     = combinado,
    width    = ancho,
    height   = alto,
    dpi      = dpi,
    device   = cairo_pdf
  )

  message("Guardado: ", nombre_salida, " (", round(ancho, 2), " x ", round(alto, 2), " in)")
  invisible(combinado)
}

carpeta_base <- "/Users/patricio/Documents/Cpmpressive_Stress/Strain_Data"

carpeta_fig2 <- file.path(carpeta_base, "Figura2")
carpeta_fig3 <- file.path(carpeta_base, "Figura3")

archivos_fig2 <- sort(list.files(carpeta_fig2, pattern = "\\.pdf$",
                                  full.names = TRUE, ignore.case = TRUE))
archivos_fig3 <- sort(list.files(carpeta_fig3, pattern = "\\.pdf$",
                                  full.names = TRUE, ignore.case = TRUE))

# Paneles "especiales": quedan fuera de la igualación de tamaño
# (pueden tener su propio tamaño/proporción, distinto de los demás)
nombres_tamano_normal <- c("DGE_barplot", "DTU_barplot", "DGE_tSNE", "DTU_tSNE")


#Figura 2 - DGE
orden_fig2 <- c("DGE_tSNE", "DGE_barplot")
archivos_fig2 <- reordenar_archivos(archivos_fig2, orden_fig2)

#Figura 3 -DTU
orden_fig3 <- c(
  "DTU_tSNE",                   "DTU_barplot",                  # fila 1
  "HUAEC_64-4_DTU",             "HUAEC_64-4_Consequences",      # fila 2
  "HUVEC_64-4_DTU",             "HUVEC_64-4_Consequences",      # fila 3
  "HUVEC_HUAEC-64_DTU",         "HUVEC_HUAEC-64_Consequences"   # fila 4
)
archivos_fig3 <- reordenar_archivos(archivos_fig3, orden_fig3)

print(archivos_fig2)
print(archivos_fig3)

armar_panel(
  archivos_fig2,
  ncol = 2,
  nombres_especiales = nombres_tamano_normal,
  nombre_salida = file.path(carpeta_base, "Figura2_panel.pdf")
)

armar_panel(
  archivos_fig3,
  ncol = 2,
  nombres_especiales = nombres_tamano_normal,
  nombre_salida = file.path(carpeta_base, "Figura3_panel.pdf")
)