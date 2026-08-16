# ==============================================================================
# Shiny App for Differential Expression and Transcriptomics Analysis
# Final version: betadisper convex hull, PCA annotation with Unicode, Report
# Modified to support methylation beta values (logit transformation)
# ==============================================================================

library(shiny)
library(shinydashboard)
library(shinythemes)
library(DT)
library(ggplot2)
library(plotly)
library(readxl)
library(edgeR)
library(DESeq2)
library(vegan)
library(ape)
library(Rtsne)
library(umap)
library(factoextra)
library(ggrepel)
library(pheatmap)
library(corrplot)
library(cluster)
library(fpc)
library(permute)
library(broom)
library(writexl)
library(rmarkdown)
library(knitr)
library(markdown)
library(viridis)
library(RColorBrewer)
library(ggpubr)
library(gridExtra)
library(shinyjs)
library(shinyWidgets)
library(htmltools)
library(igraph)
library(colourpicker)

# -----------------------------------------------------------------------------
# File upload size limit (1000 MB)
# -----------------------------------------------------------------------------
options(shiny.maxRequestSize = 1000 * 1024^2)

# ==============================================================================
# User Interface (UI)
# ==============================================================================

ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "Transcriptomics Explorer"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Import", tabName = "import", icon = icon("upload")),
      menuItem("Preprocessing", tabName = "preprocess", icon = icon("wrench")),
      menuItem("Dimensionality Reduction", tabName = "dimred", icon = icon("chart-line")),
      menuItem("PERMANOVA", tabName = "permanova", icon = icon("balance-scale")),
      menuItem("Assumptions", tabName = "assumptions", icon = icon("check-double")),
      menuItem("Integrated PCA", tabName = "pca_integrated", icon = icon("chart-pie")),
      menuItem("Report", tabName = "report", icon = icon("file-alt")),
      menuItem("Export", tabName = "export", icon = icon("file-export"))
    )
  ),
  dashboardBody(
    useShinyjs(),
    tags$head(
      tags$style(HTML("
        .content-wrapper, .right-side { background-color: #f9f9f9; }
        .box { border-top: 3px solid #3c8dbc; }
      "))
    ),
    tabItems(
      # ========================================================================
      # Module 1: Import
      # ========================================================================
      tabItem(
        tabName = "import",
        fluidRow(
          box(
            title = "Load expression matrix", width = 6, status = "primary",
            fileInput("exprFile", "Choose file (CSV, TSV, TXT, Excel)",
                      accept = c(".csv", ".tsv", ".txt", ".xlsx", ".xls")),
            radioButtons("exprSep", "Separator",
                         choices = c("Comma" = ",", "Tab" = "\t", "Semicolon" = ";"),
                         selected = ","),
            checkboxInput("exprHeader", "First row as column names?", value = TRUE),
            actionButton("loadExpr", "Load matrix", class = "btn-primary"),
            br(),
            DTOutput("exprPreview")
          ),
          box(
            title = "Load metadata (optional)", width = 6, status = "info",
            p("File must have a column with sample names and other columns as factors (groups)."),
            fileInput("metaFile", "Choose metadata file",
                      accept = c(".csv", ".tsv", ".txt", ".xlsx", ".xls")),
            radioButtons("metaSep", "Separator",
                         choices = c("Comma" = ",", "Tab" = "\t", "Semicolon" = ";"),
                         selected = ","),
            checkboxInput("metaHeader", "First row as column names?", value = FALSE),
            actionButton("loadMeta", "Load metadata", class = "btn-info"),
            br(),
            DTOutput("metaPreview")
          )
        ),
        fluidRow(
          box(
            title = "Data status", width = 12, status = "warning",
            verbatimTextOutput("dataStatus")
          )
        )
      ),
      
      # ========================================================================
      # Module 2: Preprocessing (with added logit and data type hints)
      # ========================================================================
      tabItem(
        tabName = "preprocess",
        fluidRow(
          box(
            title = "Filtering", width = 6, status = "primary",
            p(strong("Note:"), "These filters are designed for RNA‑seq counts. For methylation beta values, use with caution or skip."),
            numericInput("minExpr", "Minimum expression (counts)", value = 1, min = 0),
            numericInput("minPctSamples", "Minimum percent of samples expressed (%)",
                         value = 50, min = 0, max = 100, step = 5),
            numericInput("nTopVar", "Number of most variable genes (0 = all)",
                         value = 500, min = 0, step = 100),
            actionButton("applyFilter", "Apply filters", class = "btn-primary")
          ),
          box(
            title = "Transformations", width = 6, status = "info",
            selectInput("transformMethod", "Transformation method",
                        choices = c("None" = "none",
                                    "VST (DESeq2)" = "vst",
                                    "rlog" = "rlog",
                                    "log2(x+1)" = "log2",
                                    "log2(TPM+1)" = "log2tpm",
                                    "logCPM (edgeR)" = "logcpm",
                                    "logit (M-values for methylation)" = "logit",
                                    "Z-score" = "zscore",
                                    "Center and scale" = "scale")),
            checkboxInput("centerData", "Center", value = FALSE),
            checkboxInput("scaleData", "Scale", value = FALSE),
            actionButton("applyTransform", "Apply transformation", class = "btn-info")
          )
        ),
        fluidRow(
          box(
            title = "Preprocessed data summary", width = 12, status = "warning",
            verbatimTextOutput("preprocSummary")
          )
        )
      ),
      
      # ========================================================================
      # Module 3: Dimensionality Reduction (unchanged)
      # ========================================================================
      tabItem(
        tabName = "dimred",
        fluidRow(
          box(
            title = "Reduction method", width = 4, status = "primary",
            selectInput("dimMethod", "Method",
                        choices = c("PCA" = "pca",
                                    "PCoA" = "pcoa",
                                    "Classic MDS" = "mds",
                                    "NMDS" = "nmds",
                                    "t-SNE" = "tsne",
                                    "UMAP" = "umap")),
            selectInput("distMethod", "Distance metric",
                        choices = c("Euclidean" = "euclidean",
                                    "Manhattan" = "manhattan",
                                    "Bray-Curtis" = "bray",
                                    "Canberra" = "canberra",
                                    "Pearson" = "pearson",
                                    "Spearman" = "spearman",
                                    "Kendall" = "kendall",
                                    "Cosine" = "cosine",
                                    "Mahalanobis" = "mahalanobis"),
                        selected = "euclidean"),
            numericInput("dimPerplexity", "Perplexity (t-SNE)", value = 30, min = 5, max = 100),
            numericInput("dimNNeighbors", "Neighbors (UMAP)", value = 15, min = 5, max = 50),
            numericInput("dimSeed", "Random seed", value = 123, min = 1),
            actionButton("runDimRed", "Run reduction", class = "btn-primary")
          ),
          box(
            title = "Plot parameters", width = 8, status = "info",
            selectInput("dimColorBy", "Color by", choices = NULL),
            selectInput("dimShapeBy", "Shape by", choices = NULL),
            selectInput("dimPalette", "Color palette",
                        choices = c("Set1", "Set2", "Set3", "Dark2", "Paired", "Pastel1",
                                    "viridis", "magma", "inferno", "plasma", "cividis")),
            numericInput("dimPointSize", "Point size", value = 3, min = 0.5, max = 10, step = 0.5),
            checkboxInput("dimLabels", "Show labels with ggrepel", value = TRUE),
            checkboxInput("dimEllipse", "Add confidence ellipses", value = TRUE),
            numericInput("dimEllipseConf", "Ellipse confidence level (%)",
                         value = 95, min = 50, max = 99, step = 1),
            checkboxInput("dimHull", "Add convex hulls", value = FALSE),
            checkboxInput("dimCentroids", "Show centroids", value = FALSE),
            checkboxInput("dimSegments", "Segments to centroids", value = FALSE),
            checkboxInput("dimDensity", "Show densities", value = FALSE),
            selectInput("dimTheme", "Theme", choices = c("Light" = "light", "Dark" = "dark")),
            selectInput("dimFacetBy", "Facet by", choices = c("None" = ""), selected = ""),
            actionButton("updateDimPlot", "Update plot", class = "btn-success")
          )
        ),
        fluidRow(
          box(
            title = "Reduction plot", width = 12, status = "primary",
            plotlyOutput("dimPlot", height = "600px"),
            downloadButton("downloadDimPlot", "Download plot (SVG/PDF/PNG/TIFF)")
          )
        )
      ),
      
      # ========================================================================
      # Module 4: PERMANOVA (unchanged)
      # ========================================================================
      tabItem(
        tabName = "permanova",
        fluidRow(
          box(
            title = "PERMANOVA settings", width = 6, status = "primary",
            selectInput("permanovaFactor1", "Factor 1", choices = NULL),
            selectInput("permanovaFactor2", "Factor 2 (optional)", choices = NULL),
            selectInput("permanovaFactor3", "Factor 3 (optional)", choices = NULL),
            checkboxInput("permanovaInteractions", "Include interactions", value = FALSE),
            numericInput("permanovaPermutations", "Number of permutations",
                         value = 999, min = 99, step = 100),
            selectInput("permanovaStrata", "Stratification (strata)", choices = NULL),
            checkboxInput("permanovaPairwise", "Pairwise comparisons (manual)", value = FALSE),
            numericInput("permanovaFDR", "FDR for pairwise", value = 0.05, min = 0.01, max = 0.2, step = 0.01),
            actionButton("runPermanova", "Run PERMANOVA", class = "btn-primary")
          ),
          box(
            title = "PERMANOVA results", width = 6, status = "info",
            DTOutput("permanovaTable")
          )
        ),
        fluidRow(
          box(
            title = "Pairwise results (between groups)", width = 12, status = "warning",
            DTOutput("permanovaPairwiseTable")
          )
        )
      ),
      
      # ========================================================================
      # Module 5: Assumptions (betadisper) - convex hull + customizable
      # ========================================================================
      tabItem(
        tabName = "assumptions",
        fluidRow(
          box(
            title = "Homogeneity of dispersion (betadisper)", width = 6, status = "primary",
            selectInput("assumptionFactor", "Factor for betadisper", choices = NULL),
            actionButton("runBetadisper", "Run betadisper", class = "btn-primary"),
            verbatimTextOutput("betadisperResult")
          ),
          box(
            title = "Betadisper plot customization", width = 6, status = "info",
            checkboxInput("assumptionUseCustomColors", "Use custom colors (from PCA)", value = TRUE),
            numericInput("assumptionPointSize", "Point size", value = 3, min = 1, max = 10, step = 0.5),
            numericInput("assumptionFontSize", "Base font size", value = 12, min = 8, max = 24),
            checkboxInput("assumptionBold", "Bold titles and axes", value = FALSE),
            checkboxInput("assumptionShowConvexHull", "Show convex hull (polygon)", value = TRUE),
            checkboxInput("assumptionShowEllipses", "Show ellipses", value = FALSE),
            numericInput("assumptionEllipseConf", "Ellipse confidence level (%)", value = 95, min = 50, max = 99),
            numericInput("assumptionWidth", "Plot width (pixels)", value = 800, min = 400, max = 2000),
            numericInput("assumptionHeight", "Plot height (pixels)", value = 600, min = 400, max = 1200),
            helpText("The convex hull connects the outermost points of each group around the centroid.")
          )
        ),
        fluidRow(
          box(
            title = "Dispersion plot (PCoA ordination with centroids and hull)", width = 12, status = "primary",
            plotOutput("betadisperPlot", height = "auto"),
            downloadButton("downloadBetadisperPlot", "Download as PNG", class = "btn-success")
          )
        ),
        fluidRow(
          box(
            title = "ANOVA of dispersion and permutest", width = 12, status = "warning",
            verbatimTextOutput("dispersionAnova")
          )
        )
      ),
      
      # ========================================================================
      # Module 6: Integrated PCA (with Unicode annotation, no parse=TRUE)
      # ========================================================================
      tabItem(
        tabName = "pca_integrated",
        fluidRow(
          box(
            title = "PCA settings", width = 4, status = "primary",
            selectInput("pcaColorBy", "Color by (metadata variable)", choices = NULL),
            checkboxInput("pcaEllipse", "Show confidence ellipses", value = TRUE),
            numericInput("pcaEllipseConf", "Confidence level (%)", value = 95, min = 50, max = 99),
            checkboxInput("pcaLabels", "Show sample labels", value = TRUE),
            numericInput("pcaPointSize", "Point size", value = 3, min = 1, max = 10, step = 0.5),
            numericInput("pcaFontSize", "Base font size", value = 12, min = 8, max = 24),
            checkboxInput("pcaBold", "Bold axes labels", value = FALSE),
            numericInput("pcaWidth", "Plot width (pixels)", value = 800, min = 400, max = 2000),
            numericInput("pcaHeight", "Plot height (pixels)", value = 600, min = 400, max = 2000),
            actionButton("generatePca", "Generate PCA", class = "btn-primary")
          ),
          box(
            title = "Custom colors per group", width = 8, status = "info",
            uiOutput("pcaColorInputs"),
            br(),
            actionButton("resetColors", "Reset default colors", class = "btn-warning")
          )
        ),
        fluidRow(
          box(
            title = "PCA plot with PERMANOVA annotation", width = 12, status = "primary",
            plotOutput("pcaIntegratedPlot", height = "auto"),
            downloadButton("downloadPcaPNG", "Download as PNG", class = "btn-success")
          )
        )
      ),
      
      # ========================================================================
      # Module 7: Report
      # ========================================================================
      tabItem(
        tabName = "report",
        fluidRow(
          box(
            title = "Analysis Report", width = 12, status = "primary",
            verbatimTextOutput("reportOutput"),
            br(),
            downloadButton("downloadReportText", "Download report as text", class = "btn-success")
          )
        )
      ),
      
      # ========================================================================
      # Module 8: Export (unchanged)
      # ========================================================================
      tabItem(
        tabName = "export",
        fluidRow(
          box(
            title = "Export results", width = 12, status = "primary",
            h4("Export tables"),
            downloadButton("downloadTableCSV", "Download CSV"),
            downloadButton("downloadTableExcel", "Download Excel"),
            br(), br(),
            h4("Export plots"),
            selectInput("exportPlotFormat", "Format",
                        choices = c("SVG" = "svg", "PDF" = "pdf", "PNG" = "png", "TIFF" = "tiff")),
            numericInput("exportDPI", "DPI (for PNG/TIFF)", value = 300, min = 72, max = 1200, step = 50),
            downloadButton("downloadPlotExport", "Download current plot"),
            br(), br(),
            h4("Export reproducible R script"),
            downloadButton("downloadScript", "Download R script"),
            br(), br(),
            h4("Export report"),
            downloadButton("downloadReport", "Generate HTML/PDF report")
          )
        )
      )
    )
  )
)


# ==============================================================================
# Server logic
# ==============================================================================

server <- function(input, output, session) {
  
  # ----------------------------------------------------------------------------
  # Reactive values
  # ----------------------------------------------------------------------------
  
  values <- reactiveValues(
    exprMatrix = NULL,
    metaData = NULL,
    filteredExpr = NULL,
    transformedExpr = NULL,
    currentDimRed = NULL,
    currentPlot = NULL,
    permanovaRes = NULL,
    permanovaPairwise = NULL,
    betadisperRes = NULL,
    pcaPlot = NULL,
    betadisperPlot = NULL
  )
  
  # ----------------------------------------------------------------------------
  # Import data (unchanged)
  # ----------------------------------------------------------------------------
  
  observeEvent(input$loadExpr, {
    req(input$exprFile)
    ext <- tools::file_ext(input$exprFile$name)
    sep <- input$exprSep
    header <- input$exprHeader
    
    tryCatch({
      if (ext %in% c("csv", "tsv", "txt")) {
        if (ext == "csv") sep <- ","
        if (ext == "tsv") sep <- "\t"
        if (ext == "txt") sep <- input$exprSep
        df <- read.table(input$exprFile$datapath, header = header, sep = sep, row.names = 1,
                         stringsAsFactors = FALSE, check.names = FALSE)
      } else if (ext %in% c("xlsx", "xls")) {
        df <- as.data.frame(read_excel(input$exprFile$datapath, col_names = header))
        if (header) {
          rownames(df) <- df[,1]
          df <- df[,-1]
        } else {
          rownames(df) <- df[,1]
          df <- df[,-1]
        }
      } else {
        showNotification("Unsupported format", type = "error")
        return()
      }
      
      if (!all(sapply(df, is.numeric))) {
        showNotification("Matrix contains non‑numeric columns. Check that first column are gene IDs.", type = "warning")
      }
      
      values$exprMatrix <- as.matrix(df)
      output$exprPreview <- renderDT({ datatable(values$exprMatrix, options = list(scrollX = TRUE, pageLength = 5)) })
      showNotification("Expression matrix loaded successfully", type = "message")
    }, error = function(e) {
      showNotification(paste("Error loading matrix:", e$message), type = "error")
    })
  })
  
  observeEvent(input$loadMeta, {
    req(input$metaFile)
    ext <- tools::file_ext(input$metaFile$name)
    sep <- input$metaSep
    header <- input$metaHeader
    
    tryCatch({
      if (ext %in% c("csv", "tsv", "txt")) {
        if (ext == "csv") sep <- ","
        if (ext == "tsv") sep <- "\t"
        if (ext == "txt") sep <- input$metaSep
        df <- read.table(input$metaFile$datapath, header = header, sep = sep, row.names = 1,
                         stringsAsFactors = TRUE, check.names = FALSE)
      } else if (ext %in% c("xlsx", "xls")) {
        df <- as.data.frame(read_excel(input$metaFile$datapath, col_names = header))
        if (header) {
          rownames(df) <- df[,1]
          df <- df[,-1]
        } else {
          rownames(df) <- df[,1]
          df <- df[,-1]
        }
      } else {
        showNotification("Unsupported format", type = "error")
        return()
      }
      
      colnames(df) <- make.names(colnames(df))
      df[] <- lapply(df, function(x) {
        if (is.character(x)) as.factor(x) else x
      })
      
      values$metaData <- df
      output$metaPreview <- renderDT({ datatable(values$metaData, options = list(scrollX = TRUE, pageLength = 5)) })
      showNotification("Metadata loaded successfully", type = "message")
      
      updateSelectInput(session, "dimColorBy", choices = colnames(df))
      updateSelectInput(session, "dimShapeBy", choices = colnames(df))
      updateSelectInput(session, "permanovaFactor1", choices = colnames(df))
      updateSelectInput(session, "permanovaFactor2", choices = c("None" = "", colnames(df)))
      updateSelectInput(session, "permanovaFactor3", choices = c("None" = "", colnames(df)))
      updateSelectInput(session, "permanovaStrata", choices = c("None" = "", colnames(df)))
      updateSelectInput(session, "assumptionFactor", choices = colnames(df))
      updateSelectInput(session, "dimFacetBy", choices = c("None" = "", colnames(df)), selected = "")
      updateSelectInput(session, "pcaColorBy", choices = colnames(df))
      
    }, error = function(e) {
      showNotification(paste("Error loading metadata:", e$message), type = "error")
    })
  })
  
  output$dataStatus <- renderPrint({
    if (is.null(values$exprMatrix)) {
      cat("No expression matrix loaded.\n")
    } else {
      cat("Expression matrix:", dim(values$exprMatrix)[1], "genes/transcripts,",
          dim(values$exprMatrix)[2], "samples.\n")
      if (!is.null(values$metaData)) {
        cat("Metadata:", dim(values$metaData)[1], "samples,", dim(values$metaData)[2], "variables.\n")
        common <- intersect(rownames(values$metaData), colnames(values$exprMatrix))
        if (length(common) == 0) {
          cat("WARNING: No matching samples between matrix and metadata.\n")
        } else if (length(common) < ncol(values$exprMatrix)) {
          cat("WARNING: Some matrix samples have no metadata.\n")
        } else {
          cat("Sample correspondence: OK.\n")
        }
      } else {
        cat("No metadata loaded.\n")
      }
    }
  })
  
  # ----------------------------------------------------------------------------
  # Preprocessing (modified: added logit transformation)
  # ----------------------------------------------------------------------------
  
  observeEvent(input$applyFilter, {
    req(values$exprMatrix)
    mat <- values$exprMatrix
    
    if (input$minExpr > 0) {
      keep <- apply(mat, 1, function(x) any(x >= input$minExpr))
      mat <- mat[keep, ]
    }
    
    if (input$minPctSamples > 0) {
      pct <- input$minPctSamples / 100
      n <- ncol(mat)
      keep <- apply(mat, 1, function(x) sum(x > 0) / n >= pct)
      mat <- mat[keep, ]
    }
    
    if (input$nTopVar > 0 && input$nTopVar < nrow(mat)) {
      vars <- apply(mat, 1, var)
      top <- order(vars, decreasing = TRUE)[1:input$nTopVar]
      mat <- mat[top, ]
    }
    
    values$filteredExpr <- mat
    output$preprocSummary <- renderPrint({
      cat("After filtering:\n")
      cat("  - Genes/transcripts:", nrow(mat), "\n")
      cat("  - Samples:", ncol(mat), "\n")
      cat("  - Expression range: [", min(mat), ",", max(mat), "]\n")
    })
    showNotification("Filters applied successfully", type = "message")
  })
  
  observeEvent(input$applyTransform, {
    req(values$filteredExpr)
    mat <- values$filteredExpr
    
    transform <- input$transformMethod
    center <- input$centerData
    scale <- input$scaleData
    
    tryCatch({
      if (transform == "none") {
        trans <- mat
      } else if (transform == "vst") {
        if (!all(mat == round(mat))) {
          showNotification("VST requires integer counts. Rounding values.", type = "warning")
          mat <- round(mat)
        }
        dds <- DESeqDataSetFromMatrix(countData = mat, colData = data.frame(row.names = colnames(mat)), design = ~ 1)
        dds <- estimateSizeFactors(dds)
        trans <- assay(varianceStabilizingTransformation(dds, blind = TRUE))
      } else if (transform == "rlog") {
        if (!all(mat == round(mat))) {
          showNotification("rlog requires integer counts. Rounding values.", type = "warning")
          mat <- round(mat)
        }
        dds <- DESeqDataSetFromMatrix(countData = mat, colData = data.frame(row.names = colnames(mat)), design = ~ 1)
        dds <- estimateSizeFactors(dds)
        trans <- assay(rlog(dds, blind = TRUE))
      } else if (transform == "log2") {
        trans <- log2(mat + 1)
      } else if (transform == "log2tpm") {
        cpm <- cpm(mat, log = FALSE)
        trans <- log2(cpm + 1)
      } else if (transform == "logcpm") {
        trans <- cpm(mat, log = TRUE, prior.count = 1)
      } else if (transform == "logit") {
        # M-values for methylation beta values
        eps <- 1e-6
        # Clamp values to avoid log(0) or log(Inf)
        if (any(mat < 0, na.rm = TRUE) || any(mat > 1, na.rm = TRUE)) {
          showNotification("Data contains values outside [0,1]; logit transformation may be invalid for methylation beta values.", type = "warning")
        }
        mat_clamped <- pmax(pmin(mat, 1 - eps), eps)
        trans <- log2(mat_clamped / (1 - mat_clamped))
      } else if (transform == "zscore") {
        trans <- t(scale(t(mat)))
      } else if (transform == "scale") {
        trans <- mat
        if (center) trans <- trans - rowMeans(trans)
        if (scale) trans <- trans / apply(trans, 1, sd)
      } else {
        trans <- mat
      }
      
      if (center && transform != "scale") {
        trans <- trans - rowMeans(trans)
      }
      if (scale && transform != "scale") {
        trans <- trans / apply(trans, 1, sd)
      }
      
      values$transformedExpr <- trans
      output$preprocSummary <- renderPrint({
        cat("Transformed data:\n")
        cat("  - Method:", transform, "\n")
        cat("  - Dimensions:", dim(trans), "\n")
        cat("  - Range: [", min(trans), ",", max(trans), "]\n")
        if (transform == "logit") {
          cat("  - Note: logit transformation is suitable for methylation beta values.\n")
        }
      })
      showNotification("Transformation applied successfully", type = "message")
    }, error = function(e) {
      showNotification(paste("Error in transformation:", e$message), type = "error")
    })
  })
  
  # ----------------------------------------------------------------------------
  # Dimensionality Reduction (unchanged)
  # ----------------------------------------------------------------------------
  
  observeEvent(input$runDimRed, {
    req(values$transformedExpr)
    mat <- values$transformedExpr
    if (is.null(values$metaData)) {
      meta <- data.frame(row.names = colnames(mat), Sample = colnames(mat))
      values$metaData <- meta
    }
    meta <- values$metaData
    
    dist_method <- switch(input$distMethod,
                          "euclidean" = "euclidean",
                          "manhattan" = "manhattan",
                          "bray" = "bray",
                          "canberra" = "canberra",
                          "pearson" = "pearson",
                          "spearman" = "spearman",
                          "kendall" = "kendall",
                          "cosine" = "cosine",
                          "mahalanobis" = "mahalanobis")
    
    dist_obj <- NULL
    if (input$dimMethod %in% c("pcoa", "mds", "nmds")) {
      if (dist_method %in% c("pearson", "spearman", "kendall", "cosine")) {
        if (dist_method == "pearson") dist_obj <- as.dist(1 - cor(mat, method = "pearson"))
        else if (dist_method == "spearman") dist_obj <- as.dist(1 - cor(mat, method = "spearman"))
        else if (dist_method == "kendall") dist_obj <- as.dist(1 - cor(mat, method = "kendall"))
        else if (dist_method == "cosine") {
          cos_sim <- function(x) {
            x <- t(x)
            sim <- x %*% t(x) / (sqrt(rowSums(x^2)) %*% t(sqrt(rowSums(x^2))))
            sim
          }
          dist_obj <- as.dist(1 - cos_sim(mat))
        }
      } else {
        dist_obj <- dist(t(mat), method = dist_method)
      }
    }
    
    res <- NULL
    set.seed(input$dimSeed)
    tryCatch({
      if (input$dimMethod == "pca") {
        res <- prcomp(t(mat), center = TRUE, scale. = TRUE)
      } else if (input$dimMethod == "pcoa") {
        res <- pcoa(dist_obj)
      } else if (input$dimMethod == "mds") {
        res <- cmdscale(dist_obj, k = 2, eig = TRUE)
      } else if (input$dimMethod == "nmds") {
        res <- metaMDS(dist_obj, k = 2, trymax = 50)
      } else if (input$dimMethod == "tsne") {
        res <- Rtsne(t(mat), perplexity = input$dimPerplexity, check_duplicates = FALSE)
      } else if (input$dimMethod == "umap") {
        res <- umap(t(mat), n_neighbors = input$dimNNeighbors)
      }
      values$currentDimRed <- list(method = input$dimMethod, result = res, dist = dist_obj)
      showNotification("Reduction completed", type = "message")
    }, error = function(e) {
      showNotification(paste("Error in reduction:", e$message), type = "error")
    })
  })
  
  observeEvent(input$updateDimPlot, {
    req(values$currentDimRed)
    res_list <- values$currentDimRed
    method <- res_list$method
    res <- res_list$result
    meta <- values$metaData
    
    coords <- NULL
    if (method == "pca") {
      coords <- as.data.frame(res$x[,1:2])
      colnames(coords) <- c("Dim1", "Dim2")
      var_exp <- round(summary(res)$importance[2,1:2]*100, 2)
      xlab <- paste0("PC1 (", var_exp[1], "%)")
      ylab <- paste0("PC2 (", var_exp[2], "%)")
    } else if (method == "pcoa") {
      coords <- as.data.frame(res$vectors[,1:2])
      colnames(coords) <- c("Dim1", "Dim2")
      xlab <- "PCoA1"; ylab <- "PCoA2"
    } else if (method == "mds") {
      coords <- as.data.frame(res$points[,1:2])
      colnames(coords) <- c("Dim1", "Dim2")
      xlab <- "MDS1"; ylab <- "MDS2"
    } else if (method == "nmds") {
      coords <- as.data.frame(res$points[,1:2])
      colnames(coords) <- c("Dim1", "Dim2")
      xlab <- "NMDS1"; ylab <- "NMDS2"
    } else if (method == "tsne") {
      coords <- as.data.frame(res$Y[,1:2])
      colnames(coords) <- c("Dim1", "Dim2")
      xlab <- "t-SNE1"; ylab <- "t-SNE2"
    } else if (method == "umap") {
      coords <- as.data.frame(res$layout[,1:2])
      colnames(coords) <- c("Dim1", "Dim2")
      xlab <- "UMAP1"; ylab <- "UMAP2"
    }
    
    if (is.null(coords) || ncol(coords) < 2) {
      showNotification("Could not get coordinates for the plot.", type = "error")
      return()
    }
    
    if (!is.null(meta)) {
      coords <- cbind(coords, meta[rownames(coords), , drop = FALSE])
    } else {
      coords$Sample <- rownames(coords)
    }
    
    color_var <- input$dimColorBy
    shape_var <- input$dimShapeBy
    if (!is.null(color_var) && color_var %in% colnames(coords)) {
      coords$Color <- coords[[color_var]]
    } else {
      coords$Color <- "Group"
    }
    if (!is.null(shape_var) && shape_var %in% colnames(coords)) {
      coords$Shape <- coords[[shape_var]]
    } else {
      coords$Shape <- "Group"
    }
    
    p <- ggplot(coords, aes(x = Dim1, y = Dim2, color = Color, shape = Shape)) +
      labs(x = xlab, y = ylab, title = paste("Reduction:", method))
    
    if (input$dimTheme == "dark") {
      p <- p + theme_dark()
    } else {
      p <- p + theme_classic()
    }
    
    pal <- input$dimPalette
    if (pal %in% rownames(brewer.pal.info)) {
      p <- p + scale_color_brewer(palette = pal)
    } else if (pal %in% c("viridis", "magma", "inferno", "plasma", "cividis")) {
      p <- p + scale_color_viridis_d(option = pal)
    }
    
    p <- p + geom_point(size = input$dimPointSize)
    
    if (input$dimLabels) {
      p <- p + geom_text_repel(aes(label = rownames(coords)), size = 3)
    }
    
    if (input$dimEllipse && length(unique(coords$Color)) > 1) {
      conf <- input$dimEllipseConf / 100
      p <- p + stat_ellipse(level = conf, aes(group = Color))
    }
    
    if (input$dimHull && length(unique(coords$Color)) > 1) {
      hulls <- coords %>% group_by(Color) %>% dplyr::slice(chull(Dim1, Dim2))
      p <- p + geom_polygon(data = hulls, aes(fill = Color), alpha = 0.1, show.legend = FALSE)
    }
    
    if (input$dimCentroids) {
      centroids <- coords %>% group_by(Color) %>% summarise(Dim1 = mean(Dim1), Dim2 = mean(Dim2))
      p <- p + geom_point(data = centroids, aes(x = Dim1, y = Dim2), size = 5, shape = 4, color = "black")
      if (input$dimSegments) {
        p <- p + geom_segment(data = centroids, aes(x = Dim1, y = Dim2, xend = Dim1, yend = Dim2),
                              color = "gray", linetype = "dashed", alpha = 0.5)
      }
    }
    
    if (input$dimDensity) {
      p <- p + geom_density2d(alpha = 0.3)
    }
    
    if (!is.null(input$dimFacetBy) && input$dimFacetBy != "" && input$dimFacetBy %in% colnames(coords)) {
      p <- p + facet_wrap(~ coords[[input$dimFacetBy]])
    }
    
    values$currentPlot <- p
    output$dimPlot <- renderPlotly({
      ggplotly(p, tooltip = "text")
    })
  })
  
  # ----------------------------------------------------------------------------
  # PERMANOVA (unchanged)
  # ----------------------------------------------------------------------------
  
  observeEvent(input$runPermanova, {
    req(values$transformedExpr, values$metaData)
    mat <- values$transformedExpr
    meta <- values$metaData
    
    # ---- 1. Validate sample alignment ----
    common_samples <- intersect(colnames(mat), rownames(meta))
    if (length(common_samples) < 2) {
      showNotification("Need at least 2 common samples between matrix and metadata.", type = "error")
      return()
    }
    if (length(common_samples) < ncol(mat)) {
      showNotification(paste("Using only", length(common_samples), "common samples (out of", ncol(mat), ")."), type = "warning")
    }
    mat <- mat[, common_samples, drop = FALSE]
    meta <- meta[common_samples, , drop = FALSE]
    
    # ---- 2. Validate factor 1 ----
    f1 <- input$permanovaFactor1
    if (is.null(f1) || f1 == "") {
      showNotification("Select at least one factor in 'Factor 1'.", type = "warning")
      return()
    }
    
    if (!f1 %in% colnames(meta)) {
      showNotification(
        paste0("Factor '", f1, "' does not exist in metadata.\nAvailable columns: ", 
               paste(colnames(meta), collapse = ", ")), 
        type = "error"
      )
      return()
    }
    
    factores <- c(f1)
    f2 <- input$permanovaFactor2
    f3 <- input$permanovaFactor3
    
    if (!is.null(f2) && f2 != "" && f2 != "None") {
      if (!f2 %in% colnames(meta)) {
        showNotification(paste("Factor '", f2, "' does not exist in metadata."), type = "error")
        return()
      }
      factores <- c(factores, f2)
    }
    if (!is.null(f3) && f3 != "" && f3 != "None") {
      if (!f3 %in% colnames(meta)) {
        showNotification(paste("Factor '", f3, "' does not exist in metadata."), type = "error")
        return()
      }
      factores <- c(factores, f3)
    }
    
    # ---- 3. Remove rows with NAs ----
    keep <- rep(TRUE, nrow(meta))
    for (f in factores) {
      if (any(is.na(meta[[f]]))) {
        showNotification(paste("Factor", f, "contains NAs. Removing those samples."), type = "warning")
        keep <- keep & !is.na(meta[[f]])
      }
    }
    if (sum(keep) < 2) {
      showNotification("After removing NAs, fewer than 2 samples remain. Cannot run PERMANOVA.", type = "error")
      return()
    }
    if (sum(keep) < nrow(meta)) {
      mat <- mat[, keep, drop = FALSE]
      meta <- meta[keep, , drop = FALSE]
      showNotification(paste("Using", nrow(meta), "samples after removing NAs."), type = "message")
    }
    
    # ---- 4. Compute distance ----
    dist_method <- input$distMethod
    d <- NULL
    tryCatch({
      if (dist_method %in% c("pearson", "spearman", "kendall", "cosine")) {
        if (dist_method == "pearson") {
          d <- as.dist(1 - cor(mat, method = "pearson"))
        } else if (dist_method == "spearman") {
          d <- as.dist(1 - cor(mat, method = "spearman"))
        } else if (dist_method == "kendall") {
          d <- as.dist(1 - cor(mat, method = "kendall"))
        } else if (dist_method == "cosine") {
          cos_sim <- function(x) {
            x <- t(x)
            sim <- x %*% t(x) / (sqrt(rowSums(x^2)) %*% t(sqrt(rowSums(x^2))))
            sim
          }
          d <- as.dist(1 - cos_sim(mat))
        }
      } else {
        d <- dist(t(mat), method = dist_method)
      }
    }, error = function(e) {
      showNotification(paste("Error computing distance:", e$message), type = "error")
      return()
    })
    
    if (is.null(d) || !inherits(d, "dist")) {
      showNotification("Could not obtain a valid distance matrix.", type = "error")
      return()
    }
    if (attr(d, "Size") != nrow(meta)) {
      showNotification(
        paste("Number of samples in distance (", attr(d, "Size"), 
              ") does not match metadata (", nrow(meta), ").", sep = ""), 
        type = "error"
      )
      return()
    }
    
    # ---- 5. Formula for PERMANOVA ----
    formula_str <- paste("d ~", f1)
    if (f2 != "" && f2 != "None") {
      if (input$permanovaInteractions) {
        formula_str <- paste(formula_str, "*", f2)
      } else {
        formula_str <- paste(formula_str, "+", f2)
      }
    }
    if (f3 != "" && f3 != "None") {
      if (input$permanovaInteractions) {
        formula_str <- paste(formula_str, "*", f3)
      } else {
        formula_str <- paste(formula_str, "+", f3)
      }
    }
    form_final <- as.formula(formula_str)
    environment(form_final) <- globalenv()
    
    # ---- 6. Stratification ----
    strata <- NULL
    if (input$permanovaStrata != "" && input$permanovaStrata != "None") {
      if (!input$permanovaStrata %in% colnames(meta)) {
        showNotification("Selected strata does not exist in metadata. Ignored.", type = "warning")
      } else {
        strata <- meta[[input$permanovaStrata]]
      }
    }
    
    # ---- 7. Run PERMANOVA ----
    set.seed(input$dimSeed)
    tryCatch({
      permanova <- adonis2(
        formula = form_final,
        data = meta,
        permutations = input$permanovaPermutations,
        strata = strata
      )
      values$permanovaRes <- permanova
      output$permanovaTable <- renderDT({
        datatable(as.data.frame(permanova), options = list(pageLength = 10), rownames = TRUE)
      })
      showNotification("PERMANOVA completed successfully.", type = "message")
      
      # ---- 8. Manual pairwise comparisons (between groups) ----
      if (input$permanovaPairwise) {
        tryCatch({
          levels_factor <- levels(as.factor(meta[[f1]]))
          if (length(levels_factor) < 2) {
            showNotification("Factor must have at least 2 levels for pairwise comparisons.", type = "warning")
          } else {
            pairwise_results <- list()
            
            for (i in 1:(length(levels_factor)-1)) {
              for (j in (i+1):length(levels_factor)) {
                grp1 <- levels_factor[i]
                grp2 <- levels_factor[j]
                
                idx <- meta[[f1]] %in% c(grp1, grp2)
                if (sum(idx) < 2) next
                
                meta_sub <- meta[idx, , drop = FALSE]
                d_mat <- as.matrix(d)
                d_sub <- as.dist(d_mat[idx, idx])
                
                pair_formula <- as.formula(paste("d_sub ~", f1))
                pair_test <- adonis2(pair_formula, data = meta_sub, permutations = input$permanovaPermutations)
                
                f_val <- pair_test[1, "F"]
                if (is.na(f_val) && "F.Model" %in% colnames(pair_test)) {
                  f_val <- pair_test[1, "F.Model"]
                }
                r2_val <- pair_test[1, "R2"]
                p_val <- pair_test[1, "Pr(>F)"]
                
                comp_name <- paste(grp1, "vs", grp2, sep = " ")
                pairwise_results[[comp_name]] <- data.frame(
                  Comparison = comp_name,
                  F = f_val,
                  R2 = r2_val,
                  p.value = p_val,
                  stringsAsFactors = FALSE
                )
              }
            }
            
            if (length(pairwise_results) > 0) {
              df_pair <- do.call(rbind, pairwise_results)
              df_pair$p.adjusted <- p.adjust(df_pair$p.value, method = "fdr")
              df_pair$Significant <- ifelse(df_pair$p.adjusted < input$permanovaFDR, "Yes", "No")
              
              values$permanovaPairwise <- df_pair
              output$permanovaPairwiseTable <- renderDT({
                datatable(df_pair, options = list(pageLength = 10))
              })
              showNotification(paste("Manual pairwise comparisons completed:", nrow(df_pair), "comparisons."), type = "message")
            } else {
              showNotification("Could not perform pairwise comparisons.", type = "warning")
            }
          }
        }, error = function(e) {
          showNotification(paste("Error in manual pairwise comparisons:", e$message), type = "error")
        })
      }
      
    }, error = function(e) {
      if (grepl("object .* not found", e$message, ignore.case = TRUE)) {
        showNotification(
          paste("Error: variable not found in formula.\n",
                "Check that the selected factor exists and the distance 'd' is correct.\n",
                "Columns in metadata: ", paste(colnames(meta), collapse = ", "), "\n",
                "Formula: ", formula_str),
          type = "error", duration = 10
        )
      } else {
        showNotification(paste("Error in PERMANOVA:", e$message), type = "error")
      }
    })
  })
  
  # ----------------------------------------------------------------------------
  # Assumptions (betadisper) - unchanged
  # ----------------------------------------------------------------------------
  
  observeEvent(input$runBetadisper, {
    req(values$transformedExpr, values$metaData)
    factor <- input$assumptionFactor
    if (is.null(factor) || factor == "") {
      showNotification("Select a factor.", type = "warning")
      return()
    }
    if (!factor %in% colnames(values$metaData)) {
      showNotification(paste("Factor '", factor, "' does not exist in metadata."), type = "error")
      return()
    }
    mat <- values$transformedExpr
    meta <- values$metaData
    
    common <- intersect(colnames(mat), rownames(meta))
    if (length(common) < 2) {
      showNotification("Need at least 2 common samples.", type = "error")
      return()
    }
    mat <- mat[, common, drop = FALSE]
    meta <- meta[common, , drop = FALSE]
    
    group <- meta[[factor]]
    na_idx <- is.na(group)
    if (any(na_idx)) {
      showNotification(paste("Removing", sum(na_idx), "samples with NA in", factor), type = "warning")
      meta <- meta[!na_idx, , drop = FALSE]
      mat <- mat[, rownames(meta), drop = FALSE]
      group <- meta[[factor]]
    }
    
    dist_method <- input$distMethod
    if (dist_method %in% c("pearson", "spearman", "kendall", "cosine")) {
      if (dist_method == "pearson") d <- as.dist(1 - cor(mat, method = "pearson"))
      else if (dist_method == "spearman") d <- as.dist(1 - cor(mat, method = "spearman"))
      else if (dist_method == "kendall") d <- as.dist(1 - cor(mat, method = "kendall"))
      else if (dist_method == "cosine") {
        cos_sim <- function(x) {
          x <- t(x)
          sim <- x %*% t(x) / (sqrt(rowSums(x^2)) %*% t(sqrt(rowSums(x^2))))
          sim
        }
        d <- as.dist(1 - cos_sim(mat))
      }
    } else {
      d <- dist(t(mat), method = dist_method)
    }
    
    tryCatch({
      betad <- betadisper(d, group)
      values$betadisperRes <- betad
      
      output$betadisperResult <- renderPrint({
        print(betad)
        cat("\nANOVA of dispersion:\n")
        print(anova(betad))
        cat("\nPermutest:\n")
        print(permutest(betad))
      })
      output$dispersionAnova <- renderPrint({
        cat("Homogeneity of dispersion test (permutations):\n")
        print(permutest(betad))
      })
      
      # PCoA coordinates
      pcoa_coords <- betad$vectors[, 1:2]
      colnames(pcoa_coords) <- c("PCoA1", "PCoA2")
      centroids <- betad$centroids[, 1:2]
      colnames(centroids) <- c("PCoA1", "PCoA2")
      
      df_pts <- data.frame(
        Sample = rownames(pcoa_coords),
        Group = group,
        PCoA1 = pcoa_coords[,1],
        PCoA2 = pcoa_coords[,2],
        stringsAsFactors = FALSE
      )
      df_cent <- data.frame(
        Group = rownames(centroids),
        PCoA1 = centroids[,1],
        PCoA2 = centroids[,2],
        stringsAsFactors = FALSE
      )
      
      hull_data <- df_pts %>%
        group_by(Group) %>%
        dplyr::slice(chull(PCoA1, PCoA2)) %>%
        ungroup()
      
      grupos <- unique(group)
      grupos <- grupos[!is.na(grupos)]
      
      if (input$assumptionUseCustomColors) {
        color_map <- sapply(grupos, function(g) {
          col <- input[[paste0("pca_color_", g)]]
          if (is.null(col) || col == "") return(NULL)
          return(col)
        })
        if (any(sapply(color_map, is.null))) {
          default_colors <- RColorBrewer::brewer.pal(min(length(grupos), 8), "Set1")
          if (length(grupos) > 8) default_colors <- viridis::viridis(length(grupos))
          names(default_colors) <- grupos
          color_map <- default_colors
        } else {
          names(color_map) <- grupos
        }
      } else {
        default_colors <- RColorBrewer::brewer.pal(min(length(grupos), 8), "Set1")
        if (length(grupos) > 8) default_colors <- viridis::viridis(length(grupos))
        names(default_colors) <- grupos
        color_map <- default_colors
      }
      
      p <- ggplot(df_pts, aes(x = PCoA1, y = PCoA2, color = Group)) +
        geom_point(size = input$assumptionPointSize) +
        scale_color_manual(values = color_map) +
        labs(
          title = "Distance to centroid (betadisper)",
          x = "PCoA1",
          y = "PCoA2",
          color = factor
        ) +
        theme_classic(base_size = input$assumptionFontSize)
      
      p <- p + geom_point(data = df_cent, aes(x = PCoA1, y = PCoA2, color = Group),
                          size = input$assumptionPointSize * 2, shape = 4, stroke = 2)
      
      if (input$assumptionShowConvexHull) {
        p <- p + geom_polygon(data = hull_data, aes(x = PCoA1, y = PCoA2, fill = Group, color = Group),
                              alpha = 0.1, linetype = "solid", size = 0.8, show.legend = FALSE)
        p <- p + scale_fill_manual(values = color_map)
      }
      
      if (input$assumptionShowEllipses) {
        conf <- input$assumptionEllipseConf / 100
        p <- p + stat_ellipse(aes(group = Group), level = conf, linetype = "dashed", show.legend = FALSE)
      }
      
      if (input$assumptionBold) {
        p <- p + theme(
          axis.title = element_text(face = "bold"),
          plot.title = element_text(face = "bold")
        )
      }
      
      values$betadisperPlot <- p
      output$betadisperPlot <- renderPlot({
        p
      }, width = input$assumptionWidth, height = input$assumptionHeight, res = 100)
      
      showNotification("betadisper completed", type = "message")
    }, error = function(e) {
      showNotification(paste("Error in betadisper:", e$message), type = "error")
    })
  })
  
  output$downloadBetadisperPlot <- downloadHandler(
    filename = function() "betadisper_pcoa.png",
    content = function(file) {
      req(values$betadisperPlot)
      ggsave(file, plot = values$betadisperPlot, 
             width = input$assumptionWidth/100, height = input$assumptionHeight/100, dpi = 300)
    }
  )
  
  # ----------------------------------------------------------------------------
  # Integrated PCA (unchanged)
  # ----------------------------------------------------------------------------
  
  output$pcaColorInputs <- renderUI({
    req(values$metaData)
    color_var <- input$pcaColorBy
    if (is.null(color_var) || color_var == "") {
      return(helpText("Select a variable to color by in the settings."))
    }
    grupos <- unique(values$metaData[[color_var]])
    grupos <- grupos[!is.na(grupos)]
    if (length(grupos) == 0) return(helpText("No groups in selected variable."))
    
    default_colors <- RColorBrewer::brewer.pal(min(length(grupos), 8), "Set1")
    if (length(grupos) > 8) default_colors <- viridis::viridis(length(grupos))
    
    input_list <- lapply(seq_along(grupos), function(i) {
      colourpicker::colourInput(
        inputId = paste0("pca_color_", grupos[i]),
        label = grupos[i],
        value = default_colors[i]
      )
    })
    do.call(tagList, input_list)
  })
  
  observeEvent(input$resetColors, {
    req(values$metaData, input$pcaColorBy)
    color_var <- input$pcaColorBy
    grupos <- unique(values$metaData[[color_var]])
    grupos <- grupos[!is.na(grupos)]
    if (length(grupos) == 0) return()
    
    default_colors <- RColorBrewer::brewer.pal(min(length(grupos), 8), "Set1")
    if (length(grupos) > 8) default_colors <- viridis::viridis(length(grupos))
    
    for (i in seq_along(grupos)) {
      colourpicker::updateColourInput(
        session, 
        inputId = paste0("pca_color_", grupos[i]), 
        value = default_colors[i]
      )
    }
    showNotification("Colors reset to default.", type = "message")
  })
  
  observeEvent(input$generatePca, {
    req(values$transformedExpr, values$metaData)
    color_var <- input$pcaColorBy
    if (is.null(color_var) || color_var == "") {
      showNotification("Select a variable to color by.", type = "warning")
      return()
    }
    if (!color_var %in% colnames(values$metaData)) {
      showNotification("Selected variable does not exist in metadata.", type = "error")
      return()
    }
    
    mat <- values$transformedExpr
    meta <- values$metaData
    
    common <- intersect(colnames(mat), rownames(meta))
    if (length(common) < 2) {
      showNotification("Need at least 2 common samples.", type = "error")
      return()
    }
    mat <- mat[, common, drop = FALSE]
    meta <- meta[common, , drop = FALSE]
    
    na_idx <- is.na(meta[[color_var]])
    if (any(na_idx)) {
      showNotification(paste("Removing", sum(na_idx), "samples with NA in", color_var), type = "warning")
      meta <- meta[!na_idx, , drop = FALSE]
      mat <- mat[, rownames(meta), drop = FALSE]
    }
    
    pca <- prcomp(t(mat), center = TRUE, scale. = TRUE)
    pca_df <- as.data.frame(pca$x[, 1:2])
    colnames(pca_df) <- c("PC1", "PC2")
    var_exp <- round(summary(pca)$importance[2, 1:2] * 100, 2)
    
    pca_df[[color_var]] <- meta[[color_var]]
    
    grupos <- unique(pca_df[[color_var]])
    grupos <- grupos[!is.na(grupos)]
    color_map <- sapply(grupos, function(g) {
      input[[paste0("pca_color_", g)]]
    })
    names(color_map) <- as.character(grupos)
    
    # Base plot without title
    p <- ggplot(pca_df, aes(x = PC1, y = PC2, color = .data[[color_var]])) +
      geom_point(size = input$pcaPointSize) +
      scale_color_manual(values = color_map) +
      labs(
        x = paste0("PC1 (", var_exp[1], "%)"),
        y = paste0("PC2 (", var_exp[2], "%)"),
        color = color_var
      ) +
      theme_classic(base_size = input$pcaFontSize)
    
    if (input$pcaBold) {
      p <- p + theme(
        axis.title = element_text(face = "bold")
      )
    }
    
    if (input$pcaEllipse && length(unique(pca_df[[color_var]])) > 1) {
      conf <- input$pcaEllipseConf / 100
      p <- p + stat_ellipse(level = conf, aes(group = .data[[color_var]]))
    }
    
    if (input$pcaLabels) {
      p <- p + geom_text_repel(aes(label = rownames(pca_df)), size = input$pcaFontSize/3, show.legend = FALSE)
    }
    
    # ---- PERMANOVA annotation with Unicode (no parse=TRUE) ----
    if (!is.null(values$permanovaRes)) {
      res <- values$permanovaRes
      if (is.data.frame(res) || is.matrix(res)) {
        r2 <- round(res[1, "R2"], 4)
        pval <- res[1, "Pr(>F)"]
        if (!is.na(r2) && !is.na(pval)) {
          # Format p-value for display
          if (pval < 0.001) {
            p_label <- "< 0.001"
          } else if (pval < 0.01) {
            p_label <- "< 0.01"
          } else if (pval < 0.05) {
            p_label <- "< 0.05"
          } else {
            p_label <- paste("=", round(pval, 3))
          }
          # Use Unicode superscript 2 for r²
          annot_text <- paste0("PERMANOVA: r\u00B2 = ", r2, ", p ", p_label)
          p <- p + annotate("text", x = -Inf, y = Inf, 
                            label = annot_text,
                            hjust = -0.1, vjust = 1.1, 
                            size = input$pcaFontSize/3, 
                            fontface = ifelse(input$pcaBold, "bold", "plain"))
        }
      }
    } else {
      p <- p + annotate("text", x = -Inf, y = Inf, label = "PERMANOVA not run",
                        hjust = -0.1, vjust = 1.1, size = input$pcaFontSize/3, color = "gray40")
    }
    
    values$pcaPlot <- p
    output$pcaIntegratedPlot <- renderPlot({
      p
    }, width = input$pcaWidth, height = input$pcaHeight, res = 100)
    
    showNotification("PCA plot generated successfully.", type = "message")
  })
  
  output$downloadPcaPNG <- downloadHandler(
    filename = function() "PCA_integrated.png",
    content = function(file) {
      req(values$pcaPlot)
      ggsave(file, plot = values$pcaPlot, width = input$pcaWidth/100, height = input$pcaHeight/100, dpi = 300)
    }
  )
  
  # ----------------------------------------------------------------------------
  # Report
  # ----------------------------------------------------------------------------
  
  output$reportOutput <- renderPrint({
    cat("ANALYSIS REPORT\n")
    cat("================\n\n")
    
    cat("DATA SUMMARY\n")
    cat("-------------\n")
    if (!is.null(values$exprMatrix)) {
      cat("Expression matrix:", dim(values$exprMatrix)[1], "genes/transcripts,",
          dim(values$exprMatrix)[2], "samples.\n")
    } else {
      cat("No expression matrix loaded.\n")
    }
    if (!is.null(values$metaData)) {
      cat("Metadata:", dim(values$metaData)[1], "samples,", dim(values$metaData)[2], "variables.\n")
    } else {
      cat("No metadata loaded.\n")
    }
    if (!is.null(values$transformedExpr)) {
      cat("Transformation applied:", input$transformMethod, "\n")
    }
    cat("\n")
    
    if (!is.null(values$currentDimRed)) {
      cat("DIMENSIONALITY REDUCTION\n")
      cat("------------------------\n")
      cat("Method:", input$dimMethod, "\n")
      cat("Distance metric:", input$distMethod, "\n")
      cat("Random seed:", input$dimSeed, "\n")
      if (input$dimMethod == "tsne") cat("Perplexity:", input$dimPerplexity, "\n")
      if (input$dimMethod == "umap") cat("Neighbors:", input$dimNNeighbors, "\n")
      cat("\n")
    }
    
    if (!is.null(values$permanovaRes)) {
      cat("PERMANOVA\n")
      cat("---------\n")
      cat("Factor 1:", input$permanovaFactor1, "\n")
      if (input$permanovaFactor2 != "" && input$permanovaFactor2 != "None") {
        cat("Factor 2:", input$permanovaFactor2, "\n")
      }
      if (input$permanovaFactor3 != "" && input$permanovaFactor3 != "None") {
        cat("Factor 3:", input$permanovaFactor3, "\n")
      }
      cat("Interactions:", ifelse(input$permanovaInteractions, "Yes", "No"), "\n")
      cat("Permutations:", input$permanovaPermutations, "\n")
      cat("Strata:", ifelse(input$permanovaStrata != "" && input$permanovaStrata != "None", input$permanovaStrata, "None"), "\n")
      cat("Pairwise:", ifelse(input$permanovaPairwise, "Yes", "No"), "\n")
      if (input$permanovaPairwise) cat("FDR for pairwise:", input$permanovaFDR, "\n")
      cat("\nPERMANOVA table:\n")
      print(values$permanovaRes)
      cat("\n")
    }
    
    if (!is.null(values$betadisperRes)) {
      cat("BETADISPER (homogeneity of dispersion)\n")
      cat("--------------------------------------\n")
      betad <- values$betadisperRes
      cat("Factor:", input$assumptionFactor, "\n")
      cat("ANOVA p-value:", anova(betad)$`Pr(>F)`[1], "\n")
      cat("Permutest p-value:", permutest(betad)$`Pr(>F)`[1], "\n")
      cat("\n")
    }
    
    if (!is.null(values$permanovaPairwise)) {
      cat("PAIRWISE COMPARISONS\n")
      cat("--------------------\n")
      print(values$permanovaPairwise)
      cat("\n")
    }
    
    cat("================\n")
    cat("Report generated on", Sys.time(), "\n")
  })
  
  output$downloadReportText <- downloadHandler(
    filename = "analysis_report.txt",
    content = function(file) {
      report_text <- capture.output({
        cat("ANALYSIS REPORT\n")
        cat("================\n\n")
        cat("DATA SUMMARY\n")
        cat("-------------\n")
        if (!is.null(values$exprMatrix)) {
          cat("Expression matrix:", dim(values$exprMatrix)[1], "genes/transcripts,",
              dim(values$exprMatrix)[2], "samples.\n")
        } else {
          cat("No expression matrix loaded.\n")
        }
        if (!is.null(values$metaData)) {
          cat("Metadata:", dim(values$metaData)[1], "samples,", dim(values$metaData)[2], "variables.\n")
        } else {
          cat("No metadata loaded.\n")
        }
        if (!is.null(values$transformedExpr)) {
          cat("Transformation applied:", input$transformMethod, "\n")
        }
        cat("\n")
        if (!is.null(values$currentDimRed)) {
          cat("DIMENSIONALITY REDUCTION\n")
          cat("Method:", input$dimMethod, "\n")
          cat("Distance metric:", input$distMethod, "\n")
          cat("Random seed:", input$dimSeed, "\n")
          if (input$dimMethod == "tsne") cat("Perplexity:", input$dimPerplexity, "\n")
          if (input$dimMethod == "umap") cat("Neighbors:", input$dimNNeighbors, "\n")
          cat("\n")
        }
        if (!is.null(values$permanovaRes)) {
          cat("PERMANOVA\n")
          cat("Factor 1:", input$permanovaFactor1, "\n")
          if (input$permanovaFactor2 != "" && input$permanovaFactor2 != "None") {
            cat("Factor 2:", input$permanovaFactor2, "\n")
          }
          if (input$permanovaFactor3 != "" && input$permanovaFactor3 != "None") {
            cat("Factor 3:", input$permanovaFactor3, "\n")
          }
          cat("Interactions:", ifelse(input$permanovaInteractions, "Yes", "No"), "\n")
          cat("Permutations:", input$permanovaPermutations, "\n")
          cat("Strata:", ifelse(input$permanovaStrata != "" && input$permanovaStrata != "None", input$permanovaStrata, "None"), "\n")
          cat("Pairwise:", ifelse(input$permanovaPairwise, "Yes", "No"), "\n")
          if (input$permanovaPairwise) cat("FDR for pairwise:", input$permanovaFDR, "\n")
          cat("\nPERMANOVA table:\n")
          print(values$permanovaRes)
          cat("\n")
        }
        if (!is.null(values$betadisperRes)) {
          cat("BETADISPER\n")
          cat("Factor:", input$assumptionFactor, "\n")
          betad <- values$betadisperRes
          cat("ANOVA p-value:", anova(betad)$`Pr(>F)`[1], "\n")
          cat("Permutest p-value:", permutest(betad)$`Pr(>F)`[1], "\n")
          cat("\n")
        }
        if (!is.null(values$permanovaPairwise)) {
          cat("PAIRWISE COMPARISONS\n")
          print(values$permanovaPairwise)
          cat("\n")
        }
        cat("================\n")
        cat("Report generated on", Sys.time(), "\n")
      })
      writeLines(report_text, file)
    }
  )
  
  # ----------------------------------------------------------------------------
  # Export (unchanged)
  # ----------------------------------------------------------------------------
  
  output$downloadTableCSV <- downloadHandler(
    filename = function() "results.csv",
    content = function(file) {
      if (!is.null(values$permanovaRes)) {
        write.csv(as.data.frame(values$permanovaRes), file, row.names = TRUE)
      } else {
        write.csv(data.frame(Message = "No results to export"), file)
      }
    }
  )
  
  output$downloadTableExcel <- downloadHandler(
    filename = function() "results.xlsx",
    content = function(file) {
      sheets <- list()
      if (!is.null(values$permanovaRes)) {
        sheets$PERMANOVA <- as.data.frame(values$permanovaRes)
      }
      if (!is.null(values$permanovaPairwise)) {
        sheets$Pairwise <- values$permanovaPairwise
      }
      if (length(sheets) == 0) {
        sheets$Message <- data.frame(Message = "No results")
      }
      write_xlsx(sheets, file)
    }
  )
  
  output$downloadPlotExport <- downloadHandler(
    filename = function() {
      paste0("plot.", input$exportPlotFormat)
    },
    content = function(file) {
      req(values$currentPlot)
      ggsave(file, plot = values$currentPlot, dpi = input$exportDPI, width = 8, height = 6)
    }
  )
  
  output$downloadScript <- downloadHandler(
    filename = "reproducible_script.R",
    content = function(file) {
      script <- c(
        "# Reproducible script generated by Transcriptomics Explorer",
        "# Date:", Sys.Date(),
        "# Load libraries...",
        "library(vegan); library(ggplot2); library(DESeq2); ...",
        "# Data loaded manually or from file",
        "# ... (specific options would be written here)"
      )
      writeLines(script, file)
    }
  )
  
  output$downloadReport <- downloadHandler(
    filename = "report.html",
    content = function(file) {
      rmd_content <- c(
        "---",
        "title: 'Transcriptomics Analysis Report'",
        "output: html_document",
        "---",
        "",
        "## Summary",
        "This report was automatically generated by Transcriptomics Explorer.",
        "",
        "### Data",
        "Expression matrix:", nrow(values$transformedExpr), "genes,", ncol(values$transformedExpr), "samples.",
        "",
        "### PERMANOVA Results",
        if (!is.null(values$permanovaRes)) {
          c("```{r echo=FALSE}", "knitr::kable(as.data.frame(values$permanovaRes))", "```")
        } else { "PERMANOVA not run." },
        "",
        "### Plots",
        "Include exported plots."
      )
      writeLines(rmd_content, "temp_report.Rmd")
      rmarkdown::render("temp_report.Rmd", output_file = file)
      unlink("temp_report.Rmd")
    }
  )
}

# ==============================================================================
# Run the application
# ==============================================================================

shinyApp(ui, server)