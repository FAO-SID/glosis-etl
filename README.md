<![CDATA[<p align="center">
  <img src="www/fao_logo1.png" alt="FAO Logo" height="120">
</p>

<h1 align="center">GloSIS ETL Platform</h1>

<p align="center">
  <strong>Soil Data Harmonization, Standardization & Visualization</strong><br>
  A Dockerized platform for transforming heterogeneous soil datasets into the <a href="https://www.fao.org/global-soil-partnership/areas-of-work/soil-information-and-data/en/">GloSIS ISO-28258</a> standard.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/R-4.3.2-blue?logo=r" alt="R Version">
  <img src="https://img.shields.io/badge/Shiny_Server-Open_Source-green?logo=rstudio" alt="Shiny Server">
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white" alt="Docker Compose">
  <img src="https://img.shields.io/badge/PostgreSQL-PostGIS-336791?logo=postgresql&logoColor=white" alt="PostGIS">
  <img src="https://img.shields.io/badge/Platform-amd64%20%7C%20arm64-orange" alt="Multi-Platform">
</p>

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Applications](#applications)
- [Project Structure](#project-structure)
- [Database](#database)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Contact](#contact)

---

## Overview

The **GloSIS ETL Platform** is a suite of three interconnected Shiny web applications designed to support the full lifecycle of soil data management following the **ISO 28258** domain model:

1. **Harmonization** — Convert and harmonize raw soil datasets (CSV/XLSX) into the GloSIS template format.
2. **Standardization** — Inject harmonized data into a PostgreSQL/PostGIS database following the ISO 28258 schema.
3. **Data Viewer** — Explore and visualize ingested soil data with interactive maps, tables, and property distributions.

All applications run inside Docker containers alongside a PostGIS database, providing a reproducible, self-contained environment.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Docker Compose                        │
│                                                          │
│  ┌─────────────────────┐    ┌─────────────────────────┐  │
│  │   glosis-etl        │    │    glosis-db             │  │
│  │   (Shiny Server)    │───▶│    (PostGIS 17-3.5)      │  │
│  │                     │    │                           │  │
│  │  ┌───────────────┐  │    │  • ISO-28258 Schema      │  │
│  │  │ Landing Page  │  │    │  • Spatial Queries        │  │
│  │  │ (index.html)  │  │    │  • Persistent Storage     │  │
│  │  ├───────────────┤  │    └─────────────────────────┘  │
│  │  │ /harmonization│  │                                  │
│  │  ├───────────────┤  │    ┌─────────────────────────┐  │
│  │  │/standardizat. │  │    │  pgAdmin (optional)      │  │
│  │  ├───────────────┤  │    │  Profile: "admin"        │  │
│  │  │ /dataviewer   │  │    └─────────────────────────┘  │
│  │  └───────────────┘  │                                  │
│  └─────────────────────┘                                  │
└──────────────────────────────────────────────────────────┘
```

| Service        | Port   | Description                                |
|----------------|--------|--------------------------------------------|
| `glosis-etl`   | `3838` | Landing page + Shiny applications          |
| `postgis`      | `5442` | PostgreSQL with PostGIS (mapped to host)   |
| `pgadmin`      | `5050` | pgAdmin web UI (optional, `--profile admin`) |

---

## Prerequisites

- **Docker Desktop** ≥ 4.0 (or Docker Engine + Docker Compose v2)
  - [Download for macOS](https://docs.docker.com/desktop/install/mac-install/)
  - [Download for Windows](https://docs.docker.com/desktop/install/windows-install/)
  - [Download for Linux](https://docs.docker.com/desktop/install/linux/)
- **Git** (to clone the repository)
- Minimum **4 GB RAM** allocated to Docker
- Minimum **5 GB disk space** (Docker images + database)

> **Note**: The platform supports both **Intel/AMD (amd64)** and **Apple Silicon (arm64)** architectures natively.

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/FAO-SID/Glosis-ETL.git
cd Glosis-ETL
```

### 2. Configure Environment Variables

```bash
cp .env.example .env
```

Edit `.env` to customize your database credentials (defaults work out of the box):

```env
POSTGRES_DB=glosis
POSTGRES_USER=glosis
POSTGRES_PASSWORD=glosis        # ⚠️ Change in production!
```

### 3. Build and Start

```bash
docker compose up -d --build
```

> **First build** may take 10–20 minutes (R package compilation). Subsequent builds use Docker cache and are much faster.

### 4. Access the Platform

| Application      | URL                                  |
|------------------|--------------------------------------|
| **Landing Page** | http://localhost:3838                 |
| **Harmonization**| http://localhost:3838/harmonization   |
| **Standardization** | http://localhost:3838/standardization |
| **Data Viewer**  | http://localhost:3838/dataviewer      |

---

## Configuration

### Environment Variables (`.env`)

| Variable             | Default   | Description                          |
|----------------------|-----------|--------------------------------------|
| `POSTGRES_DB`        | `glosis`  | Database name                        |
| `POSTGRES_USER`      | `glosis`  | Database admin username              |
| `POSTGRES_PASSWORD`  | `glosis`  | Database admin password              |
| `SHINY_LOG_LEVEL`    | `INFO`    | Logging level (`DEBUG`, `INFO`, `WARN`, `ERROR`) |
| `R_MAX_MEM_SIZE`     | `2Gb`     | R memory limit                       |

### Database Credentials (`init-scripts/credentials.R`)

The Shiny apps read database credentials from environment variables injected by Docker Compose. You do **not** need to edit `credentials.R` unless running outside Docker.

### Optional: pgAdmin

To enable the pgAdmin database management UI:

```bash
docker compose --profile admin up -d
```

Access at http://localhost:5050 with:
- **Email**: `admin@glosis.org`
- **Password**: `admin`

---

## Applications

Each application has its own detailed documentation:

| App | Description | Docs |
|-----|-------------|------|
| 🔄 **Harmonization** | Convert raw soil data to GloSIS format | [apps/harmonization/README.md](apps/harmonization/README.md) |
| 📥 **Standardization** | Inject harmonized data into GloSIS database | [apps/standardization/README.md](apps/standardization/README.md) |
| 🗺️ **Data Viewer** | Explore and visualize ingested data | [apps/dataviewer/README.md](apps/dataviewer/README.md) |

---

## Project Structure

```
glosis-etl/
├── README.md                      # This file
├── Dockerfile                     # Multi-platform Docker image (amd64 + arm64)
├── docker-compose.yml             # Service orchestration
├── .env.example                   # Template for environment variables
├── .gitignore                     # Git ignore rules
├── index.html                     # Landing page (served at /)
│
├── apps/
│   ├── harmonization/             # Harmonization Shiny App
│   │   ├── README.md
│   │   ├── ui.R
│   │   ├── server.R
│   │   ├── glosis_template_v6.xlsx   # GloSIS template
│   │   └── glosis_procedures_v2.csv  # Procedure mappings
│   │
│   ├── standardization/           # Standardization / Data Injection App
│   │   ├── README.md
│   │   ├── ui.R
│   │   ├── server.R
│   │   ├── global.R               # Global settings & helpers
│   │   ├── fill_tables.R          # Database injection logic
│   │   ├── dashboard.Rmd          # Flexdashboard report template
│   │   ├── credentials.R          # DB credentials (app-level)
│   │   └── glosis_procedures.csv  # Procedure reference data
│   │
│   ├── dataviewer/                # Data Viewer / Dashboard App
│   │   ├── README.md
│   │   ├── ui.R
│   │   └── server.R
│   │
│   └── www/                       # Shared assets for apps
│
├── www/                           # Landing page assets
│   ├── fao_logo1.png
│   ├── glosis_maize.png
│   ├── glosis_trees.png
│   └── custom.css
│
└── init-scripts/                  # PostgreSQL initialization
    ├── credentials.R              # Shared DB credentials
    └── glosis-db_latest.sql       # GloSIS ISO-28258 schema
```

---

## Database

### Schema

The database follows the **ISO 28258** domain model implemented by the [GloSIS repository](https://github.com/FAO-SID/GloSIS). The schema is initialized automatically on first launch from `init-scripts/glosis-db_latest.sql`.

### Key Tables

| Schema | Table | Description |
|--------|-------|-------------|
| `core` | `project` | Research projects |
| `core` | `site` | Sampling sites |
| `core` | `plot` | Sampling plots (with PostGIS geometry) |
| `core` | `profile` | Soil profiles |
| `core` | `element` | Soil horizons/layers |
| `core` | `specimen` | Laboratory specimens |
| `core` | `observation_phys_chem` | Property definitions |
| `core` | `result_phys_chem` | Analytical results |

### Connecting Externally

From host machine (e.g., RStudio, DBeaver, QGIS):

```
Host:     localhost
Port:     5442
Database: glosis
User:     glosis
Password: glosis
```

---

## Development

### Running Apps Locally (Outside Docker)

> Requires R ≥ 4.3 and all dependencies installed locally.

1. Start only the database:
   ```bash
   docker compose up -d postgis
   ```

2. Edit `init-scripts/credentials.R` — uncomment the local connection lines:
   ```r
   host_name <- "localhost"
   port_number <- "5442"
   ```

3. Open the app in RStudio and click **Run App**.

### Rebuilding After Code Changes

```bash
docker compose up -d --build
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Shiny Server only
docker compose logs -f glosis-etl

# Database only
docker compose logs -f postgis
```

### Stopping the Platform

```bash
# Stop all services (data is preserved)
docker compose down

# Stop and remove all data (⚠️ destructive)
docker compose down -v
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Build fails on Apple Silicon** | Ensure Docker Desktop ≥ 4.25. The Dockerfile handles arm64 natively. |
| **"Connection refused" to database** | Wait for the health check (`docker compose ps`). PostGIS needs ~30s to initialize. |
| **Apps show blank page** | Check Shiny logs: `docker compose logs glosis-etl` |
| **Port 3838/5442 already in use** | Change port mapping in `docker-compose.yml` (e.g., `"3839:3838"`) |
| **Out of memory during R package install** | Increase Docker memory to ≥ 4 GB in Docker Desktop → Settings → Resources |
| **Schema not loaded** | Verify `init-scripts/glosis-db_latest.sql` is present. The schema loads only on first database creation. To reload: `docker compose down -v && docker compose up -d` |

---

## License

This project is developed by the **Global Soil Partnership** at the **Food and Agriculture Organization of the United Nations (FAO)**.

---

## Contact

- **Author**: Luis Rodriguez Lado — [luis.rodriguezlado@fao.org](mailto:luis.rodriguezlado@fao.org)
- **Organization**: [FAO Global Soil Partnership](https://www.fao.org/global-soil-partnership/)
- **Repository**: [github.com/FAO-SID/Glosis-ETL](https://github.com/FAO-SID/Glosis-ETL)
]]>
