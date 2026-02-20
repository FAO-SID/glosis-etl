# ============================================================================
# GLOBAL.R - GLOSIS ISO-28258 Standardization Database Application
# Complete replacement with robust SQL file execution
# ============================================================================
# Author: Luis Rodriguez Lado (FAO)
# Purpose: Global configuration for Shiny application
# Key fixes: 
#   - Robust SQL file execution (auto-finds and downloads)
#   - Working credentials for Docker environment
#   - Proper error handling throughout
# ============================================================================

# ============================================================================
# SECTION 1: LOAD REQUIRED PACKAGES
# ============================================================================

options(shiny.maxRequestSize = 100*1024^2)  # 100MB

message("[INFO] Loading required packages...")

packages <- c(
  "shiny",
  "shinydashboard",
  "shinycssloaders",
  "RPostgres",
  "DBI",
  "DT",
  "shinyjs",
  "readxl",
  "dplyr",
  "jsonlite",
  "digest",
  "utils",
  "tidyr"
)

for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    message(sprintf("[WARNING] Package '%s' not found", pkg))
  }
}

message("[INFO] Packages loaded successfully")

# ============================================================================
# SECTION 2: DATABASE CREDENTIALS
# ============================================================================
# Working credentials that are compatible with Docker environment

message("[INFO] Setting up database credentials...")

# Load credentials for the docker database container
source("/srv/shiny-server/init-scripts/credentials.R")

# # Get from environment variables or use defaults
# database_name <- Sys.getenv("DB_NAME", "glosis")
# host_name <- Sys.getenv("DB_HOST", "glosis-db")
# port_number <- as.numeric(Sys.getenv("DB_PORT", "5432"))
# user_name <- Sys.getenv("DB_USER", "glosis")
# password_name <- Sys.getenv("DB_PASSWORD", "glosis")
# 
# # Global configuration
# global_pass <- ""
# 
# # Database schema URL
# sql_file_url <- "https://raw.githubusercontent.com/FAO-SID/GloSIS/refs/heads/main/glosis-db/versions/glosis-db_latest.sql"

message(sprintf("[INFO] Database: %s", database_name))
message(sprintf("[INFO] Host: %s", host_name))
message(sprintf("[INFO] Port: %d", port_number))
message(sprintf("[INFO] User: %s", user_name))

# ============================================================================
# SECTION 3: SQL FILE PATH CONFIGURATION
# ============================================================================

message("[INFO] Configuring SQL file path...")

sql_file_path <- "/srv/shiny-server/init-scripts/glosis-db_latest.sql"

message(sprintf("[INFO] SQL file path: %s", sql_file_path))

# ============================================================================
# SECTION 4: ROBUST SQL FILE EXECUTION FUNCTION
# ============================================================================
# This function properly handles SQL file execution with PL/pgSQL functions

execute_sql_file_robust <- function(
    con,
    database_name,
    host_name,
    port_number,
    user_name,
    password_name
) {
  
  message("[INFO] Starting robust SQL file execution...")
  
  # ────────────────────────────────────────────────────────────
  # Step 1: Try to find the SQL file
  # ────────────────────────────────────────────────────────────
  
  possible_paths <- c(
    "/srv/shiny-server/init-scripts/glosis-db_latest.sql",
    "/docker-entrypoint-initdb.d/glosis-db_latest.sql",
    "~/init-scripts/glosis-db_latest.sql",
    "./init-scripts/glosis-db_latest.sql",
    "./glosis-db_latest.sql"
  )
  
  sql_file_path <- NULL
  
  message("[DEBUG] Searching for SQL file in possible locations...")
  for (path in possible_paths) {
    if (file.exists(path)) {
      sql_file_path <- path
      file_size <- file.info(path)$size
      message(sprintf("[INFO] ✅ Found SQL file: %s (%s bytes)", 
                      sql_file_path, 
                      format(file_size, big.mark = ",")))
      break
    }
  }
  
  # ────────────────────────────────────────────────────────────
  # Step 2: If not found, try to download it
  # ────────────────────────────────────────────────────────────
  
  if (is.null(sql_file_path)) {
    message("[WARNING] SQL file not found in standard locations")
    message("[INFO] Attempting to download SQL file from GitHub...")
    
    # Create directory if it doesn't exist
    init_dir <- "/srv/shiny-server/init-scripts"
    if (!dir.exists(init_dir)) {
      dir.create(init_dir, recursive = TRUE, showWarnings = FALSE)
      message(sprintf("[INFO] Created directory: %s", init_dir))
    }
    
    sql_file_path <- file.path(init_dir, "glosis-db_latest.sql")
    
    # Try to download
    tryCatch({
      message(sprintf("[INFO] Downloading from: %s", sql_file_url))
      download.file(sql_file_url, destfile = sql_file_path, mode = "wb", quiet = TRUE)
      file_size <- file.info(sql_file_path)$size
      message(sprintf("[INFO] ✅ Downloaded successfully (%s bytes)", 
                      format(file_size, big.mark = ",")))
    }, error = function(e) {
      message(sprintf("[ERROR] Failed to download SQL file: %s", e$message))
      return(FALSE)
    })
  }
  
  # ────────────────────────────────────────────────────────────
  # Step 3: Final verification
  # ────────────────────────────────────────────────────────────
  
  if (!file.exists(sql_file_path)) {
    message("[ERROR] SQL file not found after all attempts!")
    message("[ERROR] Checked these locations:")
    for (path in possible_paths) {
      message(sprintf("[ERROR]   - %s", path))
    }
    return(FALSE)
  }
  
  # ────────────────────────────────────────────────────────────
  # Step 4: Execute with psql command
  # ────────────────────────────────────────────────────────────
  
  message("[INFO] Executing SQL file with psql...")
  message(sprintf("[DEBUG] Database: %s, Host: %s, Port: %d, User: %s", 
                  database_name, host_name, port_number, user_name))
  
  # Build psql command with proper quoting
  psql_command <- sprintf(
    "PGPASSWORD='%s' psql -h '%s' -p %d -U '%s' -d '%s' -f '%s' 2>&1",
    password_name,
    host_name,
    as.numeric(port_number),
    user_name,
    database_name,
    sql_file_path
  )
  
  # Execute the command
  output <- system(psql_command, intern = TRUE)
  
  # ────────────────────────────────────────────────────────────
  # Step 5: Handle and display output
  # ────────────────────────────────────────────────────────────
  
  if (length(output) == 0) {
    message("[INFO] ✅ SQL file executed successfully (no output)")
    return(TRUE)
  }
  
  # Display output
  message("[INFO] psql output:")
  for (i in 1:min(20, length(output))) {
    line <- output[i]
    if (grepl("ERROR", line, ignore.case = TRUE)) {
      message(sprintf("[psql-ERROR] %s", line))
    } else if (grepl("WARNING", line, ignore.case = TRUE)) {
      message(sprintf("[psql-WARNING] %s", line))
    } else {
      message(sprintf("[psql] %s", line))
    }
  }
  
  if (length(output) > 20) {
    message(sprintf("[INFO] ... and %d more lines", length(output) - 20))
  }
  
  # Check for critical errors
  has_critical_errors <- any(grepl("^ERROR", output, ignore.case = TRUE) & 
                               !grepl("already exists|duplicate", output, ignore.case = TRUE))
  
  if (has_critical_errors) {
    message("[ERROR] SQL execution had critical errors")
    return(FALSE)
  } else {
    message("[INFO] ✅ SQL executed successfully!")
    return(TRUE)
  }
}

# ============================================================================
# SECTION 5: FUNCTION TO CREATE DATABASE TABLES
# ============================================================================
# This is the main function called when a new database is created

createTables <- function(database_name, host_name, port_number, user_name, password_name) {
  
  message("[INFO] Creating database tables...")
  
  # ────────────────────────────────────────────────────────────
  # Connect to the default postgres database to create roles
  # ────────────────────────────────────────────────────────────
  
  message("[INFO] Connecting to PostgreSQL to create roles...")
  
  con <- tryCatch({
    dbConnect(RPostgres::Postgres(),
              dbname = "postgres",
              host = host_name,
              port = port_number,
              user = user_name,
              password = password_name)
  }, error = function(e) {
    message(sprintf("[ERROR] Failed to connect to PostgreSQL: %s", e$message))
    return(NULL)
  })
  
  if (is.null(con)) {
    return(FALSE)
  }
  
  # ────────────────────────────────────────────────────────────
  # Create the 'glosis' role if it doesn't exist
  # ────────────────────────────────────────────────────────────
  
  tryCatch({
    dbExecute(con, "DO $$ BEGIN
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'glosis') THEN
        CREATE ROLE glosis LOGIN PASSWORD 'glosis';
      END IF;
    END $$;")
    message("[INFO] Role 'glosis' ensured")
  }, error = function(e) {
    message(sprintf("[WARNING] Error with role 'glosis': %s", e$message))
  })
  
  # ────────────────────────────────────────────────────────────
  # Create the 'glosis_r' role if it doesn't exist
  # ────────────────────────────────────────────────────────────
  
  tryCatch({
    dbExecute(con, "DO $$ BEGIN
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'glosis_r') THEN
        CREATE ROLE glosis_r LOGIN PASSWORD 'glosis';
      END IF;
    END $$;")
    message("[INFO] Role 'glosis_r' ensured")
  }, error = function(e) {
    message(sprintf("[WARNING] Error with role 'glosis_r': %s", e$message))
  })
  
  dbDisconnect(con)
  
  # ────────────────────────────────────────────────────────────
  # Execute the SQL file using the robust function
  # ────────────────────────────────────────────────────────────
  
  result <- execute_sql_file_robust(
    con = NULL,  # Not used in robust function
    database_name = database_name,
    host_name = host_name,
    port_number = port_number,
    user_name = user_name,
    password_name = password_name
  )
  
  if (!result) {
    message("[ERROR] Failed to execute SQL file")
    return(FALSE)
  }
  
  message("[INFO] ✅ Database tables created successfully")
  return(TRUE)
}

# ============================================================================
# SECTION 6: FUNCTION TO CREATE AND CONNECT TO DATABASE
# ============================================================================

createDatabase <- function(database_name, host_name, port_number, user_name, password_name) {
  
  message(sprintf("[INFO] Creating/connecting to database: %s", database_name))
  
  # ────────────────────────────────────────────────────────────
  # Connect to the default postgres database
  # ────────────────────────────────────────────────────────────
  
  con <- tryCatch({
    dbConnect(RPostgres::Postgres(),
              dbname = "postgres",
              host = host_name,
              port = port_number,
              user = user_name,
              password = password_name)
  }, error = function(e) {
    message(sprintf("[ERROR] Unable to connect to PostgreSQL: %s", e$message))
    return(NULL)
  })
  
  if (is.null(con)) {
    return(list(con = NULL, message = "Failed to connect to the PostgreSQL server."))
  }
  
  # ────────────────────────────────────────────────────────────
  # Check if the database exists
  # ────────────────────────────────────────────────────────────
  
  dbExists <- dbGetQuery(con, sprintf("SELECT 1 FROM pg_database WHERE datname = '%s'", database_name))
  
  messageContent <- ""
  backgroundColor <- ""
  backgroundBorder <- ""
  
  if (nrow(dbExists) == 0) {
    # Create the database if it doesn't exist
    message(sprintf("[INFO] Creating database: %s", database_name))
    
    tryCatch({
      dbExecute(con, sprintf("CREATE DATABASE \"%s\";", database_name))
      message(sprintf("[INFO] ✅ Database '%s' created", database_name))
      messageContent <- sprintf("Database '%s' created", database_name)
      backgroundColor <- "darkorange"
      backgroundBorder <- "yellow"
    }, error = function(e) {
      message(sprintf("[ERROR] Error creating database: %s", e$message))
      dbDisconnect(con)
      return(NULL)
    })
  } else {
    message(sprintf("[INFO] Database '%s' already exists", database_name))
    messageContent <- sprintf("The database '%s' already exists", database_name)
    backgroundColor <- "dodgerblue"
    backgroundBorder <- "white"
  }
  
  dbDisconnect(con)
  
  # ────────────────────────────────────────────────────────────
  # Connect to the newly created/existing database
  # ────────────────────────────────────────────────────────────
  
  message(sprintf("[INFO] Connecting to database: %s", database_name))
  
  newCon <- tryCatch({
    dbConnect(RPostgres::Postgres(),
              dbname = database_name,
              host = host_name,
              port = port_number,
              user = user_name,
              password = password_name)
  }, error = function(e) {
    message(sprintf("[ERROR] Unable to connect to database '%s': %s", database_name, e$message))
    return(NULL)
  })
  
  if (is.null(newCon)) {
    return(list(con = NULL, message = sprintf("Failed to connect to the database '%s'.", database_name)))
  }
  
  message(sprintf("[INFO] ✅ Connected to database: %s", database_name))
  
  # ────────────────────────────────────────────────────────────
  # Create tables in the database
  # ────────────────────────────────────────────────────────────
  
  message("[INFO] Creating database schema...")
  
  tryCatch({
    tables_created <- createTables(database_name, host_name, port_number, user_name, password_name)
    if (!tables_created) {
      message("[ERROR] Failed to create tables")
      return(list(con = newCon, message = "Failed to create tables."))
    }
    message("[INFO] ✅ Schema created successfully")
  }, error = function(e) {
    message(sprintf("[ERROR] Error creating tables: %s", e$message))
    return(list(con = newCon, message = "Failed to create tables."))
  })
  
  return(list(
    con = newCon,
    message = messageContent,
    backcolor = backgroundColor,
    backborder = backgroundBorder
  ))
}

# ============================================================================
# SECTION 7: TABLE DEFINITIONS FOR DATA HARMONIZATION
# ============================================================================
# These define the expected columns for each data table

message("[INFO] Defining table structures...")

# Plot table columns
plot_table.names <- c(
  "project_name", "site_code", "plot_code", "profile_code",
  "plot_type", "n_layers", "date", "longitude", "latitude", 
  "altitude", "positional_accuracy", "extent", "map_sheet_code",
  "TemperatureRegime", "MoistureRegime", "KoeppenClass", 
  "CurrentWeatherConditions", "PastWeatherConditions",
  "Landuse", "Vegetation", "Croptype", "BareSoilAbundance", 
  "TreeDensity", "ForestAbundance",
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

# Profile table columns
profile_table.names <- c(
  "profile_code", "descriptionStatus", "soilGroupWRB", "soilClassificationWRB",
  "SoilSpecifierWRB", "SupplementaryQualifierWRB", "soilPhase",
  "soilOrderUSDA", "soilSuborderUSDA", "formativeElementUSDA",
  "SoilDepthtoBedrock", "EffectiveSoilDepth"
)

# Element table columns
element_table.names <- c(
  "profile_code", "element_code", "type", "order_element", "upper_depth", "lower_depth",
  "horizon_code", "BoundaryDistinctness", "BoundaryTopography",
  "SoilTexture", "SandfractionTexture", "FieldTexture",
  "Rockabundance", "Rocksize", "RockShape",
  "Rockweathering", "RockPrimary", "RockNature",
  "PeaDescomposition", "AeromorphicForest", "ColourMoist",
  "ColourDry", "MottlesColour", "MottlesAbundance",
  "MottlesSize", "MottlesContrast", "MottlesBoundary",
  "RedoxPotential", "ReducingConditions", "CarbonateContent",
  "CarbonateForms", "GypsumContent", "GypsumForms",
  "SaltContent", "FieldPH", "SoilOdour",
  "AndicCharacteristics", "OrganicMatter", "StructureGrade",
  "StructureType", "StructureSize", "ConsistenceDry",
  "ConsistenceMoist", "ConsistenceWet", "Stickiness",
  "Plasticity", "Moisture", "BulkDensity",
  "PeatDrainage", "PeatVolume", "PeatBulkDensity",
  "PorosityAbundance", "PorosityType", "PorositySize",
  "PoreAbundance", "CoatingsAbundance", "CoatingsContrast",
  "CoatingsNature", "CoatingsForm", "CoatingsLocation",
  "Cementation/compactionContinuity", "Cementation/compactionStructure", "Cementation/compactionNature",
  "Cementation/compactionDegree", "MineralConcentrationsAbundance", "MineralConcentrationsKind",
  "MineralConcentrationsSize", "MineralConcentrationsShape", "MineralConcentrationsHardness",
  "MineralConcentrationsNature", "MineralConcentrationsColour", "RootsSize",
  "RootsAbundance", "BiologicalAbundance", "BiologicalKind",
  "ArtefactAbundance", "ArtefactKind", "ArtefactSize",
  "ArtefactHardness", "ArtefactWeathering", "ArtefactColour"
)

message("[INFO] ✅ Global configuration completed successfully")