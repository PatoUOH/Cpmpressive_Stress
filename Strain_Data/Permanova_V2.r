# ==============================================================================
# PCA Integrado con PERMANOVA - Paleta Neutral Soft (Estilo Figura Referencia)
# ==============================================================================

# --- 1. Cargar librerías ---
paquetes <- c("ggplot2", "vegan", "dplyr", "ggrepel")
for (p in paquetes) {
  if (!require(p, character.only = TRUE)) {
    install.packages(p, dependencies = TRUE, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

# --- 2. Cargar y preparar datos ---
# Asegúrate de poner la ruta correcta a tu archivo
archivo_datos <- "Transcript_counts_with_genes(all_samples).csv"
df <- read.csv(archivo_datos, row.names = 1, check.names = FALSE)

# Transponer (muestras en filas, transcritos en columnas) y transformar (log2 + 1)
# El log2(x+1) es estándar para reducir el sesgo de genes muy expresados en el PCA
datos_t <- t(df)
datos_log <- log2(datos_t + 1)

# --- 3. Crear metadatos automáticamente a partir de los nombres de las muestras ---
nombres_muestras <- rownames(datos_t)

metadata <- data.frame(Sample = nombres_muestras) %>%
  mutate(
    # Extraer tipo celular
    CellType = ifelse(grepl("HUVEC", Sample), "HUVEC", "HUAEC"),
    # Convertir "high" a 4GPa y "low" a 64kPa
    Stiffness = case_when(
      grepl("high", Sample) ~ "4GPa",
      grepl("low", Sample)  ~ "64kPa",
      TRUE ~ "Unknown"
    ),
    # Crear el grupo final exacto como en la leyenda (ej. "HUAEC.4GPa")
    Group = paste(CellType, Stiffness, sep = ".")
  )

rownames(metadata) <- metadata$Sample

# --- 4. Calcular PERMANOVA ---
set.seed(123) # Reproducibilidad
perm_result <- adonis2(datos_log ~ Group, data = metadata, method = "euclidean", permutations = 999)

# Extraer valores para la etiqueta superior
r2_val <- round(perm_result$R2[1], 4)
p_val  <- perm_result$`Pr(>F)`[1]
p_text <- ifelse(p_val < 0.01, "p < 0.01", paste0("p = ", round(p_val, 3)))
permanova_label <- paste0("PERMANOVA: r² = ", r2_val, ", ", p_text)

# --- 5. Calcular PCA ---
pca_result <- prcomp(datos_log, center = TRUE, scale. = TRUE)

# Porcentaje de varianza para los ejes
var_explained <- round(100 * pca_result$sdev^2 / sum(pca_result$sdev^2), 2)
xlab_text <- paste0("PC1 (", var_explained[1], "%)")
ylab_text <- paste0("PC2 (", var_explained[2], "%)")

# Juntar coordenadas con metadatos
pca_df <- as.data.frame(pca_result$x[, 1:2])
pca_df <- cbind(pca_df, metadata)

# --- 6. Paleta de Colores (HUAEC = Azul, HUVEC = Rojo/Coral) ---
colores_puntos <- c(
  "HUAEC.4GPa"  = "#25508F", # Azul oscuro
  "HUAEC.64kPa" = "#6C91B6", # Azul claro
  "HUVEC.4GPa"  = "#C65350", # Coral oscuro
  "HUVEC.64kPa" = "#DC867F"  # Coral claro
)

# Colores para las elipses grupales (por tipo celular)
colores_elipse <- c(
  "HUAEC" = "#25508F",
  "HUVEC" = "#C65350"
)

# --- 7. Generar el Gráfico ---
pca_plot <- ggplot(pca_df, aes(x = PC1, y = PC2)) +
  # Elipses de confianza (95%)
  stat_ellipse(aes(group = CellType, color = CellType), type = "norm", linewidth = 1) +
  # Puntos principales
  geom_point(aes(fill = Group), shape = 21, color = "white", size = 4, stroke = 0.5) +
  # Etiquetas de las muestras que se repelen para no superponerse
  geom_text_repel(aes(label = Sample, color = Group), size = 4.5, fontface = "bold", show.legend = FALSE) +
  # Etiqueta del PERMANOVA
  annotate("text", x = min(pca_df$PC1), y = max(pca_df$PC2) * 1.15, 
           label = permanova_label, hjust = 0, fontface = "bold", size = 5) +
  # Asignar colores definidos
  scale_fill_manual(values = colores_puntos) +
  scale_color_manual(values = c(colores_puntos, colores_elipse)) +
  # Textos y leyendas
  labs(x = xlab_text, y = ylab_text, fill = "Group") +
  # Tema limpio
  theme_classic(base_size = 16) +
  theme(
    axis.text = element_text(color = "black", size = 12),
    axis.title = element_text(color = "black", face = "bold", size = 14),
    axis.line = element_line(linewidth = 1, color = "black"),
    axis.ticks = element_line(linewidth = 1, color = "black"),
    legend.position = "right",
    legend.title = element_text(face = "bold", size = 14),
    legend.text = element_text(size = 12)
  ) +
  # Mantener solo la leyenda de los puntos
  guides(color = "none", fill = guide_legend(override.aes = list(size = 5)))

print(pca_plot)

# --- 8. Exportar figura (Opcional, descomentar para guardar) ---
# ggsave("PCA_PERMANOVA_Final.png", plot = pca_plot, width = 8, height = 6, dpi = 300)
# ggsave("PCA_PERMANOVA_Final.pdf", plot = pca_plot, width = 8, height = 6, device = "pdf")