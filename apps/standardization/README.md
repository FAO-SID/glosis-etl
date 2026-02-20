<![CDATA[# 📥 GloSIS Standardization App

**Inject harmonized soil data into a PostgreSQL/PostGIS database following the ISO 28258 schema.**

---

## Purpose

The Standardization app takes a harmonized GloSIS XLSX file (produced by the [Harmonization app](../harmonization/README.md)) and injects its contents into the GloSIS ISO-28258 PostgreSQL database. It handles:

- **Database management** — Create, connect to, and delete GloSIS databases
- **Schema initialization** — Automatically create the ISO 28258 table structure
- **Data injection** — Parse the XLSX file and populate all related database tables
- **Data validation** — Display the injected data in interactive tables organized by entity group
- **Dashboard generation** — Generate interactive HTML dashboards from the stored data

---

## Workflow

```
┌──────────────┐     ┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│  Create or   │────▶│  Upload      │────▶│  Inject Data  │────▶│  Review in   │
│  Connect DB  │     │  GloSIS XLSX │     │  into Tables  │     │  Data Tabs   │
└──────────────┘     └──────────────┘     └───────────────┘     └──────────────┘
```

### Step-by-Step

1. **Database Connection**
   - Select an existing database from the dropdown, or
   - Type a new name and click **"Create"** to create a fresh database with the GloSIS schema

2. **Connect to the database**
   - Click **"Connect"** to establish a connection
   - The app creates the ISO-28258 schema if it does not exist

3. **Upload harmonized data**
   - Upload an XLSX file produced by the Harmonization app
   - Click **"Inject"** to populate the database tables

4. **Review the data**
   - Navigate through tabs: **Project & Site**, **Plot**, **Surface**, **Element**, **Specimen**, **Observations**, **Results**
   - Each tab shows the corresponding database table with filtering and export options

5. **Optional: Generate Dashboard**
   - Create an interactive HTML dashboard for visual exploration

---

## Key Files

| File | Description |
|------|-------------|
| `ui.R` | Dashboard UI with sidebar (DB controls) and tabbed data views |
| `server.R` | Database connection, schema creation, data injection orchestration |
| `global.R` | Library loading, global settings, helper functions |
| `fill_tables.R` | Core injection logic — maps XLSX data to ISO-28258 tables |
| `credentials.R` | Database credentials (app-level, reads from environment) |
| `dashboard.Rmd` | Flexdashboard template for interactive HTML report |
| `glosis_procedures.csv` | Reference data for analytical procedures |

---

## Database Operations

### Creating a New Database

When you click **"Create"** with a new database name, the app:

1. Connects to the `postgres` system database
2. Creates the new database
3. Enables the PostGIS extension
4. Executes the GloSIS schema SQL (`glosis-db_latest.sql`)

### Data Injection Process

The `fill_tables.R` script handles the injection in this order:

1. **Project** — Creates project record
2. **Site** — Creates site with project linkage
3. **Plot** — Creates plot with PostGIS geometry (point from lat/lon)
4. **Profile** — Creates soil profile record
5. **Element** — Creates horizon/layer records with depth information
6. **Specimen** — Creates specimen records
7. **Observations** — Creates observation definitions
8. **Results** — Populates physical/chemical results

### Deleting a Database

The **"Delete"** button drops the selected database. This action is **irreversible**.

---

## Technical Details

### Libraries Used

| Library | Purpose |
|---------|---------|
| `shiny` / `shinydashboard` | Web framework and UI |
| `shinyjs` | JavaScript utilities (enable/disable buttons) |
| `shinycssloaders` | Loading spinners for data tables |
| `DBI` / `RPostgres` / `rpostgis` | Database connectivity |
| `DT` | Interactive data tables |
| `dplyr` / `tidyr` | Data transformation |
| `readxl` | Reading uploaded XLSX files |
| `openxlsx` | Excel file handling |
| `rmarkdown` / `flexdashboard` | Dashboard generation |
| `crosstalk` | Interactive widget linking (dashboard) |
| `leaflet` | Map rendering (dashboard) |
| `reactable` / `reactablefmtr` | Enhanced data display (dashboard) |

### Tab Structure

| Tab | Database Tables Displayed |
|-----|---------------------------|
| **Project & Site** | `project`, `site`, `project_related`, `project_site` |
| **Plot** | `plot`, `result_desc_plot` |
| **Surface** | `surface`, `profile`, `result_desc_surface`, `result_desc_profile` |
| **Element** | `element`, `result_desc_element` |
| **Specimen** | `specimen` |
| **Observations** | `observation_phys_chem`, `observation_desc_*` |
| **Results** | `result_phys_chem`, `result_desc_*` |

---

## Access

- **URL**: http://localhost:3838/standardization
- **From Landing Page**: Click the **"Standardization"** card
]]>
