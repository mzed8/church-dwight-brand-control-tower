import os
from databricks.sdk import WorkspaceClient

WAREHOUSE_ID = "46430b387bfd91fd"
CATALOG = "serverless_stable_ocafq5_catalog"
SCHEMA = "chd_demo"


NUMERIC_COLUMNS = {
    'health_score', 'positive_pct', 'negative_pct', 'neutral_pct',
    'review_count', 'avg_rating', 'roas', 'spend_amount', 'total_spend',
    'total_revenue', 'impressions', 'clicks', 'total_units_sold', 'ctr_pct',
    'total_engagement', 'avg_engagement', 'post_count', 'coefficient',
    'avg_weekly_spend', 'predicted_revenue_contribution', 'contribution_pct',
    'prev_health_score', 'prev_score', 'avg_roas',
}


def _cast_row(row: dict) -> dict:
    result = {}
    for k, v in row.items():
        if k in NUMERIC_COLUMNS and v is not None:
            try:
                result[k] = float(v)
            except (ValueError, TypeError):
                result[k] = v
        else:
            result[k] = v
    return result

def get_client() -> WorkspaceClient:
    profile = os.getenv("DATABRICKS_PROFILE")
    return WorkspaceClient(profile=profile) if profile else WorkspaceClient()


def query(sql: str) -> list[dict]:
    w = get_client()
    result = w.statement_execution.execute_statement(
        warehouse_id=WAREHOUSE_ID,
        statement=sql,
        catalog=CATALOG,
        schema=SCHEMA,
    )
    if not result.result or not result.result.data_array:
        return []
    columns = [c.name for c in result.manifest.schema.columns]
    return [_cast_row(dict(zip(columns, row))) for row in result.result.data_array]
