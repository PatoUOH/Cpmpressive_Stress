###############################################################
# UpSet Plot for Isoform Switch Consequences - Custom Palettes
# - Paleta "Neutral Soft" preconfigurada desde la figura
# - Modo "Personalizado (Manual)" con colourpicker
# - Orden de consecuencias por defecto (basado en proporción)
###############################################################

required_packages <- c(
  "shiny", "ggplot2", "dplyr", "tidyr", "cowplot",
  "DT", "stringr", "readr", "colourpicker"
)

for(pkg in required_packages){
  if(!require(pkg, character.only = TRUE)){
    # Se especifica el repositorio para que no pregunte por el CRAN mirror
    install.packages(pkg, dependencies = TRUE, repos = "https://cloud.r-project.org/")
    library(pkg, character.only = TRUE)
  }
}

###############################################################
# UI
###############################################################

ui <- fluidPage(
  titlePanel("Shift Consequences UpSet Plot"),
  sidebarLayout(
    sidebarPanel(
      fileInput("csv", "Select CSV file", accept = ".csv"),
      numericInput("top_n", "Top transcripts by |dIF|", value = 20, min = 10, max = 30),
      
      hr(),
      h4("Formatting Options"),
      numericInput("font_size", "Base Font Size", value = 14, min = 8, max = 24),
      checkboxInput("bold_axis", "Bold axis labels", value = FALSE),
      
      hr(),
      h4("Color Palette Options"),
      selectInput("color_palette", "Color Palette Preset",
                  choices = c(
                    "Neutral Soft (Figura)" = "neutral_soft",
                    "HUAEC vs HUVEC (64 kPa)" = "huaec_huvec_64kpa",
                    "Personalizado (Manual)" = "custom",
                    "Nature Communications" = "nature",
                    "Cell" = "cell",
                    "Science" = "science",
                    "NEJM" = "nejm",
                    "The Lancet" = "lancet",
                    "JAMA" = "jama",
                    "Default" = "default"
                  ),
                  selected = "neutral_soft"),
      
      conditionalPanel(
        condition = "input.color_palette == 'custom'",
        colourInput("col_bar_dif", "Barra Superior (dIF)", value = "#DF7163"),
        colourInput("col_points", "Puntos Intersección & Líneas", value = "#5B84B1"),
        colourInput("col_bar_prop", "Barra Izquierda (Proporción)", value = "#689D91"),
        colourInput("col_shade1", "Fondo Alterno 1", value = "#F6F7F9"),
        colourInput("col_shade2", "Fondo Alterno 2", value = "#FFFFFF")
      ),
      
      hr(),
      numericInput("dpi", "Export DPI", value = 300, min = 72, max = 1200),
      hr(),
      verbatimTextOutput("diagnostic"),
      hr(),
      downloadButton("png", "Export PNG"),
      downloadButton("tiff", "Export TIFF")
    ),
    mainPanel(
      plotOutput("upset", height = "1100px"),
      hr(),
      DTOutput("table")
    )
  )
)

###############################################################
# SERVER
###############################################################

server <- function(input, output, session){
  
  raw_data <- reactive({
    req(input$csv)
    df <- read.csv(input$csv$datapath, stringsAsFactors = FALSE, check.names = FALSE)
    df <- as.data.frame(df)
    for(i in seq_along(df)){
      if(is.list(df[[i]])) df[[i]] <- as.character(df[[i]])
      if(inherits(df[[i]], "Rle")) df[[i]] <- as.character(df[[i]])
      if(is.factor(df[[i]])) df[[i]] <- as.character(df[[i]])
    }
    df
  })
  
  selected_data <- reactive({
    df <- raw_data()
    cols <- names(df)
    
    gene_candidates <- c("gene_name", "geneName", "gene", "Gene", "gene_symbol", "GeneSymbol")
    dif_candidates <- c("dIF", "dif", "deltaIF")
    consequence_candidates <- c("switchConsequences", "consequences", "isoform_switch_q_value_consequences", "consequence")
    
    gene_col <- gene_candidates[gene_candidates %in% cols][1]
    dif_col <- dif_candidates[dif_candidates %in% cols][1]
    consequence_col <- consequence_candidates[consequence_candidates %in% cols][1]
    
    validate(
      need(!is.na(gene_col), "Gene column not found"),
      need(!is.na(dif_col), "dIF column not found"),
      need(!is.na(consequence_col), "Consequence column not found")
    )
    
    df <- df %>%
      mutate(
        gene_name = as.character(.data[[gene_col]]),
        dIF = suppressWarnings(as.numeric(.data[[dif_col]])),
        consequences = as.character(.data[[consequence_col]])
      ) %>%
      filter(!is.na(dIF)) %>%
      mutate(abs_dIF = abs(dIF)) %>%
      arrange(desc(abs_dIF)) %>%
      slice_head(n = input$top_n)
    
    df
  })
  
  output$diagnostic <- renderPrint({
    df <- raw_data()
    cat("Rows:", nrow(df), "\n")
    cat("Columns:", ncol(df), "\n\n")
    print(names(df))
  })
  
  # Helper function to clean consequence labels
  clean_label <- function(x) {
    x <- str_replace_all(x, "_", " ")
    sapply(x, function(s) {
      s <- tolower(s)
      words <- strsplit(s, " ")[[1]]
      words <- paste(toupper(substring(words, 1, 1)), substring(words, 2), sep = "")
      paste(words, collapse = " ")
    })
  }
  
  # Wrap long labels into two lines (max 14 chars per line)
  wrap_label <- function(label, max_width = 14) {
    if (nchar(label) <= max_width) return(label)
    words <- strsplit(label, " ")[[1]]
    if (length(words) == 1) {
      return(paste0(substr(label, 1, max_width), "\n", substr(label, max_width + 1, nchar(label))))
    }
    lines <- list()
    current_line <- ""
    for (w in words) {
      if (nchar(current_line) + nchar(w) + 1 <= max_width) {
        if (current_line == "") current_line <- w else current_line <- paste(current_line, w)
      } else {
        lines <- c(lines, current_line)
        current_line <- w
      }
    }
    if (current_line != "") lines <- c(lines, current_line)
    if (length(lines) > 2) {
      lines <- c(lines[1], paste(lines[-1], collapse = " "))
    }
    paste(lines, collapse = "\n")
  }
  
  # High-impact and custom color palettes
  get_colors <- function(palette) {
    if(palette == "neutral_soft") {
      return(list(
        bar_dIF = "#DF7163",         # Tono coral/rosado suave
        point_intersect = "#5B84B1", # Azul suave
        line_connect = "#5B84B1",
        bar_prop = "#689D91",        # Verde azulado suave
        shade1 = "#F3F5F7",
        shade2 = "#FFFFFF"
      ))
    } else if(palette == "huaec_huvec_64kpa") {
      # Lavender (PaletteNeutralSoft.py) as a single accent color throughout,
      # for the HUAEC vs HUVEC 64 kPa comparison.
      return(list(
        bar_dIF = "#A28FC5",
        point_intersect = "#A28FC5",
        line_connect = "#A28FC5",
        bar_prop = "#A28FC5",
        shade1 = "#F3F5F7",
        shade2 = "#FFFFFF"
      ))
    } else if(palette == "custom") {
      return(list(
        bar_dIF = input$col_bar_dif,
        point_intersect = input$col_points,
        line_connect = input$col_points,
        bar_prop = input$col_bar_prop,
        shade1 = input$col_shade1,
        shade2 = input$col_shade2
      ))
    } else if(palette == "nature") {
      return(list(
        bar_dIF = "#E64B35",
        point_intersect = "#4DBBD5",
        line_connect = "#4DBBD5",
        bar_prop = "#3C5488",
        shade1 = "#F0F8FF",
        shade2 = "white"
      ))
    } else if(palette == "cell") {
      return(list(
        bar_dIF = "#D7191C",
        point_intersect = "#2C7BB6",
        line_connect = "#2C7BB6",
        bar_prop = "#A6611A",
        shade1 = "#F0F8FF",
        shade2 = "white"
      ))
    } else if(palette == "science") {
      return(list(
        bar_dIF = "#3594cc",
        point_intersect = "#2e6a9e",
        line_connect = "#2e6a9e",
        bar_prop = "#2066a8",
        shade1 = "#f0f8ff",
        shade2 = "white"
      ))
    } else if(palette == "nejm") {
      return(list(
        bar_dIF = "#97a6c4",
        point_intersect = "#08519C",
        line_connect = "#08519C",
        bar_prop = "#384860",
        shade1 = "#F0f8ff",
        shade2 = "white"
      ))
    } else if(palette == "lancet") {
      return(list(
        bar_dIF = "#B2182B",
        point_intersect = "#2166AC",
        line_connect = "#2166AC",
        bar_prop = "#4D4D4D",
        shade1 = "#f0f8ff",
        shade2 = "white"
      ))
    } else if(palette == "jama") {
      return(list(
        bar_dIF = "#BD3C2B",
        point_intersect = "#2E6A9E",
        line_connect = "#2E6A9E",
        bar_prop = "#4B4B4B",
        shade1 = "#f0f8ff",
        shade2 = "white"
      ))
    } else {
      return(list(
        bar_dIF = "#d8a6a6",
        point_intersect = "#2e6a9e",
        line_connect = "#2e6a9e",
        bar_prop = "#a00000",
        shade1 = "#f0f8ff",
        shade2 = "white"
      ))
    }
  }
  
  upset_plot <- reactive({
    top_df <- selected_data()
    colors <- get_colors(input$color_palette)
    
    # Parse consequences
    consequence_list <- strsplit(
      ifelse(is.na(top_df$consequences), "", top_df$consequences),
      ";|,"
    )
    consequence_list <- lapply(consequence_list, function(x){
      x <- trimws(x)
      x[x != ""]
    })
    
    all_consequences_raw <- unique(unlist(consequence_list))
    
    # Build binary matrix
    mat_raw <- matrix(0, nrow = length(all_consequences_raw), ncol = nrow(top_df))
    rownames(mat_raw) <- all_consequences_raw
    colnames(mat_raw) <- top_df$gene_name
    for(i in seq_along(consequence_list)){
      current <- consequence_list[[i]]
      if(length(current) > 0){
        mat_raw[current, i] <- 1
      }
    }
    
    # Proportions and default sorting (by proportion size)
    prop_df_raw <- data.frame(
      consequence_raw = rownames(mat_raw),
      proportion = rowSums(mat_raw) / ncol(mat_raw) * 100
    ) %>%
      arrange(proportion)
    
    mat_raw <- mat_raw[prop_df_raw$consequence_raw, , drop = FALSE]
    cons_levels_raw <- prop_df_raw$consequence_raw
    cons_levels_clean <- clean_label(cons_levels_raw)
    cons_levels_wrapped <- sapply(cons_levels_clean, wrap_label, max_width = 14)
    names(cons_levels_wrapped) <- cons_levels_raw
    
    prop_df <- data.frame(
      consequence_raw = cons_levels_raw,
      consequence_wrapped = factor(cons_levels_wrapped, levels = cons_levels_wrapped),
      proportion = prop_df_raw$proportion
    )
    gene_levels <- top_df$gene_name
    top_df$gene_name <- factor(top_df$gene_name, levels = gene_levels)
    
    rect_df <- data.frame(
      ymin = seq_along(cons_levels_wrapped) - 0.5,
      ymax = seq_along(cons_levels_wrapped) + 0.5,
      fill = rep(c(colors$shade1, colors$shade2), length.out = length(cons_levels_wrapped))
    )
    
    # ---- BAR TOP (dIF) ----
    bar_top <- ggplot(top_df, aes(x = gene_name, y = dIF)) +
      geom_col(fill = colors$bar_dIF, width = 0.8) +
      labs(x = NULL, y = "Difference in Isoform Fraction") +
      scale_x_discrete(expand = expansion(add = 0.6)) +
      theme_bw(base_size = input$font_size) +
      theme(
        axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5,
                                   face = ifelse(input$bold_axis, "bold", "plain")),
        axis.title.y = element_text(face = ifelse(input$bold_axis, "bold", "plain")),
        panel.grid = element_blank(),
        panel.border = element_blank(),
        axis.line = element_line(),
        plot.margin = margin(5, 0, 0, 0)
      )
    
    # ---- LEFT BAR (proportions) ----
    left_bar <- ggplot(prop_df, aes(x = proportion, y = consequence_wrapped)) +
      geom_col(fill = colors$bar_prop) +
      scale_x_reverse(expand = expansion(mult = c(0, 0.05)), name = "Proportion (%)") +
      scale_y_discrete(position = "right") +
      labs(y = NULL) +
      theme_bw(base_size = input$font_size) +
      theme(
        panel.grid = element_blank(),
        panel.border = element_blank(),
        axis.line = element_line(),
        axis.text.y = element_text(face = ifelse(input$bold_axis, "bold", "plain")),
        axis.ticks.y = element_line(),
        plot.margin = margin(0, 0, 0, 0)
      )
    
    # ---- MATRIX (intersection points) ----
    matrix_df <- expand.grid(
      consequence_raw = cons_levels_raw,
      gene = colnames(mat_raw)
    )
    matrix_df$value <- as.vector(mat_raw)
    matrix_df$consequence <- factor(cons_levels_wrapped[matrix_df$consequence_raw], levels = cons_levels_wrapped)
    matrix_df$gene <- factor(matrix_df$gene, levels = gene_levels)
    
    matrix_plot <- ggplot(matrix_df, aes(x = gene, y = consequence)) +
      geom_rect(data = rect_df,
                aes(xmin = -Inf, xmax = Inf, ymin = ymin, ymax = ymax, fill = fill),
                inherit.aes = FALSE, alpha = 0.5) +
      scale_fill_identity() +
      geom_line(data = subset(matrix_df, value == 1),
                aes(group = gene), color = colors$line_connect, size = 0.8) +
      geom_point(data = subset(matrix_df, value == 0), color = "grey85", size = 3) +
      geom_point(data = subset(matrix_df, value == 1), color = colors$point_intersect, size = 4) +
      scale_x_discrete(expand = expansion(add = 0.6)) +
      theme_bw(base_size = input$font_size) +
      theme(
        axis.text.x = element_blank(),
        axis.title = element_blank(),
        panel.grid = element_blank(),
        panel.border = element_blank(),
        axis.line = element_line(),
        axis.ticks.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        plot.margin = margin(0, 0, 0, 0)
      )
    
    # ---- COMBINE PLOTS ----
    blank <- ggplot() + theme_void() + theme(plot.margin = margin(0, 0, 0, 0))
    
    final_plot <- cowplot::plot_grid(
      blank, bar_top, left_bar, matrix_plot,
      ncol = 2, nrow = 2,
      rel_widths = c(0.9, 2.4),
      rel_heights = c(2.0, 3),
      align = "hv", axis = "tblr"
    )
    
    final_plot
  })
  
  output$upset <- renderPlot({ upset_plot() })
  output$table <- renderDT({ selected_data() })
  
  output$png <- downloadHandler(
    filename = function() { "UpSet_Shift_Consequences.png" },
    content = function(file) {
      ggsave(file, upset_plot(), width = 14, height = 12, dpi = input$dpi)
    }
  )
  
  output$tiff <- downloadHandler(
    filename = function() { "UpSet_Shift_Consequences.tiff" },
    content = function(file) {
      ggsave(file, upset_plot(), width = 14, height = 12, dpi = input$dpi, compression = "lzw")
    }
  )
}

###############################################################
# RUN
###############################################################
# Forzamos a lanzar la aplicación en el navegador web
app <- shinyApp(ui, server)
shiny::runApp(app, launch.browser = TRUE)