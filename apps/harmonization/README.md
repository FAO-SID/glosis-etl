<![CDATA[# 🔄 GloSIS Harmonization App

**Convert and harmonize raw soil datasets into the GloSIS ISO-28258 template format.**

---

## Purpose

The Harmonization app transforms heterogeneous soil data files (CSV or XLSX) into. a standardized GloSIS-compatible XLSX workbook. It handles:

- **Column mapping** — Match your data columns to GloSIS properties (pH, organic carbon, texture, etc.)
- **Unit conversion** — Automatically convert between measurement units (e.g., g/kg → %, cmol/kg → meq/100g)
- **Analytical method tagging** — Assign GloSIS-standard procedure codes to each measurement
- **Metadata enrichment** — Add project name, site codes, dates, profile/plot identifiers, and horizon information
- **Template generation** — Export a ready-to-inject XLSX file following the GloSIS template structure

---

## Workflow

```
┌─────────────┐     ┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│  Upload CSV │────▶│  Configure   │────▶│  Map Columns  │────▶│  Download    │
│  or XLSX    │     │  Metadata    │     │  & Methods    │     │  GloSIS XLSX │
└─────────────┘     └──────────────┘     └───────────────┘     └──────────────┘
```

### Step-by-Step

1. **Upload your data file** (CSV or XLSX)
   - The app reads your file and displays the detected columns

2. **Configure project settings**
   - Project name (manual entry or from a column)
   - Site code (manual or from column)
   - Date (manual or from column)
   - Profile code (manual or from column)
   - Plot code and type
   - Horizon information

3. **Map soil properties**
   - The main panel shows a table of GloSIS properties
   - For each property, select the matching column from your data
   - Choose the analytical method/procedure
   - The app shows unit conversion notes where applicable

4. **Generate and download XLSX**
   - Click **"Generate XLSX"** — a spinner indicates processing
   - Once ready, click **"Download XLSX"** to save the harmonized file

---

## Key Files

| File | Description |
|------|-------------|
| `ui.R` | Dashboard UI with sidebar configuration and main data table |
| `server.R` | Core logic: column mapping, unit conversion, workbook generation |
| `glosis_template_v6.xlsx` | GloSIS template workbook (structure reference) |
| `glosis_procedures_v2.csv` | Lookup table of analytical procedures and their codes |

---

## Technical Details

### Libraries Used

| Library | Purpose |
|---------|---------|
| `shiny` / `shinydashboard` | Web framework and UI layout |
| `openxlsx` | Excel file generation |
| `readxl` | Excel file reading |
| `DT` | Interactive data tables |
| `dplyr` | Data manipulation |
| `lubridate` | Date parsing and formatting |

### Unit Conversions

The app supports automatic conversion between common soil measurement units. Conversions are applied transparently when the source unit differs from the GloSIS target unit. Examples:

- **Organic Carbon**: g/kg ↔ %
- **CEC**: cmol(+)/kg ↔ meq/100g
- **Particle Size**: g/kg ↔ %

### Output Format

The generated XLSX workbook follows the GloSIS template v6 structure with sheets for:

- Project and site metadata
- Profile and plot information
- Element (horizon) data
- Physical and chemical observations and results

---

## Access

- **URL**: http://localhost:3838/harmonization
- **From Landing Page**: Click the **"Harmonization"** card
]]>
