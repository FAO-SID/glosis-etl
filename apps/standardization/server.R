# =============================================================================
# SERVER.R - Server Logic for GLOSIS Standardization Shiny App
# GLOSIS ISO-28258 DATABASE
# LAST UPDATE. It corrects the use of duplicated lab properties analysed by different methods
# CHANGES ION THE SCRIPT FRAMED WITH NEW
# =============================================================================
# This file contains all the reactive logic, data processing, and output
# rendering for the application. It handles file uploads, data injection and,
# dashboard generation.
# =============================================================================


# Define server logic ----
server <- function(input, output, session) {
  source("fill_tables.R")  # Place this outside of your observeEvent or server function
  # Read GloSIS procedures file
  procedures <- read.csv("https://raw.githubusercontent.com/FAO-SID/GloSIS/main/glosis-db/versions/glosis_procedures.csv", header = TRUE)

  # Function to render the database dropdown menu
  renderDatabaseDropdown <- function() {
    temp_con <- dbConnect(
      RPostgres::Postgres(),
      dbname = "postgres",
      host = host_name,
      port = port_number,
      user = user_name,
      password = password_name
    )
    dbs <- dbGetQuery(temp_con, "SELECT datname FROM pg_database WHERE datistemplate = false;")
    dbDisconnect(temp_con)
    
    # Update the dropdown menu dynamically
    output$db_dropdown <- renderUI({
      selectInput(
        "db_name_input",
        "SELECT A DATABASE",
        choices = sort(na.omit(dbs[dbs$datname != "postgres", "datname"])),
        selected = ifelse("postgres" %in% dbs$datname, dbs$datname[1], "")
      )
    })
  }
  
  # Initial call to render the dropdown on load
  renderDatabaseDropdown()
  
  # Reactive value to store the database connection object
  dbCon <- reactiveVal(NULL)
  
  # Reactive value to store the connection status text
  connectionStatus <- reactiveVal("Not connected")
  
  # When the 'New Database' button is clicked search or add a new database
  observeEvent(input$btn_create_db, {
    showModal(modalDialog(
      title = "Enter Database Name",
      textInput("db_name_input", "Database Name", value = ""),
      footer = tagList(
        actionButton("confirm", "Confirm", class = "btn-primary", disabled = TRUE),
        modalButton("Cancel")
      ),
      easyClose = FALSE,
      fade = TRUE,
      tags$script(HTML("
      $(document).on('shown.bs.modal', function() {
        $('#db_name_input').focus();
      });
      $(document).on('input', '#db_name_input', function() {
        $('#confirm').prop('disabled', !$(this).val().trim());
      });
      $(document).on('keydown', '#db_name_input', function(e) {
        if (e.keyCode === 13 && $(this).val().trim()) {
          $('#confirm').click();
        }
      });
    "))
    ))
  })
  
  # Handle the 'Confirm' action for database creation
  observeEvent(input$confirm, {
    database_name <- isolate(input$db_name_input)
    
    if (nchar(trimws(database_name)) == 0) {
      output$dbMessage <- renderUI({
        tags$div(
          style = "font-weight: bold; text-align: center; padding: 10px; margin: 10px; border-radius: 5px; color: white; background-color: red; border: 2px solid white;",
          HTML("Error: Please enter a database name.")
        )
      })
      return()
    }
    
    # Show admin password modal
    showModal(modalDialog(
      title = "Enter Admin Password",
      passwordInput("admin_password", "Password"),
      footer = tagList(
        actionButton("password_confirm", "Confirm", class = "btn-primary"),
        modalButton("Cancel")
      ),
      easyClose = FALSE,
      fade = TRUE,
      tags$script(HTML("
      $(document).on('shown.bs.modal', function() {
        $('#admin_password').focus();
      });
      $(document).on('keydown', '#admin_password', function(e) {
        if (e.keyCode === 13) {
          $('#password_confirm').click();
        }
      });
    "))
    ))
  })
  
  
  observeEvent(input$password_confirm, {
    passwordInput <- isolate(input$admin_password)
    
    if (passwordInput != global_pass) {
      shinyjs::alert("Incorrect password, please try again.")
      return()
    }
    
    removeModal()  # Close modal on successful password
    
    # Create the database
    database_name <- isolate(input$db_name_input)
    showModal(modalDialog(
      title = "Creating Database",
      div(
          style = "text-align: center; padding: 20px;",
          icon("spinner", class = "fa-spin fa-3x", style = "color: #3c8dbc;"),
          tags$h4("Creating Database...", style = "margin-top: 15px; font-weight: bold;"),
          tags$p("Please wait, this may take a moment.")
      ),
      footer = NULL,
      easyClose = FALSE,
      fade = TRUE
    ))
    
    # Simulate or execute database creation
    dbCreationResult <- tryCatch({
      createDatabase(database_name, host_name, port_number, user_name, password_name)
    }, error = function(e) {
      list(message = "Database creation failed: " %||% e$message, backcolor = "red", backborder = "darkred", con = NULL)
    })
    
    removeModal()
    
    # Display results
    styledMessage <- sprintf(
      "font-weight: bold; text-align: center; padding: 10px; margin: 10px; border-radius: 5px; color: white; background-color: %s; border: 2px solid %s;",
      ifelse(!is.null(dbCreationResult$con), "green", "tomato"),
      ifelse(!is.null(dbCreationResult$con), "darkgreen", "darkred")
    )
    
    output$dbMessage <- renderUI({
      tags$div(style = styledMessage, HTML(dbCreationResult$message))
    })
    
    if (!is.null(dbCreationResult$con)) {
      shiny::showNotification("Database created successfully!", type = "message")
      
      # Re-render the dropdown menu to include the new database
      renderDatabaseDropdown()
      
    }
  })
  
  
  # Toggle database connection ON/OFF
  # Reactive value to track database connection
  connection_opened <- reactiveVal(FALSE)
  
  # Toggle database connection ON/OFF
  observeEvent(input$btnToggleConn, {
    if (is.null(dbCon())) { # No connection exists
      selected_db <- isolate(input$db_name_input)
      new_con <- tryCatch(
        {
          dbConnect(
            RPostgres::Postgres(),
            dbname = selected_db,
            host = host_name,
            port = port_number,
            user = user_name,
            password = password_name
          )
        },
        error = function(e) {
          message("Connection failed: ", e$message)
          NULL
        }
      )
      
      if (!is.null(new_con)) {
        dbCon(new_con) # Save connection
        connectionStatus("Connected to database")
        connection_opened(TRUE) # Set connection state to TRUE
        updateActionButton(session, "btnToggleConn", label = "Disconnect", icon = icon("ban"))
      } else {
        connectionStatus("Failed to connect")
        connection_opened(FALSE) # Set connection state to FALSE
      }
    } else { # Connection exists, disconnect it
      dbDisconnect(dbCon())
      dbCon(NULL) # Clear connection
      connectionStatus("Disconnected")
      connection_opened(FALSE) # Set connection state to FALSE
      updateActionButton(session, "btnToggleConn", label = "Connect", icon = icon("plug"))
      output$dbMessage <- renderUI({
        # Define the base style template
        baseStyleTemplate <- "font-weight: bold; text-align: center; padding: 10px; margin: 10px; border-radius: 5px; color: white; background-color: %s; border: 2px solid %s;"
        
        # Initialize variables for message content and background color
        messageContent <- "No new databases created"
        backgroundColor <- "gray80"
        borderColor <- "white"
        # Apply the style with the dynamic background color and content
        styledMessage <- sprintf(baseStyleTemplate, backgroundColor, borderColor)
        tags$div(style = styledMessage, HTML(messageContent))
      })
    }
  })
  
  # Expose connection status to UI
  output$connection_opened <- reactive({
    connection_opened()
  })
  outputOptions(output, "connection_opened", suspendWhenHidden = FALSE)
  
  
  # Reset warning message when connection status changes from "Failed to connect"
  observeEvent(connectionStatus(), {
    if (connectionStatus() != "Failed to connect") {
      output$fileUploadWarning <- renderUI({})
    }
  })
  
  ## DELETE EXISTING DATABASES -----------------------------------------------------
  # Handle the 'Delete' action with password confirmation
  observeEvent(input$delete_button, {
    # Show modal to confirm deletion and ask for admin password
    showModal(modalDialog(
      title = "Enter Admin Password",
      tags$p(HTML(paste0("You are going to delete the database '<b>", isolate(input$db_name_input), "</b>'. Enter your password to proceed."))),
      passwordInput("admin_password_delete", "Password"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_delete_password", "Confirm", class = "btn-danger")
      ),
      easyClose = FALSE,
      fade = TRUE,
      tags$script(HTML("
      $(document).on('shown.bs.modal', function() {
        $('#admin_password_delete').focus();
      });
      $(document).on('keydown', '#admin_password_delete', function(e) {
        if(e.keyCode == 13) {  // 13 is the Enter key
          $('#confirm_delete_password').click();
        }
      });
    "))
    ))
  })
  
  observeEvent(input$confirm_delete_password, {
    passwordInput <- isolate(input$admin_password_delete)
    
    if (passwordInput == global_pass) {
      removeModal()  # Close the modal if the password is correct
      
      # Drop the selected database
      db_to_delete <- isolate(input$db_name_input)
      temp_con <- dbConnect(RPostgres::Postgres(), dbname = "postgres", host = host_name, port = port_number, user = user_name, password = password_name)
      
      tryCatch({
        # Terminate all active connections to the database
        dbExecute(temp_con, sprintf("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = %s;", DBI::dbQuoteLiteral(temp_con, db_to_delete)))
        
        # Now drop the database
        showModal(modalDialog(
          title = "Deleting Database",
          div(
              style = "text-align: center; padding: 20px;",
              icon("spinner", class = "fa-spin fa-3x", style = "color: #dc3545;"),
              tags$h4("Deleting Database...", style = "margin-top: 15px; font-weight: bold;"),
              tags$p("Please wait... this action cannot be undone.")
          ),
          footer = NULL,
          easyClose = FALSE,
          fade = TRUE
        ))
        dbExecute(temp_con, sprintf("DROP DATABASE %s;", DBI::dbQuoteIdentifier(temp_con, db_to_delete)))
        removeModal()  # Close the modal if the password is correct
        showNotification(paste("Database", db_to_delete, "has been deleted."), type = "message")
        
        # Refresh the database list in the dropdown
        output$db_dropdown <- renderUI({
          temp_con <- dbConnect(RPostgres::Postgres(), dbname = "postgres", host = host_name, port = port_number, user = user_name, password = password_name)
          dbs <- dbGetQuery(temp_con, "SELECT datname FROM pg_database WHERE datistemplate = false;")
          dbDisconnect(temp_con)
          selectInput("db_name_input", "SELECT DATABASE", choices = dbs[dbs$datname != "postgres", "datname"], selected = dbs$datname[1])
        })
      }, error = function(e) {
        showNotification(paste("Error deleting database:", e$message), type = "error")
      })
      
      dbDisconnect(temp_con)
    } else {
      # Incorrect password
      shinyjs::alert("Incorrect password, please try again.")
    }
  })
  
  
  
  # END DELETE EXISTING DATABASES -----------------------------------------------------
  
  # Observe file upload and check structure ----
  observeEvent(input$fileUpload, {
    log_debug("1. Upload started") ### NEW
    req(input$fileUpload)
    tryCatch({
      ## Read the uploaded file
      uploaded_df.plot <- read_excel(input$fileUpload$datapath, sheet = "Plot Data", skip=1)
      names(uploaded_df.plot) <- plot_table.names
      # names(uploaded_df.plot) <- c("project_name","site_code","plot_code","profile_code",
      #                              "plot_type","n_layers","date","longitude","latitude","altitude","positional_accuracy","extent","map_sheet_code",
      #                              "TemperatureRegime","MoistureRegime","KoeppenClass","CurrentWeatherConditions","PastWeatherConditions",
      #                              "Landuse","Vegetation","Croptype","BareSoilAbundance","TreeDensity","ForestAbundance",
      #                              "GrassAbundance","ShrubAbundace","HumanInfluence","PavedAbundance",
      #                              "SurfaceAge","ParentMaterialClass","Lithology","MajorLandForm",
      #                              "ComplexLandform","Position","SlopeForm","SlopeGradient",
      #                              "SlopeOrientation","SlopePathway","RockOutcropsCover","RockOutcropsDistance",
      #                              "FragmentsCover","FragmentsSize","ErosionClass","ErosionDegree",
      #                              "ErosionAreaAffected","ErosionActivityPeriod","SealingThickness","SealingConsistence" ,      
      #                              "CracksWidth","CracksDepth","CracksDistance","SaltCover",           
      #                              "SaltThickness","BleachedSandCover","PresenceOfWater","MoistureConditions",    
      #                              "DrainageClass","ExternalDrainageClass","GroundwaterDepth","GroundwaterQuality",       
      #                              "FloodDuration","FloodFrequency")  
      
      uploaded_df.profile <- read_excel(input$fileUpload$datapath, sheet = "Profile Data", skip=1)
      names(uploaded_df.profile) <- profile_table.names
      #names(uploaded_df.profile) <- c("profile_code","descriptionStatus","soilGroupWRB","soilClassificationWRB","SoilSpecifierWRB","SupplementaryQualifierWRB","soilPhase","soilOrderUSDA","soilSuborderUSDA","formativeElementUSDA","SoilDepthtoBedrock","EffectiveSoilDepth")
      
      uploaded_df.element <- read_excel(input$fileUpload$datapath, sheet = "Element Data", skip=1)
      names(uploaded_df.element)  <- element_table.names

      uploaded_df.procedure <- read_excel(input$fileUpload$datapath, sheet = "Procedures") %>%
        left_join(procedures, by = c("property_phys_chem_id", "procedure_phys_chem_id","unit_of_measure_id"))
      
      uploaded_df.specimen <- read_excel(input$fileUpload$datapath, sheet = "Specimen Data")
      colnames(uploaded_df.specimen)[(ncol(uploaded_df.specimen) - (length(uploaded_df.procedure[[1]])-1)):ncol(uploaded_df.specimen)] <- uploaded_df.procedure[[2]]
      
      uploaded_df.metadata <- read_excel(input$fileUpload$datapath, sheet = "Metadata", skip=1)
      
      log_debug("2. Files read successfully")
      
      plot.profile <- left_join(uploaded_df.plot,uploaded_df.profile)
      plot.profile <- left_join(plot.profile,uploaded_df.metadata)
      
      site_tibble <- left_join(plot.profile,uploaded_df.element)
      
      ############## NEW ##############  
      #site_tibble <- left_join(site_tibble,uploaded_df.specimen)
      
      # Step 1: Make column names unique first
      colnames(uploaded_df.specimen) <- make.unique(colnames(uploaded_df.specimen), sep = "_")
      
      # Now do the join
      site_tibble <- left_join(
        site_tibble, 
        uploaded_df.specimen,
        by = c("profile_code", "element_code")
      )
      
      log_debug(paste("3. Joins complete. Site tibble rows:", nrow(site_tibble)))
      
      
      # Step 2: Remove suffixes from column names
      #colnames(site_tibble) <- gsub("_\\d+$", "", colnames(site_tibble))
      colnames(site_tibble) <- gsub("_[0-9]+$", "", colnames(site_tibble))
      ############## END NEW ##############  
      
      
      if (!checkFileStructure(site_tibble)) {
        # Display warning message
        output$dynamicFileInput <- renderUI({
          if (!is.null(dbCon())) {
            fileInput("fileUpload", "INJECT DATA (.xlsx)", accept = ".xlsx")
          }
        })
        
        output$fileUploadWarning <- renderUI({
          if (!is.null(dbCon())) {
            tags$div(
              tags$div(
                style = "color: white; background-color: red; font-weight: bold; text-align: center; border: 2px solid red; padding: 10px; margin: 10px; border-radius: 5px;",
                HTML("Warning:<br>Uploaded file does not match the expected structure or variable types")
              ),
              tags$div(
                style = "color: red; font-weight: bold; text-align: center; border: 2px solid red; padding: 10px; margin: 10px; border-radius: 5px;",
                HTML("Please, check your data")
              )
            )
          }
        })
      } else {
        output$fileUploadWarning <- renderUI({
          if (!is.null(dbCon())) {
            tags$div(
              tags$div(
                style = "color: white; background-color: green; font-weight: bold; text-align: center; border: 1px solid white; padding: 10px; margin: 10px; border-radius: 5px;",
                HTML("Update Successful")
              )
            )
          }
        })
        # Clear previous warnings if any
        delay(1000,output$fileUploadWarning <- renderUI({}))
        
        # Proceed with database operations...
      }
    }, error = function(e) {
      log_debug(paste("ERROR in server.R:", e$message))
      output$fileUploadWarning <- renderUI({
        tags$div(
          style = "color: red; font-weight: bold;",
          paste("Error reading file:", e$message)
        )
      })
    })
  })
  
  
  # Function to dynamically render data tables
  renderDataTables <- function(tableName) {
    renderDT({
      req(dbCon()) 
      df <- dbGetQuery(dbCon(), sprintf("SELECT * FROM core.%s", tableName))
      datatable(
        df,
        filter = "top",
        options = list(
          pageLength = 50,
          autoWidth = FALSE,
          scrollX = TRUE,
          columnDefs = list(list(width = '200px', targets = "_all"))
        ),
        rownames = FALSE
      )
    })
  }
  
  
  # Render Database Tables ----
  # Project and Site Tables
  output$viewProject <- renderDataTables("project")
  output$viewSite <- renderDataTables("site")
  output$viewSite_project <- renderDataTables("project_site")
  output$viewProject_related <- renderDataTables("project_related")
  
  # Location and Geographical Tables
  output$viewAddress <- renderDataTables("address")
  output$viewSurface <- renderDataTables("surface")
  output$viewPlot <- renderDataTables("plot")
  output$viewProfile <- renderDataTables("profile")
  output$viewElement <- renderDataTables("element")
  
  # Specimen and Specimen Preparation Tables
  output$viewSpecimen <- renderDataTables("specimen")
  output$viewSpecimen_prep_process <- renderDataTables("specimen_prep_process")
  output$viewSpecimen_transport <- renderDataTables("specimen_transport")
  output$viewSpecimen_storage <- renderDataTables("specimen_storage")
  
  # Descriptive Observations for Surface, Plot, Profile, Element, and Specimen
  output$viewResult_desc_surface <- renderDataTables("result_desc_surface")
  output$viewSurface_individual <- renderDataTables("surface_individual")
  
  output$viewPlot_individual <- renderDataTables("plot_individual")
  output$viewProperty_desc_plot <- renderDataTables("property_desc")
  output$viewObservation_desc_plot <- renderDataTables("observation_desc_plot")
  output$viewResult_desc_plot <- renderDataTables("result_desc_plot")
  output$viewThesaurus_desc_plot <- renderDataTables("category_desc")
  
  output$viewObservation_desc_profile <- renderDataTables("observation_desc_profile")
  #output$viewProperty_desc_profile <- renderDataTables("property_desc")
  output$viewResult_desc_profile <- renderDataTables("result_desc_profile")
  #output$viewThesaurus_desc_profile <- renderDataTables("category_desc")
  
  output$viewObservation_desc_element <- renderDataTables("observation_desc_element")
  #output$viewProperty_desc_element <- renderDataTables("property_desc")
  output$viewResult_desc_element <- renderDataTables("result_desc_element")
  #output$viewThesaurus_desc_element <- renderDataTables("category_desc")
  
  # Physical and Chemical Properties and Measurements
  output$viewResult_phys_chem <- renderDataTables("result_phys_chem")
  output$viewObservation_phys_chem <- renderDataTables("observation_phys_chem")
  output$viewProperty_phys_chem <- renderDataTables("property_phys_chem")
  output$viewProcedure_phys_chem <- renderDataTables("procedure_phys_chem")
  output$viewUnit_of_measure <- renderDataTables("unit_of_measure")
  
  
  # Spectral Analysis Tables
  output$viewResult_spectral <- renderDataTables("result_spectrum")
  
  
  # Render tables from metadata 
  renderMetaDataTables <- function(tableName) {
    renderDT({
      req(dbCon()) # Ensure there's a connection
      df <-
        dbGetQuery(dbCon(), sprintf("SELECT * FROM metadata.%s", tableName))
      df
    }, filter = "top", options = list(
      pageLength = 20),
    rownames = FALSE
    )
  }
  
  # Organisational and Individual Tables
  output$viewOrganisation <- renderMetaDataTables("organisation")
  output$viewOrganisation_unit <- renderMetaDataTables("organisation_unit")
  output$viewOrganisation_individual <- renderMetaDataTables("organisation_individual")
  output$viewIndividual <- renderMetaDataTables("individual")
  output$viewAddress <- renderMetaDataTables("address")
  
  # Assuming 'connectionStatus' is a reactive value holding the message ----
  output$dbMessage <- renderUI({
    # Define the base style template
    baseStyleTemplate <- "font-weight: bold; text-align: center; padding: 10px; margin: 10px; border-radius: 5px; color: white; background-color: %s; border: 2px solid %s;"
    
    # Initialize variables for message content and background color
    messageContent <- "No new databases created"
    backgroundColor <- "gray80"
    borderColor <- "white"
    # Apply the style with the dynamic background color and content
    styledMessage <- sprintf(baseStyleTemplate, backgroundColor, borderColor)
    tags$div(style = styledMessage, HTML(messageContent))
  })
  
  
  # Dynamically render fileInput based on connection status
  output$dynamicFileInput <- renderUI({
    if (!is.null(dbCon())) {
      fileInput("fileUpload", "INJECT DATA (.xlsx)", accept = ".xlsx")
    }
  })
  
  observeEvent(input$fileUpload, {
    log_debug("1. Upload started") ### NEW
    
    # # Read the uploaded file
    uploaded_df.plot <- read_excel(input$fileUpload$datapath, sheet = "Plot Data", skip=1)
    names(uploaded_df.plot) <- plot_table.names

    uploaded_df.profile <- read_excel(input$fileUpload$datapath, sheet = "Profile Data", skip=1)
    names(uploaded_df.profile) <- profile_table.names
    #names(uploaded_df.profile) <- c("profile_code","descriptionStatus","soilGroupWRB","soilClassificationWRB","SoilSpecifierWRB","SupplementaryQualifierWRB","soilPhase","soilOrderUSDA","soilSuborderUSDA","formativeElementUSDA","SoilDepthtoBedrock","EffectiveSoilDepth")

    uploaded_df.element <- read_excel(input$fileUpload$datapath, sheet = "Element Data", skip=1)
    names(uploaded_df.element)  <- element_table.names
    
    uploaded_df.procedure <- read_excel(input$fileUpload$datapath, sheet = "Procedures") %>%
      left_join(procedures, by = c("property_phys_chem_id", "procedure_phys_chem_id","unit_of_measure_id"))
    
    uploaded_df.specimen <- read_excel(input$fileUpload$datapath, sheet = "Specimen Data")
    colnames(uploaded_df.specimen)[(ncol(uploaded_df.specimen) - (length(uploaded_df.procedure[[1]])-1)):ncol(uploaded_df.specimen)] <- uploaded_df.procedure[[2]]
    
    uploaded_df.metadata <- read_excel(input$fileUpload$datapath, sheet = "Metadata", skip=1)
    
    log_debug("2. Files read successfully")
    
    plot.profile <- left_join(uploaded_df.plot,uploaded_df.profile)
    plot.profile <- left_join(plot.profile,uploaded_df.metadata)
    
    site_tibble <- left_join(plot.profile,uploaded_df.element)
    ############## NEW ##############  
    #site_tibble <- left_join(site_tibble,uploaded_df.specimen)
    
    # Step 1: Make column names unique first
    colnames(uploaded_df.specimen) <- make.unique(colnames(uploaded_df.specimen), sep = "_")
    
    # Now do the join
    site_tibble <- left_join(
      site_tibble, 
      uploaded_df.specimen,
      by = c("profile_code", "element_code")
    )
    
    log_debug(paste("3. Joins complete. Site tibble rows:", nrow(site_tibble)))    
    
    # Step 2: Remove suffixes from column names
    #colnames(site_tibble) <- gsub("_\\d+$", "", colnames(site_tibble))
    colnames(site_tibble) <- gsub("_[0-9]+$", "", colnames(site_tibble))
    ############## END NEW ##############  
    
    
    ## Start of fill_tables (delete 'if' and replace with 'fill_tables.R')
    if (!is.null(site_tibble) && nrow(site_tibble) > 0) {
      log_debug("4. Calling insert_data_sql...")
      insert_data_sql(site_tibble, uploaded_df.procedure,dbCon, session)  # Call the function
    }
    # Render Database Tables ----
    # Project and Site Tables
    output$viewProject <- renderDataTables("project")
    output$viewSite <- renderDataTables("site")
    output$viewSite_project <- renderDataTables("project_site")
    output$viewProject_related <- renderDataTables("project_related")
    
    # Location and Geographical Tables
    output$viewAddress <- renderDataTables("address")
    output$viewSurface <- renderDataTables("surface")
    output$viewPlot <- renderDataTables("plot")
    output$viewProfile <- renderDataTables("profile")
    output$viewElement <- renderDataTables("element")
    
    # Specimen and Specimen Preparation Tables
    output$viewSpecimen <- renderDataTables("specimen")
    output$viewSpecimen_prep_process <- renderDataTables("specimen_prep_process")
    output$viewSpecimen_transport <- renderDataTables("specimen_transport")
    output$viewSpecimen_storage <- renderDataTables("specimen_storage")
    
    # Descriptive Observations for Surface, Plot, Profile, Element, and Specimen
    output$viewResult_desc_surface <- renderDataTables("result_desc_surface")
    output$viewSurface_individual <- renderDataTables("surface_individual")
    
    output$viewPlot_individual <- renderDataTables("plot_individual")
    output$viewProperty_desc_plot <- renderDataTables("property_desc")
    output$viewObservation_desc_plot <- renderDataTables("observation_desc_plot")
    output$viewResult_desc_plot <- renderDataTables("result_desc_plot")
    output$viewThesaurus_desc_plot <- renderDataTables("category_desc")
    
    output$viewObservation_desc_profile <- renderDataTables("observation_desc_profile")
    #output$viewProperty_desc_profile <- renderDataTables("property_desc")
    output$viewResult_desc_profile <- renderDataTables("result_desc_profile")
    #output$viewThesaurus_desc_profile <- renderDataTables("category_desc")
    
    output$viewObservation_desc_element <- renderDataTables("observation_desc_element")
    #output$viewProperty_desc_element <- renderDataTables("property_desc")
    output$viewResult_desc_element <- renderDataTables("result_desc_element")
    #output$viewThesaurus_desc_element <- renderDataTables("category_desc")
    
    # Physical and Chemical Properties and Measurements
    output$viewResult_phys_chem <- renderDataTables("result_phys_chem")
    output$viewObservation_phys_chem <- renderDataTables("observation_phys_chem")
    output$viewProperty_phys_chem <- renderDataTables("property_phys_chem")
    output$viewProcedure_phys_chem <- renderDataTables("procedure_phys_chem")
    output$viewUnit_of_measure <- renderDataTables("unit_of_measure")
    
    
    # Spectral Analysis Tables
    output$viewResult_spectral <- renderDataTables("result_spectrum")
    
    
    # Render tables from metadata 
    renderMetaDataTables <- function(tableName) {
      renderDT({
        req(dbCon()) # Ensure there's a connection
        df <-
          dbGetQuery(dbCon(), sprintf("SELECT * FROM metadata.%s", tableName))
        df
      }, filter = "top", options = list(
        pageLength = 20),
      rownames = FALSE
      )
    }
    
    # Organisational and Individual Tables
    output$viewOrganisation <- renderMetaDataTables("organisation")
    output$viewOrganisation_unit <- renderMetaDataTables("organisation_unit")
    output$viewOrganisation_individual <- renderMetaDataTables("organisation_individual")
    output$viewIndividual <- renderMetaDataTables("individual")
    output$viewAddress <- renderMetaDataTables("address")
    
  })
}
