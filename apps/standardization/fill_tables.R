# LAST UPDATE. It corrects the use of duplicated lab properties analysed by different methods
# CHANGES FRAMED WITH NEW

# Helper function to print to Docker logs
log_debug <- function(msg) {
  cat(paste0("[DEBUG] ", Sys.time(), ": ", msg, "\n"), file = stderr())
}

log_file <- "/srv/shiny-server/init-scripts/logs/error_log.txt"

sql_value <- function(x, is_numeric = FALSE) {
  if (is.na(x)) {
    return("NULL") # Use NULL literal for missing values
  } else if (is_numeric) {
    return(as.character(x)) # Return numeric values unquoted
  } else {
    return(sprintf("'%s'", gsub("'", "''", as.character(x)))) # Quote strings and escape single quotes
  }
}

insert_data_sql <-
  function(site_tibble,
           uploaded_df.procedure,
           dbCon,
           session) {
    con = dbCon()
    
    # Show modal right before rendering
    showModal(modalDialog(
      div(
          style = "text-align: center; padding: 20px;",
          icon("spinner", class = "fa-spin fa-3x", style = "color: #3c8dbc;"),
          tags$h4("Processing Data...", style = "margin-top: 15px; font-weight: bold;"),
          tags$p("Please wait, this may take a moment.")
      ),
      footer = NULL,
      easyClose = FALSE,
      fade = TRUE
    ))
    
    ###################

    # METADATA: Insert data into 'metadata' schema tables ----
    tryCatch({
      unique_metadata <- unique(site_tibble[, c(
        "name", "honorific_title", "role", "email", "telephone", "url",
        "organization", "street_address", "postal_code", "locality", "country"
      )])
      
      for (row in 1:nrow(unique_metadata)) {
        current_row <- unique_metadata[row, ]
        
        # --------------------------
        # 1. Insert / Get address_id
        address_query <- sprintf(
          "SELECT address_id FROM metadata.address WHERE street_address = %s AND postal_code = %s AND locality = %s AND country = %s",
          sql_value(current_row$street_address),
          sql_value(current_row$postal_code),
          sql_value(current_row$locality),
          sql_value(current_row$country)
        )
        address_result <- dbGetQuery(con, address_query)
        
        if (nrow(address_result) == 0) {
          insert_address_query <- sprintf(
            "INSERT INTO metadata.address (street_address, postal_code, locality, country)
         VALUES (%s, %s, %s, %s)
         RETURNING address_id;",
         sql_value(current_row$street_address),
         sql_value(current_row$postal_code),
         sql_value(current_row$locality),
         sql_value(current_row$country)
          )
          address_id <- dbGetQuery(con, insert_address_query)$address_id[1]
        } else {
          address_id <- address_result$address_id[1]
        }
        
        # --------------------------
        # 2. Insert / Get organisation_id (if organization is not missing)
        organisation_id <- NA
        if (!is.na(current_row$organization) && current_row$organization != "") {
          org_query <- sprintf(
            "SELECT organisation_id FROM metadata.organisation WHERE name = %s",
            sql_value(current_row$organization)
          )
          org_result <- dbGetQuery(con, org_query)
          
          if (nrow(org_result) == 0) {
            insert_org_query <- sprintf(
              "INSERT INTO metadata.organisation (name, address_id)
           VALUES (%s, %s)
           RETURNING organisation_id;",
           sql_value(current_row$organization),
           sql_value(address_id, is_numeric = TRUE)
            )
            organisation_id <- dbGetQuery(con, insert_org_query)$organisation_id[1]
          } else {
            organisation_id <- org_result$organisation_id[1]
          }
        }
        
        # --------------------------
        # 3. Insert / Get organisation_unit_id (only if organisation_id exists)
        organisation_unit_id <- NA
        if (!is.na(organisation_id)) {
          unit_name <- current_row$organization
          org_unit_query <- sprintf(
            "SELECT organisation_unit_id FROM metadata.organisation_unit WHERE name = %s AND organisation_id = %s",
            sql_value(unit_name),
            sql_value(organisation_id, is_numeric = TRUE)
          )
          org_unit_result <- dbGetQuery(con, org_unit_query)
          
          if (nrow(org_unit_result) == 0) {
            insert_org_unit_query <- sprintf(
              "INSERT INTO metadata.organisation_unit (name, organisation_id)
           VALUES (%s, %s)
           RETURNING organisation_unit_id;",
           sql_value(unit_name),
           sql_value(organisation_id, is_numeric = TRUE)
            )
            organisation_unit_id <- dbGetQuery(con, insert_org_unit_query)$organisation_unit_id[1]
          } else {
            organisation_unit_id <- org_unit_result$organisation_unit_id[1]
          }
        }
        
        # --------------------------
        # 4. Insert / Get individual_id (even if name/email are missing)
        indiv_query <- sprintf(
          "SELECT individual_id FROM metadata.individual WHERE name = %s AND email = %s",
          sql_value(current_row$name),
          sql_value(current_row$email)
        )
        indiv_result <- dbGetQuery(con, indiv_query)
        
        if (nrow(indiv_result) == 0) {
          insert_indiv_query <- sprintf(
            "INSERT INTO metadata.individual (name, honorific_title, email, telephone, url, address_id)
         VALUES (%s, %s, %s, %s, %s, %s)
         RETURNING individual_id;",
         sql_value(current_row$name),
         sql_value(current_row$honorific_title),
         sql_value(current_row$email),
         sql_value(current_row$telephone),
         sql_value(current_row$url),
         sql_value(address_id, is_numeric = TRUE)
          )
          individual_id <- dbGetQuery(con, insert_indiv_query)$individual_id[1]
        } else {
          individual_id <- indiv_result$individual_id[1]
        }
        
        # --------------------------
        # 5. Link individual to organisation + unit if both exist
        if (!is.na(organisation_id) && !is.na(individual_id) && !is.na(organisation_unit_id)) {
          org_indiv_query <- sprintf(
            "SELECT * FROM metadata.organisation_individual WHERE organisation_id = %s AND individual_id = %s AND organisation_unit_id = %s",
            sql_value(organisation_id, is_numeric = TRUE),
            sql_value(individual_id, is_numeric = TRUE),
            sql_value(organisation_unit_id, is_numeric = TRUE)
          )
          org_indiv_result <- dbGetQuery(con, org_indiv_query)
          
          if (nrow(org_indiv_result) == 0) {
            insert_org_indiv_query <- sprintf(
              "INSERT INTO metadata.organisation_individual (organisation_id, individual_id, organisation_unit_id, role)
           VALUES (%s, %s, %s, %s);",
           sql_value(organisation_id, is_numeric = TRUE),
           sql_value(individual_id, is_numeric = TRUE),
           sql_value(organisation_unit_id, is_numeric = TRUE),
           sql_value(current_row$role)
            )
            dbExecute(con, insert_org_indiv_query)
          }
        }
      }
    }, error = function(e) {
      message(sprintf("Error during metadata insertion: %s", e$message))
    })
    
    
    ###################
    # PROJECT: Insert data into 'project' table ----
    tryCatch({
      # Extract unique project names
      unique_data <- unique(site_tibble[, c("project_name")])
      
      # Loop through each unique project_name
      for (row in unique_data$project_name) {
        # Construct the query dynamically, handling NA values
        query <- sprintf(
          "INSERT INTO core.project (project_id, name) VALUES (DEFAULT, %s) ON CONFLICT DO NOTHING;",
          sql_value(row) # Use sql_value to handle NA and escaping
        )
        
        # Execute the query
        dbExecute(con, query)
      }
      
      # Remove duplicates in the core.project table
      cleanup_query <- "
    DELETE FROM core.project a
    USING core.project b
    WHERE b.project_id < a.project_id AND a.name = b.name;"
      
      dbExecute(con, cleanup_query)
    }, error = function(e) {
      message(sprintf("Error inserting into core.project: %s", e$message))
    })
    
    # ----
    
    # SITE: Insert data into the 'site' table ----
    tryCatch({
      # Extract unique data for the site table
      unique_data <- unique(site_tibble[, c("site_code", "latitude", "longitude", "extent")])
      print(unique_data)
      
      # Loop through each unique row
      for (i in 1:nrow(unique_data)) {
        pair <- unique_data[i, ]
        print(pair)
        
        # Generate a POINT geometry for the position based on latitude and longitude
        position_text <- sprintf("POINT(%f %f)", pair$longitude, pair$latitude)
        
        # Construct the query dynamically, handling NA for extent
        site_query <- sprintf(
          "INSERT INTO core.site (site_code, position, extent) 
       VALUES (%s, ST_GeomFromText('%s', 4326), %s) 
       ON CONFLICT (site_code) DO NOTHING;",
       sql_value(pair$site_code),              # site_code
       position_text,                          # position (WKT format)
       sql_value(pair$extent, is_numeric = TRUE) # extent (NULL or numeric)
        )
        
        # Execute the insert query
        dbExecute(con, site_query)
      }
      
      # Clean up duplicate entries in the site table
      cleanup_query <- "
    DELETE FROM core.site a
    USING core.site b
    WHERE b.site_id < a.site_id AND a.site_code = b.site_code AND a.position = b.position;"
      dbExecute(con, cleanup_query)
      
    }, error = function(e) {
      message(sprintf("Error inserting data into site table: %s", e$message))
    })
    # ----
    # PROJECT-SITE: Insert data into the 'project_site' table ----
    tryCatch({
      # Extract unique combinations of site_code and project_name
      unique_data <- unique(site_tibble[, c("site_code", "project_name")])
      
      # Loop through each unique combination
      for (i in 1:nrow(unique_data)) {
        pair <- unique_data[i, ]
        
        # Retrieve 'site_id' based on 'site_code'
        site_id_query <- sprintf(
          "SELECT site_id FROM core.site WHERE site_code = %s",
          sql_value(pair$site_code)
        )
        site_id_result <- dbGetQuery(con, site_id_query)
        
        # Retrieve 'project_id' based on 'project_name'
        project_id_query <- sprintf(
          "SELECT project_id FROM core.project WHERE name = %s",
          sql_value(pair$project_name)
        )
        project_id_result <- dbGetQuery(con, project_id_query)
        
        # If both site_id and project_id are valid, insert into site_project
        if (nrow(site_id_result) > 0 && nrow(project_id_result) > 0) {
          site_id <- site_id_result$site_id[1]
          project_id <- project_id_result$project_id[1]
          
          # Insert the pair into 'project_site', avoiding duplicates
          insert_query <- sprintf(
            "INSERT INTO core.project_site (site_id, project_id) 
         VALUES (%s, %s) 
         ON CONFLICT DO NOTHING;",
         sql_value(site_id, is_numeric = TRUE),
         sql_value(project_id, is_numeric = TRUE)
          )
          dbExecute(con, insert_query)
        }
      }
    }, error = function(e) {
      message(sprintf("Error inserting data into project_site table: %s", e$message))
    })
    # ----
    # PROJECT-RELATED (Still to define)
    # ----
    # tryCatch({
    #   # Extract unique project relationship records
    #   unique_data <- unique(site_tibble[, c("project_source_name", "project_target_name", "role")])
    #   
    #   for (row in 1:nrow(unique_data)) {
    #     current_row <- unique_data[row, ]
    #     
    #     # Get project_source_id
    #     source_query <- sprintf(
    #       "SELECT project_id FROM core.project WHERE name = %s",
    #       sql_value(current_row$project_source_name)
    #     )
    #     source_result <- dbGetQuery(con, source_query)
    #     
    #     # Get project_target_id
    #     target_query <- sprintf(
    #       "SELECT project_id FROM core.project WHERE name = %s",
    #       sql_value(current_row$project_target_name)
    #     )
    #     target_result <- dbGetQuery(con, target_query)
    #     
    #     if (nrow(source_result) > 0 && nrow(target_result) > 0) {
    #       project_source_id <- source_result$project_id[1]
    #       project_target_id <- target_result$project_id[1]
    #       
    #       # Check if link already exists
    #       related_query <- sprintf(
    #         "SELECT * FROM core.project_related WHERE project_source_id = %s AND project_target_id = %s",
    #         sql_value(project_source_id, is_numeric = TRUE),
    #         sql_value(project_target_id, is_numeric = TRUE)
    #       )
    #       related_result <- dbGetQuery(con, related_query)
    #       
    #       if (nrow(related_result) == 0) {
    #
    #         # Insert into project_related
    #         insert_related_query <- sprintf(
    #           "INSERT INTO core.project_related (project_source_id, project_target_id, role)
    #        VALUES (%s, %s, %s);",
    #        sql_value(project_source_id, is_numeric = TRUE),
    #        sql_value(project_target_id, is_numeric = TRUE),
    #        sql_value(current_row$role)
    #         )
    #         dbExecute(con, insert_related_query)
    #       }
    #     }
    #   }
    # }, error = function(e) {
    #   message(sprintf(
    #     "Error during project_related insertion: %s",
    #     e$message
    #   ))
    # })
    # 
    
    # ----
    # PLOT: Insert data into the 'plot' table ----
    tryCatch({
      # Extract unique data for plots
      unique_data <- unique(site_tibble[, c(
        "site_code", "project_name", "plot_code", "date",
        "map_sheet_code", "altitude", "positional_accuracy",
        "longitude", "latitude", "plot_type"
      )])
      
      #unique_data <- unique(site_tibble[, names(site_tibble) %in% names(uploaded_df.plot)])
      
      for (row in 1:nrow(unique_data)) {
        current_row <- unique_data[row, ]
        
        # Generate a POINT geometry for the position based on latitude and longitude
        position_text <- sprintf("POINT(%f %f)", current_row$longitude, current_row$latitude)
        
        # Retrieve 'site_id' based on 'site_code'
        site_id_query <- sprintf(
          "SELECT site_id FROM core.site WHERE site_code = %s",
          sql_value(current_row$site_code)
        )
        site_id_result <- dbGetQuery(con, site_id_query)
        
        # Retrieve 'project_id' based on 'project_name'
        project_id_query <- sprintf(
          "SELECT project_id FROM core.project WHERE name = %s",
          sql_value(current_row$project_name)
        )
        project_id_result <- dbGetQuery(con, project_id_query)
        
        if (nrow(site_id_result) > 0 && nrow(project_id_result) > 0) {
          site_id <- site_id_result$site_id[1]
          project_id <- project_id_result$project_id[1]
          
          # Check if the plot_code already exists to avoid duplicate entries
          existing_plot_query <- sprintf(
            "SELECT plot_id FROM core.plot WHERE plot_code = %s",
            sql_value(current_row$plot_code)
          )
          existing_plot <- dbGetQuery(con, existing_plot_query)
          
          if (nrow(existing_plot) == 0) {
            # Insert new plot with site_id
            insert_plot_query <- sprintf(
              "INSERT INTO core.plot (plot_code, site_id, altitude, time_stamp, map_sheet_code, positional_accuracy, position, type)
           VALUES (%s, %s, %s, %s, %s, %s, ST_GeomFromText('%s', 4326), %s);",
           sql_value(current_row$plot_code),                     # plot_code
           sql_value(site_id, is_numeric = TRUE),               # site_id
           sql_value(current_row$altitude, is_numeric = TRUE),  # altitude
           sql_value(format(current_row$date, "%Y-%m-%d")),     # date
           sql_value(current_row$map_sheet_code),               # map_sheet_code
           sql_value(current_row$positional_accuracy, is_numeric = TRUE), # positional_accuracy
           position_text,                                       # position as WKT
           sql_value(current_row$plot_type)                    # plot_type
            )
            dbExecute(con, insert_plot_query)
          }
          
          # Ensure the site and project association in 'project_site' table
          insert_site_project_query <- sprintf(
            "INSERT INTO core.project_site (site_id, project_id) 
         VALUES (%s, %s) 
         ON CONFLICT DO NOTHING;",
         sql_value(site_id, is_numeric = TRUE),
         sql_value(project_id, is_numeric = TRUE)
          )
          dbExecute(con, insert_site_project_query)
        }
      }
    }, error = function(e) {
      message(sprintf(
        "Error during plot insertion or plot population: %s",
        e$message
      ))
    })
    
    
    # ----
    # PLOT-INDIVIDUAL
    tryCatch({
      # Extract unique combinations of plot_code, name, email
      unique_data <- unique(site_tibble[, c("plot_code", "name", "email")])
      
      for (row in 1:nrow(unique_data)) {
        current_row <- unique_data[row, ]
        
        # Safely handle NA in name/email
        safe_name <- ifelse(is.na(current_row$name), "", current_row$name)
        safe_email <- ifelse(is.na(current_row$email), "", current_row$email)
        
        # ---------------------------
        # Get individual_id using fallback-safe SQL
        indiv_query <- sprintf(
          "SELECT individual_id FROM metadata.individual
       WHERE COALESCE(name, '') = %s AND COALESCE(email, '') = %s;",
       sql_value(safe_name),
       sql_value(safe_email)
        )
        indiv_result <- dbGetQuery(con, indiv_query)
        
        if (nrow(indiv_result) > 0) {
          individual_id <- indiv_result$individual_id[1]
          
          # ---------------------------
          # Get plot_id
          plot_query <- sprintf(
            "SELECT plot_id FROM core.plot WHERE plot_code = %s",
            sql_value(current_row$plot_code)
          )
          plot_result <- dbGetQuery(con, plot_query)
          
          if (nrow(plot_result) > 0) {
            plot_id <- plot_result$plot_id[1]
            
            # ---------------------------
            # Check if link exists
            plot_indiv_query <- sprintf(
              "SELECT 1 FROM core.plot_individual
           WHERE plot_id = %s AND individual_id = %s;",
           sql_value(plot_id, is_numeric = TRUE),
           sql_value(individual_id, is_numeric = TRUE)
            )
            plot_indiv_result <- dbGetQuery(con, plot_indiv_query)
            
            if (nrow(plot_indiv_result) == 0) {
              # ---------------------------
              # Insert into plot_individual
              insert_plot_indiv_query <- sprintf(
                "INSERT INTO core.plot_individual (plot_id, individual_id)
             VALUES (%s, %s);",
             sql_value(plot_id, is_numeric = TRUE),
             sql_value(individual_id, is_numeric = TRUE)
              )
              dbExecute(con, insert_plot_indiv_query)
            }
          }
        }
      }
    }, error = function(e) {
      message(sprintf("Error during plot_individual insertion: %s", e$message))
    })
    
    # ----
    # PLOT-RESULTS: Insert data into the 'result_desc_plot' table ----
    tryCatch({
      plots <- c(
        "TemperatureRegime", "MoistureRegime", "KoeppenClass", "CurrentWeatherConditions", "PastWeatherConditions",
        "Landuse", "Vegetation", "Croptype", "BareSoilAbundance", "TreeDensity", "ForestAbundance",
        "GrassAbundance", "ShrubAbundace", "HumanInfluence", "PavedAbundance",
        "SurfaceAge", "ParentMaterialClass", "Lithology", "MajorLandForm",
        "ComplexLandform", "Position", "SlopeForm", "SlopeGradient",
        "SlopeOrientation", "SlopePathway", "RockOutcropsCover", "RockOutcropsDistance",
        "FragmentsCover", "FragmentsSize", "ErosionClass", "ErosionDegree",
        "ErosionAreaAffected", "ErosionActivityPeriod", "SealingThickness", "SealingConsistence",
        "CracksWidth", "CracksDepth", "CracksDistance", "SaltCover",
        "SaltThickness", "BleachedSandCover", "PresenceOfWater", "MoistureConditions",
        "DrainageClass", "ExternalDrainageClass", "GroundwaterDepth", "GroundwaterQuality",
        "FloodDuration", "FloodFrequency"
      )
      
      unique_data <- site_tibble %>%
        pivot_longer(
          cols = any_of(as.character(plots)),
          names_to = "property_desc_id",
          values_to = "category_desc_id"
        )
      
      for (row in 1:nrow(unique_data)) {
        current_row <- unique_data[row, ]
        
        # Skip if missing values
        if (!is.na(current_row$category_desc_id) && current_row$property_desc_id != "") {
          # Get plot_id
          plot_id_query <- sprintf(
            "SELECT plot_id FROM core.plot WHERE plot_code = %s",
            sql_value(current_row$plot_code)
          )
          plot_id_result <- dbGetQuery(con, plot_id_query)
          
          # Check observation_desc_plot constraint
          valid_combo_query <- sprintf(
            "SELECT 1 FROM core.observation_desc_plot WHERE property_desc_id = %s AND category_desc_id = %s",
            sql_value(current_row$property_desc_id),
            sql_value(current_row$category_desc_id)
          )
          valid_combo_result <- dbGetQuery(con, valid_combo_query)
          
          if (nrow(plot_id_result) > 0 && nrow(valid_combo_result) > 0) {
            plot_id <- plot_id_result$plot_id[1]
            
            insert_query <- sprintf(
              "INSERT INTO core.result_desc_plot (plot_id, property_desc_id, category_desc_id)
           VALUES (%s, %s, %s)
           ON CONFLICT DO NOTHING;",
           sql_value(plot_id, is_numeric = TRUE),
           sql_value(current_row$property_desc_id),
           sql_value(current_row$category_desc_id)
            )
            dbExecute(con, insert_query)
          }
        }
      }
    }, error = function(e) {
      message("An error occurred in result_desc_plot: ", e$message)
    })
    
    # ----
    # PROFILE: Insert data into the 'profile' table ----
    tryCatch({
      # Extract unique combinations of plot_code and profile_code
      unique_data <- unique(site_tibble[, c("plot_code", "profile_code")])
      
      for (row in 1:nrow(unique_data)) {
        current_row <- unique_data[row, ]
        
        # Retrieve 'plot_id' based on 'plot_code'
        plot_id_query <- sprintf(
          "SELECT plot_id FROM core.plot WHERE plot_code = %s",
          sql_value(current_row$plot_code)
        )
        plot_id_result <- dbGetQuery(con, plot_id_query)
        
        if (nrow(plot_id_result) > 0) {
          plot_id <- plot_id_result$plot_id[1]
          
          # Check if the profile_code already exists to avoid duplicate entries
          existing_profile_query <- sprintf(
            "SELECT profile_id FROM core.profile WHERE profile_code = %s",
            sql_value(current_row$profile_code)
          )
          existing_profile <- dbGetQuery(con, existing_profile_query)
          
          if (nrow(existing_profile) == 0) {
            # Insert new profile with plot_id
            insert_profile_query <- sprintf(
              "INSERT INTO core.profile (plot_id, profile_code) 
           VALUES (%s, %s);",
           sql_value(plot_id, is_numeric = TRUE),
           sql_value(current_row$profile_code)
            )
            dbExecute(con, insert_profile_query)
          }
        }
      }
    }, error = function(e) {
      message(sprintf("Error during profile insertion: %s", e$message))
    })
    
    # ----
    # PROFILE-RESULTS: Insert data into the 'result_desc_profile' table ----
    tryCatch({
      profile <- c(
        "descriptionStatus", "soilGroupWRB", "soilClassificationWRB", "",
        "SoilSpecifierWRB", "SupplementaryQualifierWRB", "soilPhase",
        "soilOrderUSDA", "soilSuborderUSDA", "formativeElementUSDA",
        "SoilDepthtoBedrock", "EffectiveSoilDepth"
      )
      
      # Reshape data
      unique_data <- site_tibble %>%
        pivot_longer(
          cols = any_of(as.character(profile)),
          names_to = "property_desc_id",
          values_to = "category_desc_id"
        )
      
      for (row in 1:nrow(unique_data)) {
        current_row <- unique_data[row, ]
        
        # Skip rows with missing values
        if (!is.na(current_row$category_desc_id) && current_row$property_desc_id != "") {
          # Retrieve profile_id
          profile_id_query <- sprintf(
            "SELECT profile_id FROM core.profile WHERE profile_code = %s",
            sql_value(current_row$profile_code)
          )
          profile_id_result <- dbGetQuery(con, profile_id_query)
          
          if (nrow(profile_id_result) > 0) {
            profile_id <- profile_id_result$profile_id[1]
            
            # Insert into result_desc_profile
            insert_query <- sprintf(
              "INSERT INTO core.result_desc_profile (profile_id, property_desc_id, category_desc_id)
           VALUES (%s, %s, %s)
           ON CONFLICT DO NOTHING;",
           sql_value(profile_id, is_numeric = TRUE),
           sql_value(current_row$property_desc_id),
           sql_value(current_row$category_desc_id)
            )
            dbExecute(con, insert_query)
          }
        }
      }
    }, error = function(e) {
      message("An error occurred in profile: ", e$message)
    })
    
    # ----
    # ELEMENT: Insert data into the 'element' table ----
    # tryCatch({
    #   # Extract unique combinations of relevant columns
    #   unique_data <- unique(site_tibble[, c(
    #     "order_element", "type", "upper_depth", "lower_depth",
    #     "specimen_code", "profile_code"
    #   )])
    #   
    #   for (row in 1:nrow(unique_data)) {
    #     current_row <- unique_data[row, ]
    #     
    #     # Retrieve 'profile_id' based on 'profile_code'
    #     profile_id_query <- sprintf(
    #       "SELECT profile_id FROM core.profile WHERE profile_code = %s",
    #       sql_value(current_row$profile_code)
    #     )
    #     profile_id_result <- dbGetQuery(con, profile_id_query)
    #     
    #     if (nrow(profile_id_result) > 0) {
    #       profile_id <- profile_id_result$profile_id[1]
    #       
    #       # Construct the insert query for core.element table
    #       insert_element_query <- sprintf(
    #         "INSERT INTO core.element (profile_id, order_element, upper_depth, lower_depth, type) 
    #      VALUES (%s, %s, %s, %s, %s) 
    #      ON CONFLICT DO NOTHING;",
    #      sql_value(profile_id, is_numeric = TRUE),            # profile_id
    #      sql_value(current_row$order_element, is_numeric = TRUE),  # order_element
    #      sql_value(current_row$upper_depth, is_numeric = TRUE),    # upper_depth
    #      sql_value(current_row$lower_depth, is_numeric = TRUE),    # lower_depth
    #      sql_value(current_row$type)                          # type
    #       )
    #       
    #       # Execute the insert query
    #       dbExecute(con, insert_element_query)
    #     }
    #   }
    #   
    # }, error = function(e) {
    #   message(sprintf("Error during element insertion: %s", e$message))
    # })
    
    tryCatch({
      log_file <- "/srv/shiny-server/init-scripts/logs/error_log.txt"
      
      # Extract unique combinations of relevant columns
      # Ensure numeric values before the loop
      unique_data <- unique(site_tibble[, c(
        "order_element", "type", "upper_depth", "lower_depth",
        "specimen_code", "profile_code"
      )])
      unique_data$upper_depth <- as.numeric(unique_data$upper_depth)
      unique_data$lower_depth <- as.numeric(unique_data$lower_depth)
      
      for (row in 1:nrow(unique_data)) {
        current_row <- unique_data[row, ]
        
        upper_depth <- current_row$upper_depth
        lower_depth <- current_row$lower_depth
        type <- current_row$type
        profile_code <- current_row$profile_code
        specimen_code <- current_row$specimen_code
        
        # Validate BEFORE DB insert
        if (is.na(upper_depth) || is.na(lower_depth)) {
          error_msg <- sprintf(
            "ERROR: Missing depth values in specimen '%s' (profile: '%s').",
            specimen_code, profile_code
          )
        } else if (upper_depth < 0) {
          error_msg <- sprintf(
            "ERROR: Upper depth (%d) is negative in specimen '%s' (profile: '%s').",
            upper_depth, specimen_code, profile_code
          )
        } else if (upper_depth >= lower_depth) {
          error_msg <- sprintf(
            "ERROR: Upper depth (%d) must be strictly less than lower depth (%d) in specimen '%s' (profile: '%s').",
            upper_depth, lower_depth, specimen_code, profile_code
          )
        } else if (lower_depth > 500) {
          error_msg <- sprintf(
            "ERROR: Lower depth (%d) exceeds 500 mm in specimen '%s' (profile: '%s').",
            lower_depth, specimen_code, profile_code
          )
        } else {
          error_msg <- NULL  # Valid entry
        }
        
        # If invalid, notify and log
        if (!is.null(error_msg)) {
          if (exists("session")) {
            shiny::showNotification(error_msg, type = "error", duration = 30, session = session)
          }
          
          timestamped_msg <- sprintf("[%s] %s\n", Sys.time(), error_msg)
          write(timestamped_msg, file = log_file, append = TRUE)
          
          next  # Skip invalid row
        }
        
        # Retrieve profile_id for valid rows
        profile_id_query <- sprintf(
          "SELECT profile_id FROM core.profile WHERE profile_code = %s",
          sql_value(profile_code)
        )
        profile_id_result <- dbGetQuery(con, profile_id_query)
        
        if (nrow(profile_id_result) > 0) {
          profile_id <- profile_id_result$profile_id[1]
          
          # Build and execute insert query
          insert_element_query <- sprintf(
            "INSERT INTO core.element (profile_id, order_element, upper_depth, lower_depth, type)
       VALUES (%s, %s, %s, %s, %s)
       ON CONFLICT DO NOTHING;",
       sql_value(profile_id, is_numeric = TRUE),
       sql_value(current_row$order_element, is_numeric = TRUE),
       sql_value(upper_depth, is_numeric = TRUE),
       sql_value(lower_depth, is_numeric = TRUE),
       sql_value(type)
          )
          
          dbExecute(con, insert_element_query)
        }
      }
    }, error = function(e) {
      message(sprintf("Error during element insertion: %s", e$message))
    })
    
    # ----
    # ELEMENT-RESULTS: Insert data into the 'result_desc_element' table ----
    tryCatch({
      elements <- c(
        "BoundaryDistinctness", "BoundaryTopography", "SoilTexture", "SandfractionTexture", "FieldTexture",
        "Rockabundance", "Rocksize", "RockShape", "Rockweathering", "RockPrimary", "RockNature",
        "PeaDescomposition", "AeromorphicForest", "ColourMoist", "ColourDry", "MottlesColour",
        "MottlesAbundance", "MottlesSize", "MottlesContrast", "MottlesBoundary", "RedoxPotential",
        "ReducingConditions", "CarbonateContent", "CarbonateForms", "GypsumContent", "GypsumForms",
        "SaltContent", "FieldPH", "SoilOdour", "AndicCharacteristics", "OrganicMatter",
        "StructureGrade", "StructureType", "StructureSize", "ConsistenceDry", "ConsistenceMoist",
        "ConsistenceWet", "Stickiness", "Plasticity", "Moisture", "BulkDensity", "PeatDrainage",
        "PeatVolume", "PeatBulkDensity", "PorosityAbundance", "PorosityType", "PorositySize",
        "PoreAbundance", "CoatingsAbundance", "CoatingsContrast", "CoatingsNature", "CoatingsForm",
        "CoatingsLocation", "Cementation/compactionContinuity", "Cementation/compactionStructure",
        "Cementation/compactionNature", "Cementation/compactionDegree", "MineralConcentrationsAbundance",
        "MineralConcentrationsKind", "MineralConcentrationsSize", "MineralConcentrationsShape",
        "MineralConcentrationsHardness", "MineralConcentrationsNature", "MineralConcentrationsColour",
        "RootsSize", "RootsAbundance", "BiologicalAbundance", "BiologicalKind",
        "ArtefactAbundance", "ArtefactKind", "ArtefactSize", "ArtefactHardness",
        "ArtefactWeathering", "ArtefactColour"
      )
      
      unique_data <- site_tibble %>%
        pivot_longer(
          cols = any_of(as.character(elements)),
          names_to = "property_desc_id",
          values_to = "category_desc_id"
        )
      
      for (row in 1:nrow(unique_data)) {
        current_row <- unique_data[row, ]
        
        # Skip if value or property is missing
        if (!is.na(current_row$category_desc_id) && current_row$property_desc_id != "") {
          
          # Get profile_id from profile_code
          profile_id_query <- sprintf(
            "SELECT profile_id FROM core.profile WHERE profile_code = %s",
            sql_value(current_row$profile_code)
          )
          profile_id_result <- dbGetQuery(con, profile_id_query)
          
          if (nrow(profile_id_result) > 0) {
            profile_id <- profile_id_result$profile_id[1]
            
            # Get element_id based on profile_id and order_element
            element_id_query <- sprintf(
              "SELECT element_id FROM core.element WHERE profile_id = %s AND order_element = %s",
              sql_value(profile_id, is_numeric = TRUE),
              sql_value(current_row$order_element)
            )
            element_id_result <- dbGetQuery(con, element_id_query)
            
            if (nrow(element_id_result) > 0) {
              element_id <- element_id_result$element_id[1]
              
              # Ensure (property_desc_id, category_desc_id) is valid
              valid_combo_query <- sprintf(
                "SELECT 1 FROM core.observation_desc_element
             WHERE property_desc_id = %s AND category_desc_id = %s",
             sql_value(current_row$property_desc_id),
             sql_value(current_row$category_desc_id)
              )
              valid_combo_result <- dbGetQuery(con, valid_combo_query)
              
              if (nrow(valid_combo_result) > 0) {
                # Insert into result_desc_element
                insert_query <- sprintf(
                  "INSERT INTO core.result_desc_element (element_id, property_desc_id, category_desc_id)
               VALUES (%s, %s, %s)
               ON CONFLICT DO NOTHING;",
               sql_value(element_id, is_numeric = TRUE),
               sql_value(current_row$property_desc_id),
               sql_value(current_row$category_desc_id)
                )
                dbExecute(con, insert_query)
              } else {
                message(sprintf("Skipped invalid pair: %s / %s",
                                current_row$property_desc_id, current_row$category_desc_id))
              }
            }
          }
        }
      }
    }, error = function(e) {
      message("An error occurred in result_desc_element: ", e$message)
    })
    
    # ----
    # SPECIMEN: Insert data into the 'specimen' table ----
    tryCatch({
      for (i in 1:nrow(site_tibble)) {
        current_row <- site_tibble[i, ]
        
        # Retrieve 'profile_id' based on 'profile_code'
        profile_id_query <- sprintf(
          "SELECT profile_id FROM core.profile WHERE profile_code = %s",
          sql_value(current_row$profile_code)
        )
        profile_id_result <- dbGetQuery(con, profile_id_query)
        
        if (nrow(profile_id_result) > 0) {
          profile_id <- profile_id_result$profile_id[1]
          
          # Retrieve 'element_id' based on 'profile_id' and 'order_element'
          element_id_query <- sprintf(
            "SELECT element_id FROM core.element WHERE profile_id = %s AND order_element = %s",
            sql_value(profile_id, is_numeric = TRUE),
            sql_value(current_row$order_element)
          )
          element_id_result <- dbGetQuery(con, element_id_query)
          
          if (nrow(element_id_result) > 0) {
            element_id <- element_id_result$element_id[1]
            
            # Try to retrieve organisation_id if available
            organisation_id <- NA
            if (!is.na(current_row$organization)) {
              organisation_query <- sprintf(
                "SELECT organisation_id FROM metadata.organisation WHERE name = %s",
                sql_value(current_row$organization)
              )
              organisation_result <- dbGetQuery(con, organisation_query)
              if (nrow(organisation_result) > 0) {
                organisation_id <- organisation_result$organisation_id[1]
              }
            }
            
            # Construct and execute insert query with or without organisation_id
            if (!is.na(organisation_id)) {
              insert_specimen_query <- sprintf(
                "INSERT INTO core.specimen (element_id, organisation_id, code)
             VALUES (%s, %s, %s)
             ON CONFLICT DO NOTHING;",
             sql_value(element_id, is_numeric = TRUE),
             sql_value(organisation_id, is_numeric = TRUE),
             sql_value(current_row$specimen_code)
              )
            } else {
              insert_specimen_query <- sprintf(
                "INSERT INTO core.specimen (element_id, code)
             VALUES (%s, %s)
             ON CONFLICT DO NOTHING;",
             sql_value(element_id, is_numeric = TRUE),
             sql_value(current_row$specimen_code)
              )
            }
            
            dbExecute(con, insert_specimen_query)
          }
        }
      }
    }, error = function(e) {
      message(sprintf("Error during element specimen: %s", e$message))
    })
    
    # ----
    # SPECIMEN-RESULTS: Insert data into 'result_phys_chem' (with bounds check and individual_id support)
    tryCatch({
      property_phys_chem_id <- uploaded_df.procedure[[2]]
      procedure_phys_chem_id <- uploaded_df.procedure[[3]]
      unit_of_measure_id <- uploaded_df.procedure[[4]]
      
      ############## NEW ##############  
      
      # unique_data <- site_tibble %>%
      #   pivot_longer(
      #     cols = all_of(property_phys_chem_id),
      #     names_to = "property_phys_chem_id",
      #     values_to = "value"
      #   ) %>%
      #   left_join(
      #     uploaded_df.procedure %>%
      #       select(property_phys_chem_id, procedure_phys_chem_id, observation_phys_chem_id),
      #     by = "property_phys_chem_id"
      #   )
      
      unique_data <- site_tibble %>%
        pivot_longer(
          cols = all_of(property_phys_chem_id),
          names_to = "property_phys_chem_id",
          values_to = "value"
        ) %>%
        mutate(procedure_phys_chem_id = rep(procedure_phys_chem_id, length.out = n()))
      
      ############## END NEW ##############  
    
      for (row in 1:nrow(unique_data)) {
        current_row <- unique_data[row, ]
        
        # 1. Get observation ID and bounds
        bounds_query <- sprintf(
          "SELECT observation_phys_chem_id, value_min, value_max FROM core.observation_phys_chem
       WHERE property_phys_chem_id = %s AND procedure_phys_chem_id = %s;",
       sql_value(current_row$property_phys_chem_id),
       sql_value(current_row$procedure_phys_chem_id)
        )
        bounds_result <- dbGetQuery(con, bounds_query)
        
        # 2. Get specimen ID
        specimen_query <- sprintf(
          "SELECT specimen_id FROM core.specimen WHERE code = %s;",
          sql_value(current_row$specimen_code)
        )
        specimen_result <- dbGetQuery(con, specimen_query)
        
        # 3. Get individual_id from metadata.individual (with fallback for NA)
        individual_id <- NA
        safe_name <- ifelse(is.na(current_row$name), "", current_row$name)
        safe_email <- ifelse(is.na(current_row$email), "", current_row$email)
        
        individual_query <- sprintf(
          "SELECT individual_id FROM metadata.individual
       WHERE COALESCE(name, '') = %s AND COALESCE(email, '') = %s;",
       sql_value(safe_name),
       sql_value(safe_email)
        )
        individual_result <- dbGetQuery(con, individual_query)
        if (nrow(individual_result) > 0) {
          individual_id <- individual_result$individual_id[1]
        }
        
        # 4. Proceed if required IDs exist
        if (nrow(bounds_result) > 0 && nrow(specimen_result) > 0) {
          observation_id <- bounds_result$observation_phys_chem_id[1]
          specimen_id <- specimen_result$specimen_id[1]
          value <- as.numeric(current_row$value)
          
          if (!is.na(value)) {
            value_min <- bounds_result$value_min[1]
            value_max <- bounds_result$value_max[1]
            
            
            # 5. Check bounds and show message if outside
            
            if ((!is.na(value_min) && value < value_min) || (!is.na(value_max) && value > value_max)) {
              error_msg <- sprintf(
                "ERROR: Value %.3f for property '%s' (specimen_code: '%s') is outside admissible bounds [%.3f – %.3f].",
                value,
                current_row$property_phys_chem_id,
                current_row$specimen_code,
                ifelse(is.na(value_min), -Inf, value_min),
                ifelse(is.na(value_max),  Inf, value_max)
              )
              
              # Show the error in Shiny
              shiny::showNotification(error_msg, type = "error", duration = 10, session = session)
              
              # Append to log file
              timestamped_msg <- sprintf("[%s] %s\n", Sys.time(), error_msg)
              write(timestamped_msg, file = log_file, append = TRUE)
              
              next
            }
            
            # 6. Insert with or without individual_id
            if (!is.na(individual_id)) {
              insert_query <- sprintf(
                "INSERT INTO core.result_phys_chem (observation_phys_chem_id, specimen_id, individual_id, value)
             VALUES (%s, %s, %s, %f)
             ON CONFLICT DO NOTHING;",
             sql_value(observation_id, is_numeric = TRUE),
             sql_value(specimen_id, is_numeric = TRUE),
             sql_value(individual_id, is_numeric = TRUE),
             value
              )
            } else {
              insert_query <- sprintf(
                "INSERT INTO core.result_phys_chem (observation_phys_chem_id, specimen_id, value)
             VALUES (%s, %s, %f)
             ON CONFLICT DO NOTHING;",
             sql_value(observation_id, is_numeric = TRUE),
             sql_value(specimen_id, is_numeric = TRUE),
             value
              )
            }
            
            dbExecute(con, insert_query)
          }
        }
      }
    }, error = function(e) {
      message("An error occurred in result_phys_chem: ", e$message)
    })
    
    
    
    # ----
    # After rendering, remove the modal
    removeModal()
    # Notify the user it's ready
    shiny::showNotification("Data processed successfully!", type = "error")
  }
    