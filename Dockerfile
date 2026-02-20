# ============================================================================
# GLOSIS ETL - Multi-Platform (amd64 + arm64) Solution
# ============================================================================
# Base: rocker/r-ver:4.3.2 (supports both amd64 and arm64 natively)
# Shiny Server: .deb on amd64, built from source on arm64
# ============================================================================

FROM rocker/r-ver:4.3.2

LABEL maintainer="luis.rodriguezlado@fao.org"
LABEL description="GLOSIS ETL - Harmonization + Landing Page"
LABEL version="1.0.0"

# Capture target architecture for conditional logic
ARG TARGETARCH

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
  R_VERSION=4.3.2 \
  SHINY_LOG_LEVEL=INFO \
  TZ=UTC

# ============================================================================
# SYSTEM DEPENDENCIES
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  gfortran \
  libcurl4-gnutls-dev \
  libssl-dev \
  libxml2-dev \
  libcairo2-dev \
  libxt-dev \
  libfontconfig1-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  libudunits2-dev \
  libgdal-dev \
  libgeos-dev \
  libproj-dev \
  libpq-dev \
  postgresql-client \
  wget \
  curl \
  git \
  nano \
  sudo \
  gdebi-core \
  lsb-release \
  zip \
  unzip \
  && rm -rf /var/lib/apt/lists/*

# ============================================================================
# INSTALL SHINY SERVER (architecture-conditional)
# ============================================================================

# Install the shiny R package first (needed by Shiny Server)
RUN R -e "install.packages('shiny', repos='https://cloud.r-project.org/')"
RUN R -e "install.packages('rmarkdown', repos='https://cloud.r-project.org/')"

# --- amd64: Install pre-built .deb ---
# --- arm64: Build Shiny Server from source ---
RUN if [ "$TARGETARCH" = "amd64" ] || [ "$(dpkg --print-architecture)" = "amd64" ]; then \
  echo "=== Installing Shiny Server from .deb (amd64) ===" && \
  SHINY_SERVER_VERSION=$(wget -qO- https://download3.rstudio.org/ubuntu-20.04/x86_64/VERSION) && \
  wget --no-verbose "https://download3.rstudio.org/ubuntu-20.04/x86_64/shiny-server-${SHINY_SERVER_VERSION}-amd64.deb" -O ss-latest.deb && \
  gdebi -n ss-latest.deb && \
  rm ss-latest.deb; \
  else \
  echo "=== Building Shiny Server from source (arm64) ===" && \
  apt-get update && apt-get install -y --no-install-recommends \
  cmake \
  python3 \
  && rm -rf /var/lib/apt/lists/* && \
  cd /tmp && \
  git clone --depth 1 https://github.com/rstudio/shiny-server.git && \
  cd shiny-server && \
  mkdir tmp && cd tmp && \
  DIR=$(pwd) && \
  PATH=$DIR/../bin:$PATH && \
  PYTHON=$(which python3) && \
  cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DPYTHON="$PYTHON" ../ && \
  make -j$(nproc) && \
  ../external/node/install-node.sh && \
  (cd .. && ./bin/npm --python="$PYTHON" install --no-optional) && \
  (cd .. && ./bin/npm --python="$PYTHON" rebuild) && \
  make install && \
  ln -s /usr/local/shiny-server/bin/shiny-server /usr/bin/shiny-server && \
  cd / && rm -rf /tmp/shiny-server; \
  fi

# Create shiny user and directories (the .deb creates the user on amd64; source build does not)
RUN id -u shiny &>/dev/null || useradd -r -m shiny && \
  mkdir -p /srv/shiny-server /var/log/shiny-server /var/lib/shiny-server && \
  chown -R shiny:shiny /var/log/shiny-server /var/lib/shiny-server

# ============================================================================
# R PACKAGE DEPENDENCIES
# ============================================================================
RUN R -e "install.packages('remotes', repos='https://cloud.r-project.org/')"

# Core Shiny + Dashboard
RUN R -e "remotes::install_version('shinydashboard', version='0.7.2', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('shinycssloaders', version='1.0.0', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('shinyjs', version='2.1.0', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('shinythemes', version='1.2.0', repos='https://cloud.r-project.org/')"

# Data manipulation
RUN R -e "remotes::install_version('dplyr', version='1.1.4', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('tidyr', version='1.3.1', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('lubridate', version='1.9.4', repos='https://cloud.r-project.org/')"

# File I/O
RUN R -e "remotes::install_version('openxlsx', version='4.2.5.2', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('readxl', version='1.4.3', repos='https://cloud.r-project.org/')"

# Data display
RUN R -e "remotes::install_version('DT', version='0.31', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('reactable', version='0.4.4', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('crosstalk', version='1.2.1', repos='https://cloud.r-project.org/')"

# Visualization & mapping
RUN R -e "remotes::install_version('leaflet', version='2.2.2', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('RColorBrewer', version='1.1.3', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('viridis', version='0.6.4', repos='https://cloud.r-project.org/')"

# Database
RUN R -e "remotes::install_version('RPostgres', version='1.4.6', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('DBI', version='1.2.2', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('rpostgis', version='1.4.4', repos='https://cloud.r-project.org/')"

# Utilities
RUN R -e "remotes::install_version('digest', version='0.6.35', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('jsonlite', version='1.8.8', repos='https://cloud.r-project.org/')" && \
  R -e "install.packages('callr', repos='https://cloud.r-project.org/')"

# Dashboard utilities
RUN R -e "remotes::install_version('flexdashboard', version='0.6.2', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('reactablefmtr', version='2.0.0', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('sparkline', version='2.0', repos='https://cloud.r-project.org/')" && \
  R -e "remotes::install_version('rpostgis', version='1.6.0', repos='https://cloud.r-project.org/')"

# ============================================================================
# CREATE DIRECTORY STRUCTURE
# ============================================================================
RUN mkdir -p /srv/shiny-server/harmonization \
  /srv/shiny-server/standardization \
  /srv/shiny-server/dataviewer \
  /srv/shiny-server/www \
  /var/log/shiny-server \
  /srv/shiny-server/init-scripts/logs

# ============================================================================
# COPY APPLICATION FILES
# ============================================================================

# Copy landing page
COPY ./index.html /srv/shiny-server/

# Copy shared www assets
COPY ./www/* /srv/shiny-server/www/ 
COPY ./init-scripts/* /srv/shiny-server/init-scripts/ 

# Copy Harmonization app
COPY ./apps/harmonization/ui.R /srv/shiny-server/harmonization/
COPY ./apps/harmonization/server.R /srv/shiny-server/harmonization/
COPY ./apps/harmonization/glosis_procedures_v2.csv /srv/shiny-server/harmonization/ 
COPY ./apps/harmonization/glosis_template_v6.xlsx /srv/shiny-server/harmonization/ 

# Copy Standardization/Data Injection app
COPY ./apps/standardization/ui.R /srv/shiny-server/standardization/
COPY ./apps/standardization/server.R /srv/shiny-server/standardization/
COPY ./apps/standardization/global.R /srv/shiny-server/standardization/ 
COPY ./apps/standardization/fill_tables.R /srv/shiny-server/standardization/ 
COPY ./apps/standardization/dashboard.Rmd /srv/shiny-server/standardization/ 
COPY ./apps/standardization/glosis_procedures.csv /srv/shiny-server/standardization/ 

# Copy Dataviewer app
COPY ./apps/dataviewer/ui.R /srv/shiny-server/dataviewer/
COPY ./apps/dataviewer/server.R /srv/shiny-server/dataviewer/

# ============================================================================
# SHINY SERVER CONFIGURATION
# ============================================================================
RUN mkdir -p /etc/shiny-server && \
  printf '%s\n' \
  'run_as shiny;' \
  '' \
  'server {' \
  '  listen 3838;' \
  '' \
  '  location / {' \
  '    site_dir /srv/shiny-server;' \
  '    log_dir /var/log/shiny-server;' \
  '    directory_index on;' \
  '  }' \
  '' \
  '  location /harmonization {' \
  '    redirect "/harmonization/" 301 true;' \
  '  }' \
  '  location /harmonization/ {' \
  '    app_dir /srv/shiny-server/harmonization;' \
  '    log_dir /var/log/shiny-server;' \
  '    directory_index on;' \
  '  }' \
  '' \
  '  location /standardization {' \
  '    redirect "/standardization/" 301 true;' \
  '  }' \
  '  location /standardization/ {' \
  '    app_dir /srv/shiny-server/standardization;' \
  '    log_dir /var/log/shiny-server;' \
  '    directory_index on;' \
  '  }' \
  '' \
  '  location /dataviewer {' \
  '    redirect "/dataviewer/" 301 true;' \
  '  }' \
  '  location /dataviewer/ {' \
  '    app_dir /srv/shiny-server/dataviewer;' \
  '    log_dir /var/log/shiny-server;' \
  '    directory_index on;' \
  '  }' \
  '}' \
  > /etc/shiny-server/shiny-server.conf

# ============================================================================
# PERMISSIONS
# ============================================================================
RUN chown -R shiny:shiny /srv/shiny-server && \
  chown -R shiny:shiny /var/log/shiny-server && \
  chmod -R 755 /srv/shiny-server && \
  chmod 644 /srv/shiny-server/harmonization/glosis_procedures_v2.csv && \
  chmod 644 /srv/shiny-server/harmonization/glosis_template_v6.xlsx && \
  chmod 644 /srv/shiny-server/standardization/glosis_procedures.csv

# ============================================================================
# METADATA
# ============================================================================
RUN echo "GLOSIS ETL v1.0.0 - Landing Page + Apps" > /srv/shiny-server/VERSION.txt && \
  echo "Built: $(date)" >> /srv/shiny-server/VERSION.txt && \
  echo "R: 4.3.2" >> /srv/shiny-server/VERSION.txt && \
  echo "" >> /srv/shiny-server/VERSION.txt && \
  echo "Routes:" >> /srv/shiny-server/VERSION.txt && \
  echo "  / -> index.html (landing page)" >> /srv/shiny-server/VERSION.txt && \
  echo "  /harmonization -> Data Harmonization App" >> /srv/shiny-server/VERSION.txt && \
  echo "  /standardization -> Data Standardization App" >> /srv/shiny-server/VERSION.txt && \
  echo "  /dataviewer -> Visualization App" >> /srv/shiny-server/VERSION.txt

# ============================================================================
# HEALTHCHECK
# ============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3838/ || exit 1

# ============================================================================
# RUNTIME
# ============================================================================
EXPOSE 3838

USER shiny
CMD ["/usr/bin/shiny-server"]