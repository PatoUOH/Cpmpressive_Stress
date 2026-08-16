# --- 1. Librerías ---
library(readr)
library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)
library(scales)

# ============================================================
# CONFIGURACIÓN DE DATASETS Y PALETAS "NEUTRAL SOFT"
# ============================================================

#--- HUAEC 64kPa vs 4GPa ---
 #color_borde <- "#C65350"  # Coral oscuro
 #titulo_grafico <- "HUAEC \u2013 64kPa vs std"
 #ruta <- "/Users/patricio/Documents/Cpmpressive_Stress/Strain_Data/DTU/HUAEC/enrichment_CC_2025-11-21_HUAEC.csv"
 # Gradiente Coral: de oscuro (menor FDR) a claro (mayor FDR) extraído de _div_stops
 #paleta_fill <- c('#C65350', '#EA8C68', '#FABD95', '#FDE3CB', '#F7F5F3')

#--- HUVEC 64kPa vs 4GPa ---
color_borde <- "#25508F"  # Steel Blue oscuro
titulo_grafico <- "HUVEC \u2013 64kPa vs std"
ruta <- "/Users/patricio/Documents/Cpmpressive_Stress/Strain_Data/DTU/HUVEC/enrichment_CC_2025-11-21.csv"
# Gradiente Steel Blue: de oscuro (menor FDR) a claro (mayor FDR) extraído de _seq_stops
paleta_fill <- c('#25508F', '#3966A2', '#527EB5', '#7099C9', '#8DB2D9', '#A8C6E4', '#BED5EC', '#D1E2F2', '#DBE9F5')

#--- HUVEC vs HUAEC 64kPa ---
# color_borde <- "#384860"
# titulo_grafico <- "HUVEC vs HUAEC \u2013 64kPa"
# ruta <- "/Users/patricio/Documents/Cpmpressive_Stress/Strain_Data/DTU/64kPa/enrichment_CC_2026-06-09.csv"
# paleta_fill <- c("#384860", "#6C91B6", "#D3E3F2") # Ejemplo opcional para esta configuración

#--- HUVEC vs HUAEC 4GPa ---
# color_borde <- "#C25E00"
# titulo_grafico <- "HUVEC vs HUAEC \u2013 4GPa (std)"
# ruta <- "/Users/patricio/Documents/Cpmpressive_Stress/Strain_Data/DTU/4GPa/enrichment_CC_2026-06-09.csv"
# paleta_fill <- c("#C25E00", "#F0AB6B", "#FDE3CB") # Ejemplo opcional para esta configuración

# ============================================================

if (!file.exists(ruta)) {
  stop("Archivo no encontrado. Revisa la ruta especificada.")
}

# --- 2. Lectura del archivo ---
datos <- read_csv(ruta, show_col_types = FALSE)

print(names(datos))
print(head(datos, 5))

# --- 3. Corrección de GeneRatio corrompido por Excel (fracciones -> fechas) ---
mes_a_numero <- c(
  ene = 1, jan = 1,
  feb = 2,
  mar = 3,
  abr = 4, apr = 4,
  may = 5,
  jun = 6,
  jul = 7,
  ago = 8, aug = 8,
  sep = 9, sept = 9,
  oct = 10,
  nov = 11,
  dic = 12, dec = 12
)

corregir_generatio <- function(valor) {
  valor <- tolower(trimws(valor))
  if (grepl("^[0-9]+/[0-9]+$", valor)) {
    return(valor)
  }
  m <- regmatches(valor, regexec("^([a-z]{3,4})-([0-9]+)$", valor))[[1]]
  if (length(m) == 3) {
    numerador <- mes_a_numero[m[2]]
    if (!is.na(numerador)) {
      return(paste0(numerador, "/", m[3]))
    }
  }
  return(NA_character_)
}

datos <- datos %>%
  mutate(GeneRatio_corregido = vapply(GeneRatio, corregir_generatio, character(1)))

if (any(is.na(datos$GeneRatio_corregido))) {
  cat("ADVERTENCIA: no se pudieron reparar estos GeneRatio:\n")
  print(datos %>% filter(is.na(GeneRatio_corregido)) %>% select(Description, GeneRatio))
}

# --- 4. Los mismos 12 términos, para comparar HUAEC vs HUVEC directamente ---
terminos_figura <- c(
  "ribosome", "focal adhesion", "large ribosomal subunit", "small ribosomal subunit",
  "cytosolic large ribosomal subunit", "cytosolic ribosome", "cytosolic small ribosomal subunit",
  "cell junction", "cell-substrate junction", "ribosomal subunit",
  "anchoring junction", "ribonucleoprotein complex"
)

datos_procesados <- datos %>%
  filter(!is.na(GeneRatio_corregido)) %>%
  filter(Description %in% terminos_figura) %>%
  rename(Term = Description, GeneCount = Count, FDR = `p.adjust`) %>%
  separate(GeneRatio_corregido, into = c("num", "denom"), sep = "/", convert = TRUE) %>%
  mutate(GeneRatio = num / denom) %>%
  # Orden fijo del eje Y, igual sin importar qué dataset se cargue arriba.
  # rev() para que el primer término de la lista quede arriba del gráfico.
  mutate(Term = factor(Term, levels = rev(terminos_figura))) %>%
  arrange(Term)

cat("Términos encontrados:", nrow(datos_procesados), "de", length(terminos_figura), "\n")
print(datos_procesados %>% select(Term, GeneRatio, GeneCount, FDR))

# ============================================================
# Cálculo robusto de posición del texto y breaks del eje X
# ============================================================
mult_izq <- 1.3
mult_der <- 0.1

min_ratio <- min(datos_procesados$GeneRatio)
max_ratio <- max(datos_procesados$GeneRatio)
rango_datos <- max_ratio - min_ratio

limite_izq    <- min_ratio - mult_izq * rango_datos
limite_der    <- max_ratio + mult_der * rango_datos
ancho_visible <- limite_der - limite_izq

texto_x <- limite_izq + ancho_visible * 0.02

breaks_x <- scales::pretty_breaks(n = 4)(c(min_ratio, max_ratio))
breaks_x <- breaks_x[breaks_x >= 0]
# ============================================================

# --- 5. Gráfico de burbujas ---
grafico <- ggplot(datos_procesados, aes(x = GeneRatio, y = Term)) +
  geom_text(
    aes(label = Term),
    x = texto_x,
    hjust = 0,
    fontface = "italic",
    size = 7,
    color = "black"
  ) +
  geom_point(
    aes(size = GeneCount, fill = FDR),
    shape = 21,
    color = "black",
    stroke = 0.5,
    alpha = 0.95
  ) +
  # Usar la paleta de colores definida en la configuración superior
  scale_fill_gradientn(
    colors = paleta_fill,
    name = "FDR",
    labels = scales::label_scientific()
  ) +
  scale_size_continuous(
    name = "Gene count",
    range = c(4, 16)
  ) +
  guides(
    fill = guide_colorbar(order = 1),
    size = guide_legend(order = 2, override.aes = list(fill = "black"))
  ) +
  scale_x_continuous(
    breaks = breaks_x,
    expand = expansion(mult = c(mult_izq, mult_der))
  ) +
  labs(
    x = "Gene ratio",
    y = NULL,
    #title = titulo_grafico
  ) +
  theme_bw(base_size = 16) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(color = color_borde, fill = NA, linewidth = 1.2),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.text.x = element_text(color = "black"),
    legend.position = "right",
    plot.title = element_text(face = "bold", hjust = 0.5, margin = margin(b = 15))
  )

print(grafico)