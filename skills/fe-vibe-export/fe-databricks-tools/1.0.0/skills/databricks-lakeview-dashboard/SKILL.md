---
name: databricks-lakeview-dashboard
description: Programmatically create and manage Lakeview dashboards in Databricks
---

# Databricks Lakeview Dashboard Skill

This skill enables programmatic creation of beautiful Lakeview dashboards in Databricks using the Dashboard API.

## Overview

Lakeview dashboards are stored as JSON documents with a `serialized_dashboard` payload. This skill provides the schema and helper utilities to create dashboards programmatically.

## Prerequisites

1. Databricks CLI authenticated: `databricks auth login --profile <profile>`
2. SQL warehouse available for dashboard queries
3. Unity Catalog tables/views for data sources

## API Endpoints

### Create Dashboard
```bash
databricks api post /api/2.0/lakeview/dashboards --profile <profile> --json '{
  "display_name": "My Dashboard",
  "warehouse_id": "<warehouse_id>",
  "parent_path": "/Users/<email>",
  "serialized_dashboard": "<json_string>"
}'
```

### Update Dashboard
```bash
databricks api patch /api/2.0/lakeview/dashboards/<dashboard_id> --profile <profile> --json '{
  "display_name": "Updated Name",
  "serialized_dashboard": "<json_string>"
}'
```

### Get Dashboard
```bash
databricks api get /api/2.0/lakeview/dashboards/<dashboard_id> --profile <profile>
```

### List Dashboards
```bash
databricks api get /api/2.0/lakeview/dashboards --profile <profile>
```

### Publish Dashboard
```bash
databricks api post /api/2.0/lakeview/dashboards/<dashboard_id>/published --profile <profile>
```

## Serialized Dashboard Schema

The `serialized_dashboard` is a JSON string with this structure:

```json
{
  "datasets": [...],
  "pages": [...],
  "uiSettings": {...}
}
```

### Datasets

Datasets define the SQL queries that power visualizations:

```json
{
  "datasets": [
    {
      "name": "unique_id_123",
      "displayName": "Sales Data",
      "queryLines": [
        "SELECT * FROM catalog.schema.table"
      ]
    }
  ]
}
```

### Pages

Pages contain the layout of widgets:

```json
{
  "pages": [
    {
      "name": "page_id_123",
      "displayName": "Overview",
      "pageType": "PAGE_TYPE_CANVAS",
      "layout": [...]
    }
  ]
}
```

### Layout and Positioning

Widgets are positioned on a 6-column grid:

```json
{
  "layout": [
    {
      "widget": {...},
      "position": {
        "x": 0,       // Column (0-5)
        "y": 0,       // Row
        "width": 2,   // Columns to span (1-6)
        "height": 3   // Rows to span
      }
    }
  ]
}
```

## Widget Types

### Bar Chart
```json
{
  "widget": {
    "name": "widget_id",
    "queries": [{
      "name": "main_query",
      "query": {
        "datasetName": "dataset_id",
        "fields": [
          {"name": "category", "expression": "`category`"},
          {"name": "sum_amount", "expression": "SUM(`amount`)"}
        ],
        "disaggregated": false
      }
    }],
    "spec": {
      "version": 3,
      "widgetType": "bar",
      "encodings": {
        "x": {
          "fieldName": "category",
          "scale": {"type": "categorical"},
          "displayName": "Category"
        },
        "y": {
          "fieldName": "sum_amount",
          "scale": {"type": "quantitative"},
          "displayName": "Total Amount"
        },
        "label": {"show": true}
      },
      "frame": {
        "showTitle": true,
        "title": "Sales by Category"
      },
      "mark": {
        "colors": ["#FFAB00", "#00A972", "#FF3621"]
      }
    }
  }
}
```

### Line Chart
```json
{
  "widget": {
    "name": "widget_id",
    "queries": [{
      "name": "main_query",
      "query": {
        "datasetName": "dataset_id",
        "fields": [
          {"name": "date", "expression": "DATE_TRUNC(\"MONTH\", `sale_date`)"},
          {"name": "series", "expression": "`category`"},
          {"name": "value", "expression": "SUM(`amount`)"}
        ],
        "disaggregated": false
      }
    }],
    "spec": {
      "version": 3,
      "widgetType": "line",
      "encodings": {
        "x": {
          "fieldName": "date",
          "scale": {"type": "temporal"},
          "displayName": "Date"
        },
        "y": {
          "fieldName": "value",
          "scale": {"type": "quantitative"},
          "displayName": "Amount"
        },
        "color": {
          "fieldName": "series",
          "scale": {"type": "categorical"},
          "displayName": "Category"
        }
      }
    }
  }
}
```

### Pie Chart
```json
{
  "widget": {
    "name": "widget_id",
    "queries": [{
      "name": "main_query",
      "query": {
        "datasetName": "dataset_id",
        "fields": [
          {"name": "count", "expression": "COUNT(`*`)"},
          {"name": "category", "expression": "`category`"}
        ],
        "disaggregated": false
      }
    }],
    "spec": {
      "version": 3,
      "widgetType": "pie",
      "encodings": {
        "angle": {
          "fieldName": "count",
          "scale": {"type": "quantitative"},
          "displayName": "Count"
        },
        "color": {
          "fieldName": "category",
          "scale": {"type": "categorical"},
          "displayName": "Category"
        }
      },
      "frame": {
        "showTitle": true,
        "title": "Distribution by Category"
      }
    }
  }
}
```

### Counter (KPI)
```json
{
  "widget": {
    "name": "widget_id",
    "queries": [{
      "name": "main_query",
      "query": {
        "datasetName": "dataset_id",
        "fields": [
          {"name": "total", "expression": "SUM(`amount`)"}
        ],
        "disaggregated": true
      }
    }],
    "spec": {
      "version": 2,
      "widgetType": "counter",
      "encodings": {
        "value": {
          "fieldName": "total",
          "displayName": "Total Revenue"
        }
      },
      "frame": {
        "showTitle": true,
        "title": "Total Revenue"
      }
    }
  }
}
```

### Scatter Plot
```json
{
  "widget": {
    "name": "widget_id",
    "queries": [{
      "name": "main_query",
      "query": {
        "datasetName": "dataset_id",
        "fields": [
          {"name": "x_val", "expression": "`price`"},
          {"name": "y_val", "expression": "`quantity`"},
          {"name": "group", "expression": "`category`"}
        ],
        "disaggregated": true
      }
    }],
    "spec": {
      "version": 3,
      "widgetType": "scatter",
      "encodings": {
        "x": {
          "fieldName": "x_val",
          "scale": {"type": "quantitative"},
          "displayName": "Price"
        },
        "y": {
          "fieldName": "y_val",
          "scale": {"type": "quantitative"},
          "displayName": "Quantity"
        },
        "color": {
          "fieldName": "group",
          "scale": {"type": "categorical"},
          "displayName": "Category"
        }
      }
    }
  }
}
```

### Area Chart
```json
{
  "spec": {
    "version": 3,
    "widgetType": "area",
    "encodings": {
      "x": {"fieldName": "date", "scale": {"type": "temporal"}},
      "y": {"fieldName": "value", "scale": {"type": "quantitative"}},
      "color": {"fieldName": "series", "scale": {"type": "categorical"}}
    }
  }
}
```

### Histogram
```json
{
  "spec": {
    "version": 3,
    "widgetType": "histogram",
    "encodings": {
      "x": {
        "fieldName": "bin_field",
        "scale": {"type": "categorical", "sort": {"by": "natural-order"}}
      },
      "y": {
        "fieldName": "count",
        "scale": {"type": "quantitative"}
      },
      "color": {
        "fieldName": "category",
        "scale": {
          "type": "categorical",
          "mappings": [
            {"value": "good", "color": "#00A972"},
            {"value": "bad", "color": "#FF3621"}
          ]
        }
      }
    }
  }
}
```

### Table
```json
{
  "widget": {
    "name": "widget_id",
    "queries": [{
      "name": "main_query",
      "query": {
        "datasetName": "dataset_id",
        "fields": [
          {"name": "col1", "expression": "`column1`"},
          {"name": "col2", "expression": "`column2`"}
        ],
        "disaggregated": true
      }
    }],
    "spec": {
      "version": 1,
      "widgetType": "table",
      "encodings": {
        "columns": [
          {
            "fieldName": "col1",
            "type": "string",
            "displayAs": "string",
            "title": "Column 1",
            "displayName": "Column 1"
          },
          {
            "fieldName": "col2",
            "type": "float",
            "displayAs": "number",
            "numberFormat": "0.00",
            "title": "Column 2",
            "alignContent": "right"
          }
        ]
      }
    }
  }
}
```

## Filter Widgets

### Date Range Picker
```json
{
  "spec": {
    "version": 2,
    "widgetType": "filter-date-range-picker",
    "encodings": {
      "fields": [{
        "fieldName": "date_field",
        "displayName": "Date",
        "queryName": "filter_query_name"
      }]
    },
    "frame": {"showTitle": true, "title": "Select Date Range"}
  }
}
```

### Single Select Dropdown
```json
{
  "spec": {
    "version": 2,
    "widgetType": "filter-single-select",
    "encodings": {
      "fields": [{
        "fieldName": "category",
        "displayName": "Category",
        "queryName": "filter_query_name"
      }]
    },
    "frame": {"showTitle": true, "title": "Select Category"}
  }
}
```

### Multi-Select
```json
{
  "spec": {
    "version": 2,
    "widgetType": "filter-multi-select",
    "encodings": {
      "fields": [{
        "fieldName": "region",
        "displayName": "Region",
        "queryName": "filter_query_name"
      }]
    }
  }
}
```

### Text Entry Filter
```json
{
  "spec": {
    "version": 2,
    "widgetType": "filter-text-entry",
    "encodings": {
      "fields": [{
        "fieldName": "search_field",
        "displayName": "Search",
        "queryName": "filter_query_name"
      }]
    }
  }
}
```

## Scale Types

- `categorical` - For discrete categories
- `quantitative` - For numeric values
- `temporal` - For date/time values

## Color Palettes

Default Databricks colors:
```json
["#FFAB00", "#00A972", "#FF3621", "#8BCAE7", "#AB4057", "#99DDB4", "#FCA4A1", "#919191", "#BF7080"]
```

Custom color mappings:
```json
{
  "scale": {
    "type": "categorical",
    "mappings": [
      {"value": "Success", "color": "#00A972"},
      {"value": "Warning", "color": "#FFAB00"},
      {"value": "Error", "color": "#FF3621"}
    ]
  }
}
```

## UI Settings

```json
{
  "uiSettings": {
    "theme": {
      "widgetHeaderAlignment": "ALIGNMENT_UNSPECIFIED"
    },
    "applyModeEnabled": false
  }
}
```

## Complete Example

See `resources/example_dashboard.json` for a complete working example.

## Python Helper

Use `resources/lakeview_builder.py` for a Python class that simplifies dashboard creation:

```python
from lakeview_builder import LakeviewDashboard

dashboard = LakeviewDashboard("My Sales Dashboard")

# Add dataset
dashboard.add_dataset(
    "sales",
    "Sales Data",
    "SELECT * FROM catalog.schema.sales"
)

# Add bar chart
dashboard.add_bar_chart(
    dataset_name="sales",
    x_field="category",
    y_field="amount",
    y_agg="SUM",
    title="Sales by Category",
    position={"x": 0, "y": 0, "width": 3, "height": 4}
)

# Add counter
dashboard.add_counter(
    dataset_name="sales",
    value_field="amount",
    value_agg="SUM",
    title="Total Sales",
    position={"x": 3, "y": 0, "width": 1, "height": 2}
)

# Get JSON for API
json_payload = dashboard.to_json()
```

## Tips

1. **Widget IDs**: Generate unique 8-character hex IDs for widget and dataset names
2. **Grid Layout**: Dashboard uses a 6-column grid. Plan layout before building.
3. **Dataset Reuse**: Multiple widgets can share the same dataset
4. **Filter Queries**: Filters need special query names for associativity
5. **Disaggregated**: Set to `true` for raw data (tables), `false` for aggregations

## Troubleshooting

- **Dashboard not rendering**: Check serialized_dashboard is valid JSON string (escaped)
- **Widget empty**: Verify dataset name matches exactly
- **Filters not working**: Ensure filter query names follow the pattern
