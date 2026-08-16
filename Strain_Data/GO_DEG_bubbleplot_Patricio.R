# --- 1. Librerías ---
library(readxl)
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
 #carpeta <- "/Users/patricio/Documents/Cpmpressive_Stress/Strain_Data/DEG/HUAEC_FDR-405/DEVEA_Analysis_HUAEC/Enrichment_HUAEC"
# # Gradiente Coral: de oscuro (menor FDR) a claro (mayor FDR)
 #paleta_fill <- c('#C65350', '#EA8C68', '#FABD95', '#FDE3CB', '#F7F5F3')

#--- HUVEC 64kPa vs 4GPa ---
color_borde <- "#25508F"  # Steel Blue oscuro
carpeta <- "/Users/patricio/Documents/Cpmpressive_Stress/Strain_Data/DEG/HUVEC_FDR-53/DEVEA_Analysis_HUVEC/Enrichment_HUVEC"
# Gradiente Steel Blue: de oscuro (menor FDR) a claro (mayor FDR)
paleta_fill <- c('#25508F', '#3966A2', '#527EB5', '#7099C9', '#8DB2D9', '#A8C6E4', '#BED5EC', '#D1E2F2', '#DBE9F5')

#--- HUVEC vs HUAEC 64kPa ---
# color_borde <- "#384860"
# carpeta <- "/Users/patricio/Documents/Cpmpressive_Stress/Strain_Data/DEG/64kPa_FDR-2043/DEVEA_Analysis_64kPa/Enrichment_64kPa"
# paleta_fill <- c("#384860", "#6C91B6", "#D3E3F2")

#--- HUVEC vs HUAEC 4GPa ---
# color_borde <- "#C25E00"
# carpeta <- "/Users/patricio/Documents/Cpmpressive_Stress/Strain_Data/DEG/4GPa_FDR-666/DEVEA_Analysis_4GPa/Enrichment_4GPa"
# paleta_fill <- c("#C25E00", "#F0AB6B", "#FDE3CB")

# ============================================================

archivos_encontrados <- Sys.glob(file.path(carpeta, "*Call*.xlsx"))
ruta <- archivos_encontrados[1]

if (!file.exists(ruta)) {
  cat("Archivo no encontrado. Archivos disponibles en la carpeta:\n")
  print(list.files(carpeta))
  stop("Revisa la carpeta seleccionada arriba y corrige según la lista impresa.")
}

# --- 3. Lectura ---
datos <- read_excel(ruta, sheet = "Sheet1", skip = 1)
print(names(datos))
print(head(datos, 3))

# --- 4. Filtro de términos ---
terminos_figura <- c(
  "membrane-bounded organelle", "cytoplasm", "extracellular region",
  "extracellular space", "extracellular organelle", "extracellular vesicle",
  "extracellular exosome", "outer membrane", "cytoplasmic vesicle lumen",
  "Lsm1-7-Pat1 complex"
)

datos_procesados <- datos %>%
  filter(Term %in% terminos_figura) %>%
  mutate(`p-value` = as.numeric(`p-value`)) %>%
  rename(FDR = `p-value`, GeneCount = DEG, Background = N) %>%
  mutate(GeneCount = as.numeric(GeneCount),
         Background = as.numeric(Background)) %>%
  mutate(GeneRatio = GeneCount / Background) %>%
  # Orden fijo del eje Y, igual sin importar qué dataset se cargue arriba.
  # rev() para que el primer término de la lista quede arriba del gráfico.
  mutate(Term = factor(Term, levels = rev(terminos_figura))) %>%
  arrange(Term)

cat("Términos encontrados:", nrow(datos_procesados), "de 10\n")
print(datos_procesados %>% select(Term, GeneRatio, GeneCount, FDR))

mult_izq <- 1.3
mult_der <- 0.1

min_ratio <- min(datos_procesados$GeneRatio)
max_ratio <- max(datos_procesados$GeneRatio)
rango_datos <- max_ratio - min_ratio

limite_izq    <- min_ratio - mult_izq * rango_datos
limite_der    <- max_ratio + mult_der * rango_datos
ancho_visible <- limite_der - limite_izq

texto_x <- limite_izq + ancho_visible * 0.02   # 2% del ancho visible TOTAL, no del rango de datos

breaks_x <- scales::pretty_breaks(n = 4)(c(min_ratio, max_ratio))
breaks_x <- breaks_x[breaks_x >= 0]

# --- 6. Gráfico ---
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
    y = NULL
    # El título fue eliminado según las instrucciones
  ) +
  theme_bw(base_size = 16) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(color = color_borde, fill = NA, linewidth = 1.2),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.text.x = element_text(color = "black"),
    legend.position = "right"
  )

print(grafico)

# --- 7. Guardado ---
#ggsave(
#  file.path(carpeta, nombre_salida),
#  grafico, width = 8, height = 6, dpi = 300
#)
#cat("Gráfico guardado como:", nombre_salida, "\n")