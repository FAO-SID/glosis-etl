# =============================================================================
# UI.R - User Interface for GLOSIS Standardization Shiny App
# GLOSIS ISO-28258 DATABASE
# LAST UPDATE. It corrects the use of duplicated lab properties analysed by different methods
# CHANGES ION THE SCRIPT FRAMED WITH NEW
# =============================================================================
# This file contains all the reactive logic, data processing, and output
# rendering for the application. It handles file uploads, data injection and,
# dashboard generation.
# =============================================================================


# Define UI ----
ui <- fluidPage(
  useShinyjs(),
  dashboardPage(
    skin = "red",
    dashboardHeader(
      title = "GloSIS Database",
      tags$li(
        class = "dropdown",
        tags$img(
          src = "../www/fao_logo1.png",
          height = "40px",
          style = "position: absolute; right: 20px; top: 5px;"
        )
      ),
      titleWidth = 250
    ),
    dashboardSidebar(
      tags$head(
        tags$style(HTML(".main-sidebar, .left-side {background-color: #FFC527 !important;}"))
      ),
      tags$br(),
      uiOutput("db_dropdown"), # Dynamically generated dropdown menu
      actionButton("btnToggleConn", "Connect", icon = icon("plug"), width = '85%'),
      uiOutput("dynamicFileInput"), # Dynamic UI for fileInput
      tags$br(),
      
      #verbatimTextOutput("working_dir"),
      
      
      # Conditional rendering for delete-related elements
      conditionalPanel(
        # New line with the label
        tags$br(),
        tags$div(style = "padding: 10px 15px; font-weight: bold;", "CREATE A DATABASE"),
        actionButton("btn_create_db", "New Database", icon = icon("plus-circle"), width = '85%'),
        uiOutput("dbMessage"),
        uiOutput("password_modal"),  
        tags$br(),
        uiOutput("backupWarning"), # Add this line to display warnings
        uiOutput("connectionWarning"), # Add this line to display warnings
        condition = "!output.connection_opened", # Render only if no connection is open
        tags$p("DELETE SELECTED DATABASE", style = "width: 100%; padding: 10px 15px; color: white; font-weight: bold;"),
        actionButton("delete_button", "Delete", icon = icon("trash"), width = '85%', style = "color: red;")  # Delete button with red text for emphasis
      ),
      
      tags$div(
        style = "position: absolute; bottom: 0; width: 100%; padding: 10px 15px; box-sizing: border-box;",
        tags$a(
          href = "/", 
          target = "_blank", 
          class = "btn btn-warning", 
          style = "width: 100%; margin-left: auto; margin-right: auto; display: block;color: #FFFFFF;border-radius: 8px;", 
          icon("external-link-alt"), " Go to the Main Page"
        )
      )
    ),
    dashboardBody(
      tags$head(
        tags$style(
          HTML(
            "
            /* General background color for the dashboard */
            .content-wrapper { background-color: #F7F7F7 !important; }
          
            /* Ensure main tabBox and tabPanel container do not exceed the main content width */
            .box, .tabBox, .nav-tabs-custom {
              max-width: calc(100% - 30px) !important; /* Adjust to fit within the main content */
              margin: 0 auto !important; /* Center align with full width */
              padding: 0 !important; /* Remove extra padding */
            }
          
            /* Style for main tabs (top-level tabPanels) */
            .nav-tabs-custom > .nav-tabs {
              display: flex !important;
              justify-content: flex-start !important; /* Left-align top-level tabs */
              margin: 0 !important; /* Remove default margin */
              width: auto !important; /* Let it adapt to available space */
            }
          
            .nav-tabs-custom > .nav-tabs > li {
              flex: 1; /* Make each tab take equal space */
              text-align: center; /* Center-align text inside each tab */
            }
          
            .nav-tabs-custom > .nav-tabs > li > a {
              width: 100% !important; /* Make tab width consistent */
              background-color: #EAEAEA !important; /* Inactive tab background */
              color: #333333 !important; /* Inactive tab text color */
            }
          
            .nav-tabs-custom > .nav-tabs > li.active > a {
              background-color: #FF6347 !important; /* Active tabPanel color - Tomato */
              color: white !important; /* Active tabPanel text color */
            }
          
            .nav-tabs-custom > .nav-tabs > li > a:hover {
              background-color: #CCCCCC !important; /* Hover background */
              color: #333333 !important; /* Hover text color */
            }
          
            /* Style for inner tabBox */
            .tab-content {
              background-color: #FFFFFF !important; /* White background */
              padding: 10px !important; /* Small padding inside content */
              border: .5px solid #DDDDDD !important; /* Light gray border */
            }
          
            /* Ensure inner tabBox tabs are aligned and do not overflow */
            .nav-tabs {
              display: flex !important;
              justify-content: flex-start !important; /* Left-align inner tabs */
              margin: 0 !important;
              width: auto !important;
            }
          
            .nav-tabs > li {
              flex: 1; /* Each inner tab takes equal space */
              text-align: center; /* Center-align text inside each tab */
            }
          
            .nav-tabs > li > a {
              width: 100% !important;
              background-color: #EAEAEA !important; /* Inactive inner tab background */
              color: #333333 !important; /* Inactive inner tab text color */
            }
          
            .nav-tabs > li.active > a {
              background-color: #FFA07A !important; /* Active tabBox color - Light Salmon */
              color: white !important; /* Active tabBox text color */
            }
          
            .nav-tabs > li > a:hover {
              background-color: #CCCCCC !important; /* Hover background for inner tabs */
              color: #333333 !important; /* Hover text color */
            }
          
            /* Spinner customization */
            .shiny-spinner-output-container {
              background-color: #F9F9F9 !important;
            }
            "
          )
        )
      ),
      
      tabBox(
        id = "mainTabs",
        width = 12,
        
        # Project and Site Group
        tabPanel(title =tagList("Project & Site", icon("image")),
                 tabBox(
                   id = "projectSiteTabs",
                   width = 12,
                   tabPanel("Project", DTOutput("viewProject") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Site", DTOutput("viewSite") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Site Project", DTOutput("viewSite_project") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Project Related", DTOutput("viewProject_related") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3))
                 )
        ),
        
        # Plot Group
        tabPanel(title =tagList("Plot", icon("map")),
                 tabBox(
                   id = "plotTabs",
                   width = 12,
                   tabPanel("Plot", DTOutput("viewPlot") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Plot individual", DTOutput("viewPlot_individual") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Property Desc", DTOutput("viewProperty_desc_plot") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Observation Desc Plot", DTOutput("viewObservation_desc_plot") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Category Desc", DTOutput("viewThesaurus_desc_plot") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Result Desc Plot", DTOutput("viewResult_desc_plot") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3))
                 )
        ),
        
        # Surface Group
        tabPanel(title =tagList("Surface", icon("route")),
                 tabBox(
                   id = "surfaceTabs",
                   width = 12,
                   tabPanel("Surface", DTOutput("viewSurface") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Surface Individual", DTOutput("viewSurface_individual") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Result Desc Surface", DTOutput("viewResult_desc_surface") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3))
                 )
        ),
        
        # Profile Group
        tabPanel(title =tagList("Profile", icon("layer-group")),
                 tabBox(
                   id = "profileTabs",
                   width = 12,
                   tabPanel("Profile", DTOutput("viewProfile") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Observation Desc Profile", DTOutput("viewObservation_desc_profile") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Result Desc Profile", DTOutput("viewResult_desc_profile") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3))
                 )
        ),
        
        # Element Group
        tabPanel(title =tagList("Element", icon("arrows-up-down")),
                 tabBox(
                   id = "elementTabs",
                   width = 12,
                   tabPanel("Element", DTOutput("viewElement") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Observation Desc Element", DTOutput("viewObservation_desc_element") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Result Desc Element", DTOutput("viewResult_desc_element") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3))
                 )
        ),
        
        # Specimen Group
        tabPanel(title =tagList("Specimen", icon("sack-xmark")),
                 tabBox(
                   id = "specimenTabs",
                   width = 12,
                   tabPanel("Specimen", DTOutput("viewSpecimen") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Specimen Preparation Process", DTOutput("viewSpecimen_prep_process") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Specimen Transport", DTOutput("viewSpecimen_transport") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Specimen Storage", DTOutput("viewSpecimen_storage") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Result Phys Chem", DTOutput("viewResult_phys_chem") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3))
                 )
        ),
        
        # Physical and Chemical Properties and Measurements Group
        tabPanel(title =tagList("Lab Descriptors", icon("flask-vial")),
                 tabBox(
                   id = "physChemTabs",
                   width = 12,
                   tabPanel("Observation Phys Chem", DTOutput("viewObservation_phys_chem") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Property Phys Chem", DTOutput("viewProperty_phys_chem") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Procedure Phys Chem", DTOutput("viewProcedure_phys_chem") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Unit of Measure", DTOutput("viewUnit_of_measure") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3))
                 )
        ),
        
        # Spectral Analysis Group
        tabPanel(title =tagList("Spectral Data", icon("think-peaks")),
                 tabBox(
                   id = "spectralTabs",
                   width = 12,
                   tabPanel("Sensor", DTOutput("viewResult_spectral") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3))
                 )
        ),
        
        # VCard Specification Group
        tabPanel(title =tagList("VCard ", icon("person")),  # Add the icon and label together
                 tabBox(
                   id = "vcardTabs",
                   width = 12,
                   tabPanel("Organisation", DTOutput("viewOrganisation") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Organisation Unit", DTOutput("viewOrganisation_unit") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Organisation Individual", DTOutput("viewOrganisation_individual") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Individual", DTOutput("viewIndividual") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3)),
                   tabPanel("Address", DTOutput("viewAddress") %>% withSpinner(color = "#0275D8", color.background = "#ffffff", size = .6, type = 3))
                 )
        )
      )
    )
  )
)
