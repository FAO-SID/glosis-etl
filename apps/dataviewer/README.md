<![CDATA[# 🗺️ GloSIS Data Viewer

**Explore and visualize soil data stored in the GloSIS ISO-28258 database.**

---

## Purpose

The Data Viewer provides an interactive dashboard for exploring soil data that has been injected into the database via the [Standardization app](../standardization/README.md). It features:

- **Interactive Map** — Leaflet map showing soil sampling locations with popups
- **Property Distributions** — Reactable table with data bars for Visual comparison of soil property values across sites
- **Data Table** — Full filterable data table with export options
- **Cross-filtering** — All three views are linked via `crosstalk`, enabling interactive filtering across the map, property table, and data table

---

## Layout

```
┌───────────────────────┬───────────────────────────────────────┐
│                       │                                       │
│   Soil Profile        │   Vertical Distribution of            │
│   Selection           │   Soil Properties                     │
│   (Leaflet Map)       │   (Reactable with Data Bars)          │
│                       │                                       │
│                       │   [Select Properties ▼]               │
│                       │   ┌─────┬─────┬─────┬─────┐          │
│                       │   │Code │ pH  │ OC  │Sand │          │
│                       │   │─────┼█████┼███──┼████─│          │
│                       │   │─────┼███──┼████─┼██───│          │
│                       │   └─────┴─────┴─────┴─────┘          │
├───────────────────────┴───────────────────────────────────────┤
│                                                               │
│   Soil Locations (DT Data Table)                              │
│   ┌──────┬──────┬───────┬──────┬──────┬──────┬──────┐        │
│   │ code │ type │ depth │ lat  │ lon  │ pH   │ OC   │        │
│   ├──────┼──────┼───────┼──────┼──────┼──────┼──────┤        │
│   │ ...  │ ...  │ ...   │ ...  │ ...  │ ...  │ ...  │        │
│   └──────┴──────┴───────┴──────┴──────┴──────┴──────┘        │
└───────────────────────────────────────────────────────────────┘
```

---

## Workflow

1. **Connect to a Database**
   - Select a database from the dropdown in the sidebar
   - Click **"Connect to Database"**
   - A loading spinner is displayed while data is fetched

2. **Explore the Map**
   - Markers appear on the Leaflet map at sample locations
   - Click markers to see site code and project information
   - Select markers to filter the data table and property distributions

3. **Select Properties to Visualize**
   - Use the multi-select dropdown to choose which soil properties to display
   - The property table shows horizontal data bars (red) for each selected property
   - Values are normalized within each column for visual comparison

4. **Filter and Export Data**
   - The bottom data table supports column-level filtering
   - Export options: Copy, CSV, Excel, Print

---

## Key Files

| File | Description |
|------|-------------|
| `ui.R` | Dashboard layout: map box, property distribution box, data table box |
| `server.R` | Database queries, `SharedData` creation, linked rendering |

---

## Technical Details

### Cross-filtering with Crosstalk

All three output widgets share the same `crosstalk::SharedData` object, keyed by the specimen `code` column. This enables:

- **Map → Table**: Clicking a marker filters the data table
- **Table → Map**: Filtering the table highlights corresponding map markers
- **Properties ↔ Table**: Selecting rows in the property table filters the data table

### Data Pipeline

```r
# Query 1: Location data (code, type, depths, lat/lon)
# Query 2: Property data (project, site, property values)
# Join + pivot_wider → unified dataframe
# Wrap in SharedData → pass to leaflet, reactable, DT
```

### Libraries Used

| Library | Purpose |
|---------|---------|
| `shiny` / `shinydashboard` | Web framework and UI |
| `shinycssloaders` | Loading spinners |
| `DBI` / `RPostgres` | Database connectivity |
| `crosstalk` | Client-side widget linking |
| `leaflet` | Interactive map |
| `reactable` / `reactablefmtr` | Property distribution table with data bars |
| `DT` | Full data table with filtering and export |
| `dplyr` / `tidyr` | Data manipulation |

### Property Distribution Table

The property table uses `reactablefmtr::data_bars()` to render horizontal bar charts inside each cell. Features:

- **Red fill** (`#E42D3A`) matching the original dashboard style
- **Dynamic column selection** — Choose which properties to display
- **Normalized scaling** — Bars scale relative to column min/max
- **Linked selection** — Clicking rows cross-filters the map and data table

---

## Access

- **URL**: http://localhost:3838/dataviewer
- **From Landing Page**: Click the **"Data Viewer"** card
]]>
