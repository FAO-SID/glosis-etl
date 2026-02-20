# GLOSIS DATABASE VIEWER
# load libraries
library(shiny)
library(DBI)
library(dplyr)
library(tidyr)
library(RPostgres)
library(shinythemes)
library(shinydashboard)
library(DT)
library(leaflet)
library(reactable)
library(reactablefmtr)
library(crosstalk)
library(shinycssloaders)

# Load credentials for the docker database container
source("/srv/shiny-server/init-scripts/credentials.R")

# Define UI
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(
    title = "GloSIS Database Viewer",
    tags$li(
      class = "dropdown",
      tags$img(
        src = "../www/fao_logo1.png",
        height = "40px",
        style = "position: absolute; right: 20px; top: 5px;"
      )
    ),
    titleWidth = 300
  ),
  dashboardSidebar(
    width = 300,
    sidebarMenu(
      id = "inputdata",
      menuItem(
        "Database Connection",
        tabName = "connect-db",
        icon = icon("database"),
        startExpanded = TRUE,
        uiOutput("db_dropdown"),
        actionButton("connect_button", "Connect to Database", icon = icon("plug"), width = "85%")
      ),
      tags$br(),
      uiOutput("credits"),
      tags$br(),
      tags$div(
        style = "position: absolute; bottom: 0; left: 0; right: 0; padding: 10px 15px; box-sizing: border-box;",
        tags$a(
          href = "/",
          target = "_blank",
          class = "btn btn-warning",
          style = "width: 100%; display: block; color: #FFFFFF; border-radius: 8px;",
          icon("external-link-alt"), " Go to the Main Page"
        )
      )
    )
  ),
  dashboardBody(
    tags$head(
      tags$style(HTML(
        ".shiny-output-error { visibility: hidden; }\n",
        ".shiny-output-error:before { visibility: hidden; }\n",
        ".content-wrapper, .right-side { background-color: #f4f6f9; }\n",
        ".small-box, .box { border-radius: 6px; }\n",
        ".leaflet { min-height: 620px !important; }\n",
        ".property-help { margin-bottom: 6px; color: #666; font-size: 12px; }\n",
        ".leaflet-bar a.active { background-color: #3c8dbc !important; color: #fff !important; }\n",
        ".reactable .rt-td { transition: background-size 220ms ease, background-color 220ms ease, color 180ms ease; }\n",
        ".reactable .rt-tr-group { transition: opacity 180ms ease; }"
      ))
    ),
    fluidRow(
      box(
        width = 4,
        title = "Soil Profile Selection",
        status = "primary",
        solidHeader = TRUE,
        withSpinner(
          leafletOutput("map", height = 620),
          type = 3,
          color = "#3c8dbc",
          color.background = "#ffffff",
          size = 0.4
        )
      ),
      box(
        width = 8,
        title = "Vertical Distribution of Soil Properties",
        status = "primary",
        solidHeader = TRUE,
        div(class = "property-help", "Select one or more properties to compare property variation with depth."),
        uiOutput("hist_select_vars"),
        withSpinner(
          reactableOutput("histogram_table", height = 520),
          type = 3,
          color = "#3c8dbc",
          color.background = "#ffffff",
          size = 0.4
        )
      )
    ),
    fluidRow(
      box(
        width = 12,
        title = "Soil Locations",
        status = "primary",
        solidHeader = TRUE,
        withSpinner(
          DTOutput("data_table"),
          type = 3,
          color = "#3c8dbc",
          color.background = "#ffffff",
          size = 0.4
        )
      )
    )
  )
)
