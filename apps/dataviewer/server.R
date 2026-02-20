# GLOSIS DATABASE VIEWER

server <- function(input, output, session) {
  con <- reactiveVal(NULL)
  location_data <- reactiveVal(NULL)
  attributes_data <- reactiveVal(NULL)
  selection_bounds <- reactiveVal(NULL)
  connection_opened <- reactiveVal(FALSE)

  output$credits <- renderUI({
    column(
      width = 12,
      tags$br(), tags$br(),
      tags$hr(),
      tags$div(
        style = "text-align: center; margin-bottom: 8px;",
        tags$img(
          src = "../www/glosis_trees.png",
          alt = "GloSIS",
          style = "max-width: 60%; height: auto;",
          onerror = "if(!this.dataset.f1){this.dataset.f1=1;this.src='/www/glosis_trees.png';}else if(!this.dataset.f2){this.dataset.f2=1;this.src='/apps/www/glosis_trees.png';}else if(!this.dataset.f3){this.dataset.f3=1;this.src='glosis_maize.png';}"
        )
      ),
      tags$div(
        style = "text-align: center; color: #d2d6de; font-size: 12px;",
        "Global Soil Information System",
        tags$br(),
        "(GLOSIS)"
      ),
      tags$h6(
        style = "text-align: center; color: #d2d6de; margin-top: 10px;",
        "Database Viewer"
      ),
      tags$hr(),
      tags$div(
        style = "text-align: center; color: #d2d6de; font-size: 14px;",
        "Developed within",
        tags$br(),
        tags$b(" INSII - Global Soil Partnership"),
        tags$br(),
        "FAO"
      ),
      tags$div(
        style = "text-align: center;",
        tags$a(
          "www.fao.org/global-soil-partnership",
          href = "https://www.fao.org/global-soil-partnership",
          target = "_blank",
          style = "color: #9ec8ff; font-size: 12px;"
        )
      ),
      tags$hr()
    )
  })

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

    output$db_dropdown <- renderUI({
      selectInput(
        "db_name_input",
        "SELECT A DATABASE",
        choices = sort(na.omit(dbs[dbs$datname != "postgres", "datname"])),
        selected = dbs$datname[1]
      )
    })
  }

  renderDatabaseDropdown()

  observeEvent(input$connect_button, {
    if (is.null(con())) {
      db <- tryCatch({
        dbConnect(
          RPostgres::Postgres(),
          dbname = isolate(input$db_name_input),
          host = host_name,
          port = port_number,
          user = user_name,
          password = password_name
        )
      }, error = function(e) {
        shiny::showNotification(paste("Failed to connect:", e$message), type = "error")
        return(NULL)
      })

      if (!is.null(db)) {
        con(db)
        connection_opened(TRUE)
        selection_bounds(NULL)
        shiny::showNotification("Connected to database.", type = "message")
        updateActionButton(session, "connect_button", label = "Disconnect", icon = icon("ban"))
      }
    } else {
      dbDisconnect(con())
      con(NULL)
      connection_opened(FALSE)
      location_data(NULL)
      attributes_data(NULL)
      selection_bounds(NULL)
      shiny::showNotification("Disconnected from database.", type = "message")
      updateActionButton(session, "connect_button", label = "Connect to Database", icon = icon("plug"))
    }
  })

  observe({
    if (!connection_opened()) {
      location_data(NULL)
      attributes_data(NULL)
      return()
    }

    req(con())

    tryCatch({
      showModal(modalDialog(
        title = "Loading Data",
        div(
          style = "text-align: center; padding: 20px;",
          icon("spinner", class = "fa-spin fa-3x", style = "color: #3c8dbc;"),
          tags$h4("Fetching Data...", style = "margin-top: 15px; font-weight: bold;"),
          tags$p("Please wait, this may take a moment.")
        ),
        footer = NULL,
        easyClose = FALSE,
        fade = TRUE
      ))

      query1 <- "
      SELECT
        pr.name AS project_name,
        s.site_code,
        opc.property_phys_chem_id,
        e.element_id,
        e.profile_id,
        e.order_element,
        e.upper_depth,
        e.lower_depth,
        e.type,
        spc.code,
        ST_X(pl.position::geometry) AS longitude,
        ST_Y(pl.position::geometry) AS latitude
      FROM core.result_phys_chem rpc
      JOIN core.element e ON rpc.specimen_id = e.element_id
      JOIN core.profile p ON e.profile_id = p.profile_id
      JOIN core.plot pl ON p.plot_id = pl.plot_id
      JOIN core.site s ON pl.site_id = s.site_id
      JOIN core.project_site sp ON s.site_id = sp.site_id
      JOIN core.project pr ON sp.project_id = pr.project_id
      JOIN core.observation_phys_chem opc ON rpc.observation_phys_chem_id = opc.observation_phys_chem_id
      JOIN core.specimen spc ON rpc.specimen_id = spc.specimen_id;
      "

      query2 <- "
      SELECT
        pr.name AS project_name,
        s.site_code,
        rpc.result_phys_chem_id,
        rpc.value,
        opc.property_phys_chem_id,
        sp.code,
        e.profile_id,
        ST_X(pl.position::geometry) AS longitude,
        ST_Y(pl.position::geometry) AS latitude
      FROM core.result_phys_chem rpc
      JOIN core.specimen sp ON rpc.specimen_id = sp.specimen_id
      JOIN core.element e ON sp.element_id = e.element_id
      JOIN core.profile p ON e.profile_id = p.profile_id
      JOIN core.plot pl ON p.plot_id = pl.plot_id
      JOIN core.site s ON pl.site_id = s.site_id
      JOIN core.project_site sp2 ON s.site_id = sp2.site_id
      JOIN core.project pr ON sp2.project_id = pr.project_id
      JOIN core.observation_phys_chem opc ON rpc.observation_phys_chem_id = opc.observation_phys_chem_id;
      "

      sch <- dbGetQuery(con(), query1)

      location_tbl <- sch %>%
        select(project_name, site_code, code, profile_id, order_element, upper_depth, lower_depth, type, longitude, latitude) %>%
        distinct()

      site_tibble <- dbGetQuery(con(), query2)
      property_wide <- site_tibble %>%
        select(-result_phys_chem_id) %>%
        group_by(project_name, site_code, code, property_phys_chem_id) %>%
        summarise(value = mean(value, na.rm = TRUE), .groups = "drop") %>%
        pivot_wider(
          names_from = property_phys_chem_id,
          values_from = value,
          names_glue = "{property_phys_chem_id}"
        )

      attributes_tbl <- left_join(
        location_tbl,
        property_wide,
        by = c("project_name", "site_code", "code")
      ) %>%
        mutate_if(is.numeric, ~round(., 3)) %>%
        distinct()

      location_data(location_tbl)
      attributes_data(attributes_tbl)
      removeModal()
    }, error = function(e) {
      removeModal()
      shiny::showNotification(paste("Error fetching data:", e$message), type = "error")
    })
  })

  observeEvent(input$map_selected_bounds, {
    b <- input$map_selected_bounds
    req(!is.null(b$west), !is.null(b$east), !is.null(b$south), !is.null(b$north))
    selection_bounds(list(
      west = as.numeric(b$west),
      east = as.numeric(b$east),
      south = as.numeric(b$south),
      north = as.numeric(b$north)
    ))
  })

  observeEvent(input$map_clear_selection, {
    selection_bounds(NULL)
  })

  filtered_location_data <- reactive({
    req(location_data())
    df <- location_data()
    b <- selection_bounds()
    if (is.null(b)) {
      return(df)
    }

    df %>%
      filter(
        !is.na(longitude), !is.na(latitude),
        longitude >= b$west, longitude <= b$east,
        latitude >= b$south, latitude <= b$north
      )
  })

  filtered_attributes_data <- reactive({
    req(attributes_data(), filtered_location_data())
    attributes_data() %>%
      filter(code %in% filtered_location_data()$code)
  })

  shared_location <- reactive({
    req(filtered_location_data())
    SharedData$new(filtered_location_data(), key = ~code, group = "glosis_shared")
  })

  shared_attributes <- reactive({
    req(filtered_attributes_data())
    SharedData$new(filtered_attributes_data(), key = ~code, group = "glosis_shared")
  })

  output$hist_select_vars <- renderUI({
    req(filtered_attributes_data())

    df <- filtered_attributes_data()
    numeric_cols <- names(select_if(df, is.numeric))
    exclude <- c("longitude", "latitude", "upper_depth", "lower_depth", "profile_id", "order_element")
    choices <- setdiff(numeric_cols, exclude)

    if (length(choices) == 0) {
      return(tags$p("No numeric properties found to plot."))
    }

    default_choices <- head(choices, 4)
    selectizeInput(
      "hist_vars",
      "Properties:",
      choices = choices,
      selected = default_choices,
      multiple = TRUE,
      options = list(placeholder = "Choose one or more properties")
    )
  })

  output$histogram_table <- renderReactable({
    req(shared_attributes(), filtered_attributes_data())

    props <- input$hist_vars
    available <- names(filtered_attributes_data())
    props <- props[props %in% available]

    if (length(props) == 0) {
      return(NULL)
    }

    columns <- list(
      project_name = colDef(show = TRUE, name = "Project"),
      site_code = colDef(show = TRUE, name = "Site"),
      code = colDef(show = TRUE, name = "Code"),
      upper_depth = colDef(show = TRUE, name = "Upper Depth"),
      lower_depth = colDef(show = TRUE, name = "Lower Depth")
    )

    for (prop in props) {
      columns[[prop]] <- colDef(
        show = TRUE,
        name = prop,
        minWidth = 150,
        cell = data_bars(
          filtered_attributes_data(),
          fill_color = "#E42D3A",
          text_position = "inside-base",
          background = "#F5F5F5",
          round_edges = FALSE,
          box_shadow = FALSE
        )
      )
    }

    reactable(
      shared_attributes(),
      defaultColDef = colDef(
        show = FALSE,
        style = list(
          transition = "background-size 220ms ease, background-color 220ms ease, color 180ms ease"
        )
      ),
      columns = columns,
      selection = "multiple",
      onClick = "select",
      highlight = TRUE,
      striped = TRUE,
      bordered = TRUE,
      compact = TRUE,
      pagination = TRUE,
      defaultPageSize = 25,
      theme = reactableTheme(
        rowSelectedStyle = list(backgroundColor = "#DCEAF7"),
        searchInputStyle = list(width = "100%")
      )
    )
  })

  output$map <- renderLeaflet({
    req(location_data())

    pal <- colorFactor(
      palette = c("#1f78b4", "#33a02c", "#e31a1c", "#ff7f00", "#6a3d9a", "#a6cee3", "#b2df8a", "#fb9a99"),
      domain = location_data()$project_name
    )

    leaflet(location_data(), options = leafletOptions(attributionControl = FALSE)) %>%
      addProviderTiles("Esri.WorldImagery", group = "Esri.WorldImagery") %>%
      addProviderTiles("OpenStreetMap", group = "OpenStreetMap") %>%
      addCircleMarkers(
        lng = ~longitude,
        lat = ~latitude,
        radius = 5,
        weight = 1,
        fillColor = ~pal(project_name),
        stroke = TRUE,
        fillOpacity = 0.8,
        popup = ~paste0("<b>Project:</b> ", project_name, "<br><b>Site:</b> ", site_code, "<br><b>Code:</b> ", code),
        label = ~as.character(code)
      ) %>%
      addLegend(
        "bottomright",
        pal = pal,
        values = ~project_name,
        title = "Project"
      ) %>%
      addLayersControl(
        baseGroups = c("Esri.WorldImagery", "OpenStreetMap"),
        position = "bottomleft"
      ) %>%
      htmlwidgets::onRender(
        "function(el, x) {
          var map = this;
          var mapId = el.id;
          var active = false;
          var selecting = false;
          var startLatLng = null;
          var selectionRect = null;

          function ensureDragEnabled() {
            if (map.dragging && !map.dragging.enabled()) map.dragging.enable();
          }

          var SelectControl = L.Control.extend({
            options: { position: 'topleft' },
            onAdd: function() {
              var container = L.DomUtil.create('div', 'leaflet-bar');

              var selectBtn = L.DomUtil.create('a', '', container);
              selectBtn.href = '#';
              selectBtn.innerHTML = '&#9633;';
              selectBtn.title = 'Toggle area selection';
              selectBtn.style.width = '30px';
              selectBtn.style.height = '30px';
              selectBtn.style.lineHeight = '30px';
              selectBtn.style.textAlign = 'center';
              selectBtn.style.fontSize = '16px';
              selectBtn.style.cursor = 'pointer';

              var clearBtn = L.DomUtil.create('a', '', container);
              clearBtn.href = '#';
              clearBtn.innerHTML = '&times;';
              clearBtn.title = 'Clear selected area';
              clearBtn.style.width = '30px';
              clearBtn.style.height = '30px';
              clearBtn.style.lineHeight = '30px';
              clearBtn.style.textAlign = 'center';
              clearBtn.style.fontSize = '18px';
              clearBtn.style.cursor = 'pointer';

              L.DomEvent.disableClickPropagation(container);

              L.DomEvent.on(selectBtn, 'click', function(e) {
                L.DomEvent.stop(e);
                active = !active;
                if (active) {
                  L.DomUtil.addClass(selectBtn, 'active');
                } else {
                  L.DomUtil.removeClass(selectBtn, 'active');
                  selecting = false;
                  startLatLng = null;
                  ensureDragEnabled();
                }
              });

              L.DomEvent.on(clearBtn, 'click', function(e) {
                L.DomEvent.stop(e);
                if (selectionRect) {
                  map.removeLayer(selectionRect);
                  selectionRect = null;
                }
                Shiny.setInputValue(mapId + '_clear_selection', { nonce: Date.now() }, { priority: 'event' });
              });

              return container;
            }
          });

          map.addControl(new SelectControl());

          map.on('mousedown', function(e) {
            if (!active) return;
            selecting = true;
            startLatLng = e.latlng;
            if (selectionRect) {
              map.removeLayer(selectionRect);
            }
            selectionRect = L.rectangle([startLatLng, startLatLng], {
              color: '#E42D3A',
              weight: 2,
              fillColor: '#E42D3A',
              fillOpacity: 0.08
            }).addTo(map);
            if (map.dragging) map.dragging.disable();
          });

          map.on('mousemove', function(e) {
            if (!active || !selecting || !startLatLng || !selectionRect) return;
            var bounds = L.latLngBounds(startLatLng, e.latlng);
            selectionRect.setBounds(bounds);
          });

          map.on('mouseup', function(e) {
            if (!active || !selecting || !startLatLng) return;
            selecting = false;
            var bounds = L.latLngBounds(startLatLng, e.latlng);
            if (selectionRect) selectionRect.setBounds(bounds);
            Shiny.setInputValue(mapId + '_selected_bounds', {
              west: bounds.getWest(),
              east: bounds.getEast(),
              south: bounds.getSouth(),
              north: bounds.getNorth(),
              nonce: Date.now()
            }, { priority: 'event' });
            ensureDragEnabled();
          });
        }"
      )
  })

  output$data_table <- renderDT({
    req(shared_location())

    datatable(
      shared_location(),
      extensions = c("FixedHeader", "Buttons", "Scroller", "Select"),
      filter = "top",
      selection = "none",
      class = "cell-border stripe",
      editable = "cell",
      rownames = FALSE,
      options = list(
        dom = "Bfrtip",
        buttons = c("selectAll", "selectNone", "copy", "csv", "excel", "pdf", "print"),
        select = list(style = "multi", items = "row"),
        paging = TRUE,
        pageLength = 40,
        scrollX = TRUE,
        scrollY = "550px",
        fixedHeader = TRUE,
        scrollCollapse = TRUE,
        keys = TRUE
      )
    )
  }, server = FALSE)

  session$onSessionEnded(function() {
    if (!is.null(con())) {
      dbDisconnect(con())
    }
  })
}
