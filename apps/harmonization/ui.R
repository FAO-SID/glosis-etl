# =============================================================================
# UI.R - User Interface Definition for GLOSIS Harmonization Shiny App
# =============================================================================
# This file defines the visual layout and input controls for the application.
# The app uses shinydashboard framework with a sidebar for inputs and main
# body for data display and quality checks.
# =============================================================================
# =============================================================================
# BOX STATUS COLORS SUMMARY
# =============================================================================
# The 'status' parameter in box() determines the header color:
#
# status = "primary"   → BLUE (#3c8dbc)      - General information, neutral
# status = "success"   → GREEN (#00a65a)     - Positive status, success
# status = "info"      → LIGHT BLUE (#00c0ef)- Informational content
# status = "warning"   → YELLOW/ORANGE (#f39c12) - Warnings, caution
# status = "danger"    → RED (#dd4b39)       - Critical issues, errors
#
# The skin = "red" parameter sets the overall theme color for:
# - Dashboard header background
# - Active menu items in sidebar
# - Progress bars
# - Primary buttons
# =============================================================================

# Load libraries
library(shiny)
library(shinydashboard)
library(dplyr)
library(openxlsx)
library(DT)
library(readxl)
library(lubridate)

# ---------- UI ----------
ui <- dashboardPage(
  skin = "red",
  
  dashboardHeader(
    title = "GloSIS Harmonization",
    tags$li(
      class = "dropdown",
      # tags$img(
      #   src = "../www/fao_logo1.png",
      #   height = "40px",
      #   style = "position: absolute; right: 20px; top: 5px;"
      # )
    ),
    titleWidth = 460
  ),
  
  dashboardSidebar(
    tags$head(
      tags$style(HTML("
        .main-sidebar, .left-side { width: 300px !important; background-color: #FFC527 !important; }
        .content-wrapper, .right-side, .main-footer { 
           margin-left: 300px !important;
           background-color: #F7F7F7 !important;
        }
        .main-header .logo {
           width: 300px !important;
        }
        .main-header .navbar {
           margin-left: 300px !important;
        }
        .sidebar-menu > li > a { font-weight: 700; }
        .box { border-top: 3px solid #b30000 !important; }
        
        .soil-card{
          padding:10px;
          background:#fff;
          border:1px solid #ddd;
          border-radius:10px;
          margin-bottom:12px;
          box-shadow: 0 1px 2px rgba(0,0,0,0.06);
          border-left: 6px solid #3477c9;
        }
        .soil-card-title{
          font-weight:800;
          margin-bottom:8px;
          display:flex;
          align-items:center;
          gap:8px;
        }
        .soil-chip{
          display:inline-block;
          font-weight:700;
          padding:2px 8px;
          border-radius:999px;
          background:#f2f2f2;
          border:1px solid #ddd;
        }
        .soil-method-note{
          margin-top:8px;
          padding:8px 10px;
          background:#f7f7f7;
          border-left:4px solid #b30000;
          border-radius:6px;
        }
        .soil-method-note-label{
          font-weight:800;
          margin-right:6px;
        }
        .soil-method-note-text{
          opacity:.9;
        }
        .conversion-notice {
          margin-top: 8px;
          padding: 8px 10px;
          background: #fff3cd;
          border-left: 4px solid #ffc107;
          border-radius: 6px;
          font-weight: 600;
          font-size: 12px;
          color: #856404;
        }
        .soil-reference-unit {
          margin-top: 8px;
          padding: 6px 10px;
          background: #e3f2fd;
          border-left: 4px solid #1976d2;
          border-radius: 4px;
          font-size: 13px;
        }
      "))
    ),
    
    sidebarMenu(
      menuItem("Converter", tabName = "converter", icon = icon("file-arrow-up"))
    ),
    
    tags$hr(style = "border-top: 1px solid rgba(0,0,0,0.15);"),
    
    div(
      style = "padding: 0 12px;",
      
      # SECTION 1: Data Upload ----
      tags$strong(style = "color:#4f4f4f;","1) Upload your data (CSV or XLSX)"),
      fileInput("data_file", NULL, accept = c(".csv", ".xlsx", ".xls")),
      uiOutput("xlsx_sheet_ui"),
      
      # SECTION 2: Glosis template ----
      # tags$strong(style = "color:#4f4f4f;","2) Select Glosis Template (optional)"),
      # uiOutput("template_label"),
      # tags$br(),
      
      # SECTION 3: Project Settings ----
      #tags$strong(style = "color:#4f4f4f;","3) Configure Project Settings"),
      tags$strong(style = "color:#4f4f4f;","2) Configure Project Settings"),
      tags$br(),
      tags$br(),
      
      # Project name group
      tags$div(
        style = "background: rgba(255,255,255,.3); padding: 8px; border-radius: 6px; margin-bottom: 12px;",
        tags$div(
          style = "font-weight: 700; margin-bottom: 4px; font-size: 13px; color: #ffffff;",
          "Project name"
        ),
        tags$div(
          style = "margin-bottom: 0px;",
          checkboxInput("use_project_col", "Use 'Project name' from data", value = FALSE)
        ),
        tags$small(
          "Check this box if your 'Project name' is in your input data.",
          style = "display:block; opacity:.8; margin-top: -10px; margin-bottom: 8px;"
        ),
        conditionalPanel(
          condition = "input.use_project_col == false",
          textInput("project_name", NULL, value = "MyProject", placeholder = "Enter project name")
        ),
        conditionalPanel(
          condition = "input.use_project_col == true",
          uiOutput("project_col_selector")
        )
      ),
      
      # Site code group
      tags$div(
        style = "background: rgba(255,255,255,.3); padding: 8px; border-radius: 6px; margin-bottom: 12px;",
        tags$div(
          style = "font-weight: 700; margin-bottom: 4px; font-size: 13px; color: #ffffff;",
          "Site code"
        ),
        tags$div(
          style = "margin-bottom: 6px;",
          checkboxInput("use_site_col", "Use 'Site code' from data", value = FALSE),
          tags$small("Check this box if your 'Site code' is in your input data.",
                     style = "display:block; opacity:.8;"),
        ),
        conditionalPanel(
          condition = "input.use_site_col == false",
          textInput("site_code", NULL, value = "MySite", placeholder = "Enter site code")
        ),
        conditionalPanel(
          condition = "input.use_site_col == true",
          uiOutput("site_col_selector")
        )
      ),
      
      # Date group
      tags$div(
        style = "background: rgba(255,255,255,.3); padding: 8px; border-radius: 6px; margin-bottom: 12px;",
        tags$div(
          style = "font-weight: 700; margin-bottom: 4px; font-size: 13px; color: #ffffff;",
          "Date"
        ),
        tags$div(
          style = "margin-bottom: 6px;",
          checkboxInput("use_date_col", "Use 'Date' from data", value = FALSE),
          tags$small("Check this box if your 'Date' is in your input data.",
                     style = "display:block; opacity:.8;"),
        ),
        conditionalPanel(
          condition = "input.use_date_col == false",
          textInput("date_manual", NULL, value = as.character(Sys.Date()), placeholder = "YYYY-MM-DD"),
          tags$small("Format: YYYY-MM-DD (e.g., 2025-12-21). Year-only (e.g., 2025) will be converted to 2025-01-01.",
                     style = "display:block; opacity:.8; margin-top: -10px;")
        ),
        conditionalPanel(
          condition = "input.use_date_col == true",
          uiOutput("date_col_selector")
        )
      ),
      
      # Profile code group
      tags$div(
        style = "background: rgba(255,255,255,.3); padding: 8px; border-radius: 6px; margin-bottom: 12px;",
        tags$div(
          style = "font-weight: 700; margin-bottom: 4px; font-size: 13px; color: #ffffff;",
          "Profile code"
        ),
        tags$div(
          style = "margin-bottom: 6px;",
          checkboxInput("use_profile_col", "Use 'Profile code' from data", value = FALSE),
          tags$small("Check this box if your 'Profile code' is in your input data.",
                     style = "display:block; opacity:.8;"),
        ),
        conditionalPanel(
          condition = "input.use_profile_col == false",
          tags$small("Profile codes will be auto-generated as 'profile_1', 'profile_2', etc.",
                     style = "display:block; opacity:.8; font-style: italic;")
        ),
        conditionalPanel(
          condition = "input.use_profile_col == true",
          uiOutput("profile_col_selector")
        )
      ),
      
      # Plot code + Plot type
      tags$div(
        style = "background: rgba(255,255,255,.3); padding: 8px; border-radius: 6px; margin-bottom: 12px;",
        
        # --- Plot code section ---
        tags$div(
          style = "font-weight: 700; margin-bottom: 4px; font-size: 13px; color: #ffffff;",
          "Plot code"
        ),
        tags$div(
          style = "margin-bottom: 6px;",
          checkboxInput("use_plot_col", "Use 'Plot code' from data", value = FALSE),
          tags$small(
            "Check this box if your 'Plot code' is in your input data.",
            style = "display:block; opacity:.8;"
          )
        ),
        conditionalPanel(
          condition = "input.use_plot_col == false",
          tags$small(
            "Plot codes will be auto-generated as 'plot_1', 'plot_2', etc.",
            style = "display:block; opacity:.8; font-style: italic;"
          )
        ),
        conditionalPanel(
          condition = "input.use_plot_col == true",
          uiOutput("plot_col_selector")
        ),
        
        # divider inside the same group
        tags$hr(style = "margin: 10px 0; border-top: 1px solid rgba(255,255,255,0.25);"),
        
        # --- Plot type section ---
        tags$div(
          style = "font-weight: 700; margin-bottom: 4px; font-size: 13px; color: #ffffff;",
          "Plot type"
        ),
        tags$div(
          style = "margin-bottom: 6px;",
          selectInput(
            "plot_type",
            NULL,
            choices = c("Borehole", "TrialPit", "Surface"),
            selected = "TrialPit"
          )
        ),
        tags$small(
          "Choose the plot type used in the template.",
          style = "display:block; opacity:.8;"
        )
      ),
      
      
      # Horizon group: Horizon ID column (optional) + Horizon type
      tags$div(
        style = "background: rgba(255,255,255,.3); padding: 8px; border-radius: 6px; margin-bottom: 12px;",
        
        tags$div(
          style = "font-weight: 700; margin-bottom: 4px; font-size: 13px; color: #ffffff;",
          "Horizon ID"
        ),
        
        # Ask if Horizon ID is in the data
        tags$div(
          style = "margin-bottom: 6px;",
          checkboxInput("use_hor_col", "Use 'Horizon ID' from data", value = FALSE),
          tags$small(
            "Check this box if your Horizon ID/code is stored in a column in your input data.",
            style = "display:block; opacity:.8;"
          )
        ),
        
        # If not using a column, explain behavior (you can adjust text)
        conditionalPanel(
          condition = "input.use_hor_col == false",
          tags$small(
            "Horizon codes will be taken from the selected Horizon type logic or left empty (depending on your export rules).",
            style = "display:block; opacity:.8; font-style: italic;"
          )
        ),
        
        # If using a column, show selector
        conditionalPanel(
          condition = "input.use_hor_col == true",
          tags$div(
            style = "font-weight: 700; margin: 10px 0 4px 0; font-size: 13px; color: #ffffff;",
            "Horizon ID column"
          ),
          tags$div(
            style = "margin-bottom: 6px;",
            uiOutput("hor_col_selector")
          )
        ),
        
        tags$hr(style = "margin: 10px 0; border-top: 1px solid rgba(255,255,255,0.25);"),
        
        # Horizon type (always asked, in same group)
        tags$div(
          style = "font-weight: 700; margin-bottom: 4px; font-size: 13px; color: #ffffff;",
          "Horizon type"
        ),
        tags$div(
          style = "margin-bottom: 6px;",
          selectInput(
            "horizon_type",
            NULL,
            choices = c("Horizon", "Layer"),
            selected = "Horizon"
          )
        ),
        tags$small(
          "Choose whether your depth intervals represent Horizons or Layers.",
          style = "display:block; opacity:.8;"
        )
      ),
      
      
      tags$hr(),
      
      # SECTION 4: Map Properties ----
      #tags$strong(style = "color:#4f4f4f;", "4) Map fields"),
      tags$strong(style = "color:#4f4f4f;", "3) Map Plot Parameters"),
      tags$br(),
      tags$br(),
      
      tags$div(
        style = "background: rgba(255,255,255,.3); padding: 8px; border-radius: 6px; margin-bottom: 12px;",
        uiOutput("col_selectors"),
      ),
      
      tags$hr(),
      
      # SECTION 5: Export as filled template -----
      #tags$strong(style = "color:#4f4f4f;","5) Export Harmonized Data"),
      tags$strong(style = "color:#4f4f4f;","4) Download Harmonized Data"),
      tags$br(),
      tags$br(),
      
      tags$div(
        style = "background: rgba(255,255,255,.3); padding: 8px; border-radius: 6px; margin-bottom: 12px;",
        
        # Helper text above buttons
        tags$div(
          style = "font-weight: 700; font-size: 13px; color:#4f4f4f; margin-bottom: 8px; line-height: 1.4;",
          "Step 1: Click on 'Generate XLSX'.", tags$br(),
          "Step 2: When it finishes, the download button will appear."
        ),
        
        actionButton("prepare_xlsx", "Generate XLSX",
                     class = "btn btn-primary",
                     icon = icon("cogs"),
                     style = "width: 100%; font-weight: 800; margin-left: 0px; margin-bottom: 10px;"),
        uiOutput("download_xlsx_ui")
      ),
      tags$br(), tags$br(),
      uiOutput("download_hint"),
      tags$div(
        style = "position: absolute; bottom: 0; left: 0; right: 0; padding: 10px 15px; box-sizing: border-box;",
        tags$a(
          href = "/", 
          target = "_blank", 
          class = "btn btn-warning", 
          style = "width: 100%; margin-left: auto; margin-right: auto; display: block;color: #FFFFFF;border-radius: 8px;", 
          icon("external-link-alt"), " Go to the Main Page"
        )
      )
    )
  ),
  
  dashboardBody(
    tags$head(
      tags$style(HTML("
        /* Force DT scroll header alignment */
        .dataTables_scrollHeadInner { width: 100% !important; }
        .dataTables_scrollHeadInner table { width: 100% !important; margin: 0 !important; }
        .dataTables_scrollBody table { width: 100% !important; margin: 0 !important; }
        div.dataTables_scrollHead table.dataTable { margin-bottom: 0 !important; }
        div.dataTables_scrollBody table.dataTable { margin-top: 0 !important; }
      ")),
      tags$script(HTML("
        // Adjust all visible DT tables when a bootstrap tab becomes visible
        $(document).on('shown.bs.tab', 'a[data-toggle=\"tab\"]', function () {
          setTimeout(function() {
            $($.fn.dataTable.tables({ visible: true, api: true }))
              .columns.adjust()
              .responsive.recalc();
          }, 120);
        });

        // Allow server to request an adjust for a specific table
        Shiny.addCustomMessageHandler('dt_adjust_one', function(msg){
          var id = msg.id;
          setTimeout(function() {
            if ($.fn.dataTable.isDataTable('#' + id)) {
              $('#' + id).DataTable()
                .columns.adjust()
                .responsive.recalc();
            }
          }, 150);
        });

        // Adjust on window resize
        $(window).on('resize', function() {
          setTimeout(function() {
            $($.fn.dataTable.tables({ visible: true, api: true }))
              .columns.adjust();
          }, 150);
        });
      "))
    ),
    
    tabItems(
      tabItem(
        tabName = "converter",
        
        tabBox(
          width = 12,
          id = "mainTabs",
          
          tabPanel(
            title = tagList(icon("file-arrow-up"), "Converter"),
            value = "converter_tab",
            
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("list-check"), "What this app does:"),
                tagList("This app helps organize soil data for harmonization in the GloSIS database. Users upload a soil dataset and download a harmonized .xlsx file ready to be ingested into the GloSIS database. The app also identifies potential errors in the dataset."),
                tags$hr(style = "border-top: 1px solid rgba(0,0,0,0.15);"),
                tagList(tags$strong( icon("list-check"), "How to use:")),
                tags$ol(
                  tags$li("Upload your soil data as .CSV or .XLSX (choose sheet if XLSX)."),
                  #tags$li("Select the template (optional – otherwise default template is used)."),
                  tags$li("Configure project settings (project name, site code, date, profile/plot codes)."),
                  tags$li("Map lon/lat + required columns (sample ID / top-bottom depth)."),
                  tags$li("Select soil properties columns."),
                  tags$li("Map each soil property to property/method/unit using GloSIS standards."),
                  tags$li("Add metadata if needed (Metadata tab)."),
                  tags$li("Download the populated GloSIS template XLSX.")
                )
              )
            ),
            
            fluidRow(
              box(
                width = 7, status = "primary", solidHeader = TRUE,
                title = tagList(icon("table"), "Data Preview"),
                DTOutput("preview_dt")
              ),
              box(
                width = 5, status = "warning", solidHeader = TRUE,
                title = tagList(icon("circle-info"), "Status & Checks"),
                verbatimTextOutput("status"),
                tags$hr(),
                uiOutput("validation_panel"),
                tags$hr(),
                uiOutput("qc_panel")
              )
            ),
            
            fluidRow(
              box(
                width = 12, status = "info", solidHeader = TRUE,
                title = tagList(icon("flask"), "Identify the GLOSIS reference property name/analytical method/unit for each soil property in your input data"),
                uiOutput("procedures_mapping_ui")
              )
            )
          ),
          
          tabPanel(
            title = tagList(icon("shield-halved"), "Quality checks"),
            value = "qc_tab",
            
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("exclamation-triangle"), "Non-numeric coordinates (lon/lat)"),
                DTOutput("qc_non_numeric_coords_dt")
              )
            ),
            
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("exclamation-triangle"), "Non-numeric depth (top/bottom)"),
                DTOutput("qc_non_numeric_depth_dt")
              )
            ),
            
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("exclamation-triangle"), "Non-numeric soil property values"),
                DTOutput("qc_non_numeric_props_dt")
              )
            ),
            
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("copy"), "Duplicates (by Sample ID)"),
                DTOutput("qc_duplicates_dt")
              )
            ),
            fluidRow(
              box(
                width = 12, status = "warning", solidHeader = TRUE,
                title = tagList(icon("location-dot"), "Missing/Invalid coordinates (lon/lat)"),
                DTOutput("qc_missing_coords_dt")
              )
            ),
            fluidRow(
              box(
                width = 12, status = "warning", solidHeader = TRUE,
                title = tagList(icon("ruler-vertical"), "Missing depth (top/bottom)"),
                DTOutput("qc_missing_depth_dt")
              )
            ),
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("triangle-exclamation"), "Invalid depth (bottom ≤ top)"),
                DTOutput("qc_bad_depth_dt")
              )
            ),
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("calendar"), "Invalid dates"),
                DTOutput("qc_invalid_dates_dt")
              )
            ),
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("code-branch"), "Invalid profile_code format"),
                DTOutput("qc_invalid_profile_code_dt")
              )
            ),
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("map-pin"), "Inconsistent profile_code per coordinate group"),
                DTOutput("qc_profile_inconsistent_dt")
              )
            ),
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("code-branch"), "Invalid plot_code format"),
                DTOutput("qc_invalid_plot_code_dt")
              )
            ),
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("map-pin"), "Inconsistent plot_code per coordinate group"),
                DTOutput("qc_plot_inconsistent_dt")
              )
            ),
            fluidRow(
              box(
                width = 12, status = "danger", solidHeader = TRUE,
                title = tagList(icon("flask"), "Out-of-range soil properties (min/max from procedures)"),
                DTOutput("qc_out_of_range_dt")
              )
            )
          ),
          
          tabPanel(
            title = tagList(icon("address-card"), "Metadata"),
            value = "metadata_tab",
            fluidRow(
              box(
                width = 12, status = "info", solidHeader = TRUE,
                title = tagList(icon("pen-to-square"), "Edit Metadata (cell editing enabled)"),
                tags$p("Edit the metadata table below. Empty fields will be filled with 'unknown' in the export."),
                DTOutput("metadata_edit_dt")
              )
            )
          ),
          tabPanel(
            title = tagList(icon("magnifying-glass"), "Procedures reference"),
            value = "procedures_ref_tab",
            fluidRow(
              box(
                width = 12, status = "primary", solidHeader = TRUE,
                title = tagList(icon("table"), "glosis_procedures.csv (inspect)"),
                DTOutput("procedures_dt")
              )
            )
          )
        )
      )
    )
  )
)
