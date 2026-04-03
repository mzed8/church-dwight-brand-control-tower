#!/usr/bin/env python3
"""
Create and deploy the CHD Brand Health Monitor dashboard (Act 1)
to Databricks Lakeview using the LakeviewDashboard builder.
"""

import json
import subprocess
import uuid
from typing import Optional, List, Dict, Any


# -- LakeviewDashboard builder (inlined) --------------------------------------

class LakeviewDashboard:
    """Builder class for creating Lakeview dashboard JSON payloads."""

    DEFAULT_COLORS = [
        "#FFAB00", "#00A972", "#FF3621", "#8BCAE7",
        "#AB4057", "#99DDB4", "#FCA4A1", "#919191", "#BF7080"
    ]

    def __init__(self, name: str = "New Dashboard"):
        self.name = name
        self.datasets: List[Dict] = []
        self.pages: List[Dict] = []
        self._current_page: Optional[Dict] = None
        self.add_page("Overview")

    @staticmethod
    def _generate_id() -> str:
        return uuid.uuid4().hex[:8]

    def add_dataset(self, name: str, display_name: str, query: str) -> str:
        dataset = {
            "name": name,
            "displayName": display_name,
            "queryLines": [query]
        }
        self.datasets.append(dataset)
        return name

    def add_page(self, display_name: str) -> str:
        page_id = self._generate_id()
        page = {
            "name": page_id,
            "displayName": display_name,
            "pageType": "PAGE_TYPE_CANVAS",
            "layout": []
        }
        self.pages.append(page)
        self._current_page = page
        return page_id

    def _add_widget(self, widget: Dict, position: Dict[str, int]) -> None:
        if self._current_page is None:
            raise ValueError("No page exists. Call add_page() first.")
        layout_item = {
            "widget": widget,
            "position": {
                "x": position.get("x", 0),
                "y": position.get("y", 0),
                "width": position.get("width", 2),
                "height": position.get("height", 3)
            }
        }
        self._current_page["layout"].append(layout_item)

    def _create_field(self, name: str, expression: str) -> Dict:
        return {"name": name, "expression": expression}

    def add_bar_chart(
        self, dataset_name: str, x_field: str, y_field: str,
        y_agg: str = "SUM", title: Optional[str] = None,
        position: Optional[Dict[str, int]] = None,
        colors: Optional[List[str]] = None, show_labels: bool = True,
        color_field: Optional[str] = None, sort_descending: bool = False
    ) -> str:
        widget_id = self._generate_id()
        y_name = f"{y_agg.lower()}({y_field})"
        fields = [
            self._create_field(x_field, f"`{x_field}`"),
            self._create_field(y_name, f"{y_agg}(`{y_field}`)")
        ]
        if color_field:
            fields.append(self._create_field(color_field, f"`{color_field}`"))
        x_scale = {"type": "categorical"}
        if sort_descending:
            x_scale["sort"] = {"by": "y-reversed"}
        encodings = {
            "x": {"fieldName": x_field, "scale": x_scale, "displayName": x_field},
            "y": {"fieldName": y_name, "scale": {"type": "quantitative"}, "displayName": f"{y_agg} of {y_field}"},
            "label": {"show": show_labels}
        }
        if color_field:
            encodings["color"] = {"fieldName": color_field, "scale": {"type": "categorical"}, "displayName": color_field}
        widget = {
            "name": widget_id,
            "queries": [{"name": "main_query", "query": {"datasetName": dataset_name, "fields": fields, "disaggregated": False}}],
            "spec": {
                "version": 3, "widgetType": "bar", "encodings": encodings,
                "frame": {"showTitle": title is not None, "title": title or ""},
                "mark": {"colors": colors or self.DEFAULT_COLORS}
            }
        }
        self._add_widget(widget, position or {"x": 0, "y": 0, "width": 3, "height": 4})
        return widget_id

    def add_line_chart(
        self, dataset_name: str, x_field: str, y_field: str,
        y_agg: str = "SUM", time_grain: Optional[str] = None,
        title: Optional[str] = None, position: Optional[Dict[str, int]] = None,
        color_field: Optional[str] = None
    ) -> str:
        widget_id = self._generate_id()
        if time_grain:
            x_name = f"{time_grain.lower()}({x_field})"
            x_expr = f'DATE_TRUNC("{time_grain}", `{x_field}`)'
            x_scale_type = "temporal"
        else:
            x_name = x_field
            x_expr = f"`{x_field}`"
            x_scale_type = "categorical"
        y_name = f"{y_agg.lower()}({y_field})"
        fields = [
            self._create_field(x_name, x_expr),
            self._create_field(y_name, f"{y_agg}(`{y_field}`)")
        ]
        if color_field:
            fields.append(self._create_field(color_field, f"`{color_field}`"))
        encodings = {
            "x": {"fieldName": x_name, "scale": {"type": x_scale_type}, "displayName": x_field},
            "y": {"fieldName": y_name, "scale": {"type": "quantitative"}, "displayName": f"{y_agg} of {y_field}"}
        }
        if color_field:
            encodings["color"] = {"fieldName": color_field, "scale": {"type": "categorical"}, "displayName": color_field}
        widget = {
            "name": widget_id,
            "queries": [{"name": "main_query", "query": {"datasetName": dataset_name, "fields": fields, "disaggregated": False}}],
            "spec": {
                "version": 3, "widgetType": "line", "encodings": encodings,
                "frame": {"showTitle": title is not None, "title": title or ""}
            }
        }
        self._add_widget(widget, position or {"x": 0, "y": 0, "width": 3, "height": 4})
        return widget_id

    def add_counter(
        self, dataset_name: str, value_field: str, value_agg: str = "SUM",
        title: Optional[str] = None, position: Optional[Dict[str, int]] = None
    ) -> str:
        widget_id = self._generate_id()
        if value_agg == "COUNT":
            value_name = "count(*)"
            value_expr = "COUNT(`*`)"
        else:
            value_name = f"{value_agg.lower()}({value_field})"
            value_expr = f"{value_agg}(`{value_field}`)"
        widget = {
            "name": widget_id,
            "queries": [{"name": "main_query", "query": {"datasetName": dataset_name, "fields": [self._create_field(value_name, value_expr)], "disaggregated": True}}],
            "spec": {
                "version": 2, "widgetType": "counter",
                "encodings": {"value": {"fieldName": value_name, "displayName": title or value_name}},
                "frame": {"showTitle": title is not None, "title": title or ""}
            }
        }
        self._add_widget(widget, position or {"x": 0, "y": 0, "width": 1, "height": 2})
        return widget_id

    def add_table(
        self, dataset_name: str, columns: List[Dict[str, Any]],
        title: Optional[str] = None, position: Optional[Dict[str, int]] = None
    ) -> str:
        widget_id = self._generate_id()
        fields = []
        column_encodings = []
        for i, col in enumerate(columns):
            field_name = col["field"]
            fields.append(self._create_field(field_name, f"`{field_name}`"))
            col_type = col.get("type", "string")
            display_as = "string"
            align = "left"
            if col_type in ("integer", "float"):
                display_as = "number"
                align = "right"
            elif col_type == "datetime":
                display_as = "datetime"
                align = "right"
            encoding = {
                "fieldName": field_name, "type": col_type, "displayAs": display_as,
                "title": col.get("title", field_name), "displayName": col.get("title", field_name),
                "order": 100000 + i, "alignContent": align
            }
            if "format" in col and col_type in ("integer", "float"):
                encoding["numberFormat"] = col["format"]
            column_encodings.append(encoding)
        widget = {
            "name": widget_id,
            "queries": [{"name": "main_query", "query": {"datasetName": dataset_name, "fields": fields, "disaggregated": True}}],
            "spec": {
                "version": 1, "widgetType": "table",
                "encodings": {"columns": column_encodings},
                "frame": {"showTitle": title is not None, "title": title or ""}
            }
        }
        self._add_widget(widget, position or {"x": 0, "y": 0, "width": 6, "height": 5})
        return widget_id

    def add_filter_dropdown(
        self, dataset_name: str, field: str, title: Optional[str] = None,
        position: Optional[Dict[str, int]] = None, multi_select: bool = False
    ) -> str:
        widget_id = self._generate_id()
        query_name = f"filter_{widget_id}_{field}"
        widget_type = "filter-multi-select" if multi_select else "filter-single-select"
        widget = {
            "name": widget_id,
            "queries": [{"name": query_name, "query": {
                "datasetName": dataset_name,
                "fields": [
                    self._create_field(field, f"`{field}`"),
                    self._create_field(f"{field}_associativity", 'COUNT_IF(`associative_filter_predicate_group`)')
                ],
                "disaggregated": False
            }}],
            "spec": {
                "version": 2, "widgetType": widget_type,
                "encodings": {"fields": [{"fieldName": field, "displayName": field, "queryName": query_name}]},
                "frame": {"showTitle": title is not None, "title": title or f"Filter by {field}"}
            }
        }
        self._add_widget(widget, position or {"x": 0, "y": 0, "width": 1, "height": 2})
        return widget_id

    def add_date_filter(
        self, dataset_name: str, field: str, title: Optional[str] = None,
        position: Optional[Dict[str, int]] = None
    ) -> str:
        widget_id = self._generate_id()
        query_name = f"filter_{widget_id}_{field}"
        widget = {
            "name": widget_id,
            "queries": [{"name": query_name, "query": {
                "datasetName": dataset_name,
                "fields": [
                    self._create_field(field, f"`{field}`"),
                    self._create_field(f"{field}_associativity", 'COUNT_IF(`associative_filter_predicate_group`)')
                ],
                "disaggregated": False
            }}],
            "spec": {
                "version": 2, "widgetType": "filter-date-range-picker",
                "encodings": {"fields": [{"fieldName": field, "displayName": field, "queryName": query_name}]},
                "frame": {"showTitle": title is not None, "title": title or f"Select {field}"}
            }
        }
        self._add_widget(widget, position or {"x": 0, "y": 0, "width": 1, "height": 2})
        return widget_id

    def to_dict(self) -> Dict:
        return {
            "datasets": self.datasets,
            "pages": self.pages,
            "uiSettings": {
                "theme": {"widgetHeaderAlignment": "ALIGNMENT_UNSPECIFIED"},
                "applyModeEnabled": False
            }
        }

    def to_json(self, indent: int = 2) -> str:
        return json.dumps(self.to_dict(), indent=indent)

    def get_api_payload(self, warehouse_id: str, parent_path: str) -> Dict:
        return {
            "display_name": self.name,
            "warehouse_id": warehouse_id,
            "parent_path": parent_path,
            "serialized_dashboard": self.to_json()
        }


# -- Build the CHD Brand Health Monitor dashboard ----------------------------

CATALOG_SCHEMA = "serverless_stable_ocafq5_catalog.chd_demo"
WAREHOUSE_ID = "46430b387bfd91fd"
PARENT_PATH = "/Users/user"
PROFILE = "fevm-serverless-stable-ocafq5"
BASE_URL = "https://fevm-serverless-stable-ocafq5.cloud.databricks.com"

dashboard = LakeviewDashboard("CHD Brand Health Monitor")

# -- Datasets -----------------------------------------------------------------

dashboard.add_dataset(
    "brand_health", "Brand Health Daily",
    f"SELECT * FROM {CATALOG_SCHEMA}.brand_health_daily"
)
dashboard.add_dataset(
    "channel_sentiment", "Channel Sentiment Daily",
    f"SELECT * FROM {CATALOG_SCHEMA}.channel_sentiment_daily"
)
dashboard.add_dataset(
    "social_engagement", "Social Engagement Daily",
    f"SELECT * FROM {CATALOG_SCHEMA}.social_engagement_daily"
)
dashboard.add_dataset(
    "recent_negative_reviews", "Recent Negative Reviews",
    f"SELECT review_date, brand_name, product_name, retailer_name, rating, review_title, review_text "
    f"FROM {CATALOG_SCHEMA}.reviews_silver WHERE rating <= 2 ORDER BY review_date DESC LIMIT 50"
)

# -- Page 1: Portfolio Overview -----------------------------------------------
# The default page created by __init__ is "Overview"; rename it.
dashboard.pages[0]["displayName"] = "Portfolio Overview"

# Row 0 (y=0, h=2): Filters
dashboard.add_filter_dropdown(
    "brand_health", "brand_name", title="Brand",
    position={"x": 0, "y": 0, "width": 2, "height": 2},
    multi_select=True
)
dashboard.add_date_filter(
    "brand_health", "review_date", title="Date Range",
    position={"x": 2, "y": 0, "width": 2, "height": 2}
)

# Row 1 (y=2, h=2): KPI Counters
dashboard.add_counter(
    "brand_health", "review_count", "SUM", title="Total Reviews",
    position={"x": 0, "y": 2, "width": 1, "height": 2}
)
dashboard.add_counter(
    "brand_health", "avg_rating", "AVG", title="Avg Rating",
    position={"x": 1, "y": 2, "width": 1, "height": 2}
)
dashboard.add_counter(
    "brand_health", "health_score", "AVG", title="Avg Health Score",
    position={"x": 2, "y": 2, "width": 1, "height": 2}
)
dashboard.add_counter(
    "brand_health", "positive_pct", "AVG", title="Positive Review %",
    position={"x": 3, "y": 2, "width": 1, "height": 2}
)
dashboard.add_counter(
    "social_engagement", "total_engagement", "SUM", title="Total Social Engagement",
    position={"x": 4, "y": 2, "width": 2, "height": 2}
)

# Row 2 (y=4, h=5): Main Charts
dashboard.add_line_chart(
    "brand_health", x_field="review_date", y_field="health_score",
    y_agg="AVG", time_grain="WEEK",
    title="Brand Health Score Over Time",
    position={"x": 0, "y": 4, "width": 3, "height": 5},
    color_field="brand_name"
)
dashboard.add_bar_chart(
    "brand_health", x_field="brand_name", y_field="health_score",
    y_agg="AVG", title="Health Score by Brand",
    position={"x": 3, "y": 4, "width": 3, "height": 5},
    sort_descending=True
)

# Row 3 (y=9, h=5): Sentiment Detail
dashboard.add_line_chart(
    "brand_health", x_field="review_date", y_field="negative_pct",
    y_agg="AVG", time_grain="WEEK",
    title="Negative Review % by Brand Over Time",
    position={"x": 0, "y": 9, "width": 3, "height": 5},
    color_field="brand_name"
)
dashboard.add_bar_chart(
    "channel_sentiment", x_field="retailer_name", y_field="avg_rating",
    y_agg="AVG", title="Sentiment by Retailer",
    position={"x": 3, "y": 9, "width": 3, "height": 5},
    color_field="brand_name"
)

# Row 4 (y=14, h=5): Social & Detail
dashboard.add_line_chart(
    "social_engagement", x_field="post_date", y_field="total_engagement",
    y_agg="SUM", time_grain="WEEK",
    title="Social Engagement by Platform",
    position={"x": 0, "y": 14, "width": 3, "height": 5},
    color_field="platform"
)
dashboard.add_table(
    "recent_negative_reviews",
    columns=[
        {"field": "review_date", "title": "Date", "type": "datetime"},
        {"field": "brand_name", "title": "Brand", "type": "string"},
        {"field": "product_name", "title": "Product", "type": "string"},
        {"field": "retailer_name", "title": "Retailer", "type": "string"},
        {"field": "rating", "title": "Rating", "type": "float"},
        {"field": "review_title", "title": "Title", "type": "string"},
        {"field": "review_text", "title": "Review", "type": "string"},
    ],
    title="Recent Negative Reviews",
    position={"x": 3, "y": 14, "width": 3, "height": 5}
)

# -- Deploy via Databricks CLI ------------------------------------------------

payload = dashboard.get_api_payload(WAREHOUSE_ID, PARENT_PATH)

print("Creating dashboard...")
result = subprocess.run(
    [
        "databricks", "api", "post",
        "/api/2.0/lakeview/dashboards",
        f"--profile={PROFILE}",
        "--json", json.dumps(payload),
    ],
    capture_output=True, text=True
)

print(result.stdout)
if result.stderr:
    print("STDERR:", result.stderr)

response = json.loads(result.stdout)
dashboard_id = response.get("dashboard_id", "")
print(f"Dashboard ID: {dashboard_id}")

# Publish
if dashboard_id:
    pub = subprocess.run(
        [
            "databricks", "api", "post",
            f"/api/2.0/lakeview/dashboards/{dashboard_id}/published",
            f"--profile={PROFILE}",
            "--json", json.dumps({"warehouse_id": WAREHOUSE_ID}),
        ],
        capture_output=True, text=True
    )
    print(f"Published: {pub.stdout}")
    if pub.stderr:
        print("Publish STDERR:", pub.stderr)

    print(f"\nDashboard URL: {BASE_URL}/dashboardsv3/{dashboard_id}")
else:
    print("ERROR: No dashboard_id returned. Check output above.")
