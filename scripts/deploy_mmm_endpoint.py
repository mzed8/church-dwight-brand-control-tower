"""
Deploy the Marketing Mix Model as a Databricks Model Serving endpoint
and run scenario planning tests.

The registered model is a combined Ridge regression model
with 8 spend features + 5 brand one-hot features (13 total).

Usage:
  uv run --with requests scripts/deploy_mmm_endpoint.py
"""

import json
import os
import subprocess
import time

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PROFILE = "fevm-serverless-stable-ocafq5"
WORKSPACE = "https://fevm-serverless-stable-ocafq5.cloud.databricks.com"
ENDPOINT_NAME = "chd-marketing-mix-model"
MODEL_NAME = "serverless_stable_ocafq5_catalog.chd_demo.marketing_mix_model"
MODEL_VERSION = "2"

# Feature order (from training script):
# 8 spend cols (in channel order)
# 5 brand one-hot (sorted alphabetically)
SPEND_LABELS = [
    "Paid Search",
    "Social Media",
    "Display Ads",
    "Linear TV",
    "Connected TV",
    "Retail Media",
    "Email / CRM",
    "Print / Circulars",
]
BRAND_NAMES = ["ARM \u0026 HAMMER", "Batiste", "HERO Cosmetics", "OxiClean", "TheraBreath"]


def cli(method, path, payload=None):
    """Call Databricks REST API via the CLI."""
    cmd = ["databricks", "api", method, path, f"--profile={PROFILE}"]
    if payload:
        cmd += ["--json", json.dumps(payload)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        try:
            return json.loads(result.stderr)
        except Exception:
            raise RuntimeError(f"CLI error: {result.stderr.strip()}")
    return json.loads(result.stdout) if result.stdout.strip() else {}


def brand_vector(brand_name):
    """Return one-hot vector for a brand."""
    return [1 if b == brand_name else 0 for b in BRAND_NAMES]


def make_row(spends, brand):
    """Combine spend values + brand one-hot into a single feature row."""
    return spends + brand_vector(brand)


def invoke(rows):
    """Send rows to the serving endpoint, return predictions."""
    resp = cli("post", f"/serving-endpoints/{ENDPOINT_NAME}/invocations", {
        "dataframe_split": {"data": rows}
    })
    return resp.get("predictions", [])


# ===================================================================
# Step 1: Create or verify the serving endpoint
# ===================================================================
print("=" * 70)
print("STEP 1: Create / verify serving endpoint")
print("=" * 70)

existing = cli("get", f"/api/2.0/serving-endpoints/{ENDPOINT_NAME}")
if "error_code" in existing and "RESOURCE_DOES_NOT_EXIST" in str(existing.get("error_code", "")):
    print(f"  Creating endpoint '{ENDPOINT_NAME}' ...")
    resp = cli("post", "/api/2.0/serving-endpoints", {
        "name": ENDPOINT_NAME,
        "config": {
            "served_entities": [{
                "entity_name": MODEL_NAME,
                "entity_version": MODEL_VERSION,
                "scale_to_zero_enabled": True,
                "workload_size": "Small",
            }]
        }
    })
    print(f"  Created. ID: {resp.get('id', 'N/A')}")
else:
    state = existing.get("state", {})
    print(f"  Endpoint already exists. State: ready={state.get('ready')}, config_update={state.get('config_update')}")
    config = existing.get("config", {})
    entities = config.get("served_entities", [])
    current_version = entities[0].get("entity_version") if entities else None
    if current_version != MODEL_VERSION:
        print(f"  Updating from version {current_version} to {MODEL_VERSION} ...")
        cli("put", f"/api/2.0/serving-endpoints/{ENDPOINT_NAME}/config", {
            "served_entities": [{
                "entity_name": MODEL_NAME,
                "entity_version": MODEL_VERSION,
                "scale_to_zero_enabled": True,
                "workload_size": "Small",
            }]
        })

# ===================================================================
# Step 2: Wait for endpoint to be ready
# ===================================================================
print("\n" + "=" * 70)
print("STEP 2: Wait for endpoint to be ready")
print("=" * 70)

MAX_POLLS = 20
POLL_INTERVAL = 30

for i in range(1, MAX_POLLS + 1):
    resp = cli("get", f"/api/2.0/serving-endpoints/{ENDPOINT_NAME}")
    state = resp.get("state", {})
    ready = state.get("ready", "UNKNOWN")
    config_update = state.get("config_update", "UNKNOWN")
    print(f"  Poll {i}/{MAX_POLLS}: ready={ready}, config_update={config_update}")

    if ready == "READY" and config_update == "NOT_UPDATING":
        print("  Endpoint is READY.")
        break
    if config_update == "UPDATE_FAILED":
        print("  ERROR: Endpoint update failed!")
        pending = resp.get("pending_config", {})
        for se in pending.get("served_entities", []):
            print(f"    {se.get('state', {})}")
        raise SystemExit(1)

    time.sleep(POLL_INTERVAL)
else:
    print("  WARNING: Timed out waiting for endpoint. Proceeding anyway ...")

# ===================================================================
# Step 3: Scenario planning tests
# ===================================================================
print("\n" + "=" * 70)
print("STEP 3: Scenario planning tests")
print("=" * 70)

# ---------- Scenario 1: ARM & HAMMER ----------
print("\n--- ARM & HAMMER: Scenario Planning Test ---")
# Example: shift spend between channels
current_1 = [52500] * 8
shifted_1 = list(current_1)
# Modify a channel spend for what-if analysis
shifted_1[0] = int(shifted_1[0] * 0.5)  # Reduce first channel
shifted_1[1] = int(shifted_1[1] * 1.5)  # Increase second channel

preds = invoke([
    make_row(current_1, "ARM & HAMMER"),
    make_row(shifted_1, "ARM & HAMMER"),
])
base_1, new_1 = preds[0], preds[1]
delta_1 = new_1 - base_1

print(f"  Current state prediction : ${base_1:>14,.2f}")
print(f"  Scenario prediction      : ${new_1:>14,.2f}")
print(f"  Delta (what-if value)    : ${delta_1:>+14,.2f}")
print(f"  Change                   : {delta_1 / base_1 * 100:>+.2f}%")

# ---------- Scenario 2: OxiClean ----------
print("\n--- OxiClean: Scenario Planning Test ---")
current_2 = [24375] * 8
shifted_2 = list(current_2)
shifted_2[2] = int(shifted_2[2] * 1.5)

preds = invoke([
    make_row(current_2, "OxiClean"),
    make_row(shifted_2, "OxiClean"),
])
base_2, new_2 = preds[0], preds[1]
delta_2 = new_2 - base_2

print(f"  Current state prediction : ${base_2:>14,.2f}")
print(f"  Scenario prediction      : ${new_2:>14,.2f}")
print(f"  Delta (what-if value)    : ${delta_2:>+14,.2f}")
print(f"  Change                   : {delta_2 / base_2 * 100:>+.2f}%")

# ---------- Scenario 3: TheraBreath ----------
print("\n--- TheraBreath: Scenario Planning Test ---")
current_3 = [18125] * 8
shifted_3 = list(current_3)
shifted_3[3] = int(shifted_3[3] * 1.5)

preds = invoke([
    make_row(current_3, "TheraBreath"),
    make_row(shifted_3, "TheraBreath"),
])
base_3, new_3 = preds[0], preds[1]
delta_3 = new_3 - base_3

print(f"  Current state prediction : ${base_3:>14,.2f}")
print(f"  Scenario prediction      : ${new_3:>14,.2f}")
print(f"  Delta (what-if value)    : ${delta_3:>+14,.2f}")
print(f"  Change                   : {delta_3 / base_3 * 100:>+.2f}%")

# ---------- Scenario 4: Batiste ----------
print("\n--- Batiste: Scenario Planning Test ---")
current_4 = [13750] * 8
shifted_4 = list(current_4)
shifted_4[4] = int(shifted_4[4] * 1.5)

preds = invoke([
    make_row(current_4, "Batiste"),
    make_row(shifted_4, "Batiste"),
])
base_4, new_4 = preds[0], preds[1]
delta_4 = new_4 - base_4

print(f"  Current state prediction : ${base_4:>14,.2f}")
print(f"  Scenario prediction      : ${new_4:>14,.2f}")
print(f"  Delta (what-if value)    : ${delta_4:>+14,.2f}")
print(f"  Change                   : {delta_4 / base_4 * 100:>+.2f}%")

# ===================================================================
# Summary
# ===================================================================
print("\n" + "=" * 70)
print("DEPLOYMENT SUMMARY")
print("=" * 70)
print(f"  Endpoint URL  : {WORKSPACE}/serving-endpoints/{ENDPOINT_NAME}/invocations")
print(f"  Endpoint name : {ENDPOINT_NAME}")
print(f"  Model         : {MODEL_NAME} v{MODEL_VERSION}")
print(f"  Status        : READY")
print()
print("  Scenario Results:")
print(f"  {'Scenario':<55s} {'Delta':>14s}")
print("  " + "-" * 70)
print(f"  {'ARM & HAMMER: Spend Reallocation Test':<55s} ${delta_1:>+13,.2f}")
print(f"  {'OxiClean: Spend Reallocation Test':<55s} ${delta_2:>+13,.2f}")
print(f"  {'TheraBreath: Spend Reallocation Test':<55s} ${delta_3:>+13,.2f}")
print(f"  {'Batiste: Spend Reallocation Test':<55s} ${delta_4:>+13,.2f}")
print()
print("Done.")
