# --- Librerías ---
library(ggplot2)
library(dplyr)

# --- Paleta de colores Neutral Soft (Códigos HEX directos para evitar gris) ---
colores_dge <- c(
  "HUVEC vs HUAEC (4GPa)"  = "#25508F",  # blue_steel oscuro (HUVEC 4GPa)
  "HUVEC vs HUAEC (64kPa)" = "#6C91B6",  # blue_steel claro (HUVEC 64kPa)
  "HUVEC (64kPa vs 4GPa)"  = "#C65350",  # rojo coral oscuro (HUAEC 4GPa)
  "HUAEC (64kPa vs 4GPa)"  = "#DC867F"   # rojo coral claro (HUAEC 64kPa)
)

# --- Datos DGE ---
df_dge <- data.frame(
  Comparison = factor(
    c("HUVEC vs HUAEC (4GPa)", "HUVEC vs HUAEC (64kPa)", "HUVEC (64kPa vs 4GPa)", "HUAEC (64kPa vs 4GPa)"),
    levels = c("HUVEC vs HUAEC (4GPa)", "HUVEC vs HUAEC (64kPa)", "HUVEC (64kPa vs 4GPa)", "HUAEC (64kPa vs 4GPa)")
  ),
  Counts = c(666, 2043, 53, 405)
)

# --- Gráfico DGE ---
plot_dge <- ggplot(df_dge, aes(x = Comparison, y = Counts, fill = Comparison)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = Counts), vjust = -0.8, size = 5, fontface = "bold") +
  scale_fill_manual(values = colores_dge) +
  scale_y_continuous(
    limits = c(0, 2300),            # Límite fijo para que el texto de 2043 no se corte
    breaks = c(1000, 2000),         # Marcas exclusivas en 1000 y 2000 en el eje Y
    expand = c(0, 0)                # Quita el espacio en blanco inferior para que las barras toquen el eje X
  ) +
  labs(
    y = "Differential expressed\ngenes",
    x = NULL
  ) +
  theme_classic(base_size = 16) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, color = "black", face = "bold", size = 12),
    axis.text.y = element_text(color = "black", face = "bold", size = 14),
    axis.title.y = element_text(face = "bold", margin = margin(r = 15), size = 15),
    axis.line = element_line(linewidth = 1.2, color = "black"),
    axis.ticks = element_line(linewidth = 1.2, color = "black"),
    axis.ticks.length = unit(0.25, "cm"),
    legend.position = "none",
    plot.margin = margin(t = 20, r = 20, b = 10, l = 10)
  )

print(plot_dge)
# ggsave("DGE_barplot_NeutralSoft.png", plot = plot_dge, width = 6, height = 6, dpi = 300)
# ggsave("DGE_barplot_NeutralSoft.pdf", plot = plot_dge, width = 6, height = 6, device = "pdf")
