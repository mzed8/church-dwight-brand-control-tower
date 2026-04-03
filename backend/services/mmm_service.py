import os
import httpx
from databricks.sdk import WorkspaceClient

MMM_ENDPOINT = os.environ.get("DATABRICKS_MMM_ENDPOINT", "chd-marketing-mix-model")


def _get_auth() -> tuple[str, dict]:
    profile = os.getenv("DATABRICKS_PROFILE")
    w = WorkspaceClient(profile=profile) if profile else WorkspaceClient()
    host = w.config.host.rstrip("/")
    headers = w.config.authenticate()
    headers["Content-Type"] = "application/json"
    return host, headers


async def predict(brand: str, channel_spends: dict[str, float]) -> float:
    host, headers = _get_auth()

    brands = ["ARM & HAMMER", "OxiClean", "TheraBreath", "Batiste", "HERO Cosmetics"]
    channels = ["Paid Search", "Social Media", "Display Ads", "Linear TV", "Connected TV", "Retail Media", "Email / CRM", "Print / Circulars"]

    row = {}
    for b in brands:
        row[f"brand_{b}"] = 1.0 if b == brand else 0.0
    for c in channels:
        row[c] = channel_spends.get(c, 0.0)

    url = f"{host}/serving-endpoints/{MMM_ENDPOINT}/invocations"
    payload = {"dataframe_records": [row]}

    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(url, json=payload, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        predictions = data.get("predictions", [0])
        return predictions[0] if predictions else 0.0
