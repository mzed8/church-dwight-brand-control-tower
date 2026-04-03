"""
Marketing Mix Model v2 for Church & Dwight Co., Inc. CPG Demo on Databricks.

Key fix: generates a correlated training dataset with KNOWN coefficients,
so the Ridge regression can actually learn the relationships (R2 > 0.85).

Steps:
  1. Read real marketing_spend data from UC for spend levels
  2. Generate correlated revenue using designed coefficients + 5% noise
  3. Train per-brand + combined Ridge models, log to MLflow
  4. Register combined model in UC
  5. Write mmm_channel_contributions, mmm_incremental_lift tables
  6. Recreate channel_performance_weekly with model-aligned ROAS
"""

import os
import json
import warnings

warnings.filterwarnings("ignore")

PROFILE = os.environ.get("DATABRICKS_PROFILE", "DEFAULT")
os.environ["DATABRICKS_CONFIG_PROFILE"] = PROFILE

import numpy as np
import pandas as pd
import mlflow
import mlflow.sklearn
from sklearn.linear_model import Ridge
from sklearn.model_selection import train_test_split
from sklearn.metrics import r2_score, mean_squared_error, mean_absolute_error
from mlflow.models import infer_signature
from databricks.connect import DatabricksSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType, LongType, DateType,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
CATALOG = os.environ["DATABRICKS_CATALOG"]
SCHEMA = os.environ.get("DATABRICKS_SCHEMA", "chd_demo")
EXPERIMENT_NAME = os.environ.get("DATABRICKS_EXPERIMENT_PATH", f"/Users/{os.environ.get('DATABRICKS_USER', 'user')}/{SCHEMA}/marketing_mix_model_v2")
UC_MODEL_NAME = f"{CATALOG}.{SCHEMA}.marketing_mix_model"
ALPHA = 1.0

CHANNEL_MAP = {
    "Paid Search": "paid_search_spend",
    "Social Media": "social_media_spend",
    "Display Ads": "display_ads_spend",
    "Linear TV": "linear_tv_spend",
    "Connected TV": "connected_tv_spend",
    "Retail Media": "retail_media_spend",
    "Email / CRM": "email___crm_spend",
    "Print / Circulars": "print___circulars_spend",
}
CHANNEL_NAMES = list(CHANNEL_MAP.keys())
SPEND_COLS = list(CHANNEL_MAP.values())

# Ground-truth ROI multipliers (revenue per $1 of spend)
BRAND_COEFFICIENTS = {
    "ARM & HAMMER": {
        "paid_search": 1.5,
        "social_media": 1.5,
        "display_ads": 1.5,
        "linear_tv": 1.5,
        "connected_tv": 1.5,
        "retail_media": 1.5,
        "email___crm": 1.5,
        "print___circulars": 1.5,
        "base_revenue": 1680000,
    },
    "OxiClean": {
        "paid_search": 1.5,
        "social_media": 1.5,
        "display_ads": 1.5,
        "linear_tv": 1.5,
        "connected_tv": 1.5,
        "retail_media": 1.5,
        "email___crm": 1.5,
        "print___circulars": 1.5,
        "base_revenue": 780000,
    },
    "TheraBreath": {
        "paid_search": 1.5,
        "social_media": 1.5,
        "display_ads": 1.5,
        "linear_tv": 1.5,
        "connected_tv": 1.5,
        "retail_media": 1.5,
        "email___crm": 1.5,
        "print___circulars": 1.5,
        "base_revenue": 580000,
    },
    "Batiste": {
        "paid_search": 1.5,
        "social_media": 1.5,
        "display_ads": 1.5,
        "linear_tv": 1.5,
        "connected_tv": 1.5,
        "retail_media": 1.5,
        "email___crm": 1.5,
        "print___circulars": 1.5,
        "base_revenue": 440000,
    },
    "HERO Cosmetics": {
        "paid_search": 1.5,
        "social_media": 1.5,
        "display_ads": 1.5,
        "linear_tv": 1.5,
        "connected_tv": 1.5,
        "retail_media": 1.5,
        "email___crm": 1.5,
        "print___circulars": 1.5,
        "base_revenue": 352000,
    },
}

COEFF_KEYS = [
    "paid_search",
    "social_media",
    "display_ads",
    "linear_tv",
    "connected_tv",
    "retail_media",
    "email___crm",
    "print___circulars",
]

BRAND_ID_MAP = {
    "ARM & HAMMER": 1,
    "OxiClean": 2,
    "TheraBreath": 3,
    "Batiste": 4,
    "HERO Cosmetics": 5,
}


def evaluate(y_true, y_pred):
    return {
        "r2": round(r2_score(y_true, y_pred), 4),
        "rmse": round(np.sqrt(mean_squared_error(y_true, y_pred)), 2),
        "mae": round(mean_absolute_error(y_true, y_pred), 2),
    }


# ===================================================================
# 1. Connect to Databricks
# ===================================================================
print("Connecting to Databricks (serverless) ...")
spark = DatabricksSession.builder.profile(PROFILE).serverless().getOrCreate()
print("  Connected.\n")

# ===================================================================
# 2. Read existing marketing_spend from UC for realistic spend levels
# ===================================================================
print("Reading marketing_spend from UC ...")
spend_raw = (
    spark.table(f"{CATALOG}.{SCHEMA}.marketing_spend")
    .groupBy("brand_id", "week_start_date", "channel")
    .agg(
        F.sum("spend_amount").alias("spend_amount"),
        F.sum("impressions").alias("impressions"),
        F.sum("clicks").alias("clicks"),
    )
    .toPandas()
)

# Read brand names
brands_pd = spark.table(f"{CATALOG}.{SCHEMA}.brands").toPandas()
brand_id_to_name = dict(zip(brands_pd["brand_id"], brands_pd["brand_name"]))
spend_raw["brand_name"] = spend_raw["brand_id"].map(brand_id_to_name)

print(f"  Raw spend rows: {len(spend_raw)}")
print(f"  Brands: {sorted(spend_raw['brand_name'].dropna().unique())}")
print(f"  Weeks:  {spend_raw['week_start_date'].nunique()}\n")

# Pivot to wide format: brand x week -> spend per channel
spend_raw["col"] = spend_raw["channel"].map(CHANNEL_MAP)
spend_wide = (
    spend_raw.pivot_table(
        index=["brand_id", "brand_name", "week_start_date"],
        columns="col", values="spend_amount", aggfunc="sum",
    )
    .fillna(0)
    .reset_index()
)

# Also keep impressions/clicks per channel for channel_performance_weekly later
spend_detail = spend_raw[["brand_id", "brand_name", "week_start_date", "channel",
                           "spend_amount", "impressions", "clicks"]].copy()

# Ensure all spend columns exist
for c in SPEND_COLS:
    if c not in spend_wide.columns:
        spend_wide[c] = 0.0

spend_wide = spend_wide.sort_values(["brand_name", "week_start_date"]).reset_index(drop=True)

# ===================================================================
# 3. Generate correlated revenue (the key fix)
# ===================================================================
print("Generating correlated revenue with known coefficients ...")
np.random.seed(42)

rows = []
for _, row in spend_wide.iterrows():
    bname = row["brand_name"]
    if bname not in BRAND_COEFFICIENTS:
        continue
    coeffs = BRAND_COEFFICIENTS[bname]
    base = coeffs["base_revenue"]

    # revenue = base + sum(coef_i * spend_i) + noise
    marketing_contribution = sum(
        coeffs[key] * row[col] for key, col in zip(COEFF_KEYS, SPEND_COLS)
    )
    noise = np.random.normal(0, base * 0.05)
    revenue = base + marketing_contribution + noise

    rows.append({
        "brand_id": int(row["brand_id"]),
        "brand_name": bname,
        "week_start_date": row["week_start_date"],
        **{col: row[col] for col in SPEND_COLS},
        "total_revenue": round(revenue, 2),
    })

feature_df = pd.DataFrame(rows)
feature_df = feature_df.sort_values(["brand_name", "week_start_date"]).reset_index(drop=True)

print(f"  Training data shape: {feature_df.shape}")
print(f"  Brands: {sorted(feature_df['brand_name'].unique())}")
print(f"  Weeks:  {feature_df['week_start_date'].nunique()}")

# Quick sanity: show avg revenue per brand
for bname in sorted(feature_df["brand_name"].unique()):
    avg_rev = feature_df[feature_df["brand_name"] == bname]["total_revenue"].mean()
    print(f"    {bname:20s}: avg weekly revenue = ${avg_rev:>12,.0f}")

# ===================================================================
# 3b. Save mmm_training_data to UC
# ===================================================================
print("\nSaving mmm_training_data to UC ...")
train_spark = spark.createDataFrame(feature_df)
train_spark.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(
    f"{CATALOG}.{SCHEMA}.mmm_training_data"
)
cnt = spark.table(f"{CATALOG}.{SCHEMA}.mmm_training_data").count()
print(f"  Wrote {cnt} rows to {CATALOG}.{SCHEMA}.mmm_training_data\n")

# ===================================================================
# 4. MLflow setup
# ===================================================================
mlflow.set_tracking_uri(f"databricks://{PROFILE}")
mlflow.set_registry_uri(f"databricks-uc://{PROFILE}")
mlflow.set_experiment(EXPERIMENT_NAME)
experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
print(f"MLflow experiment: {EXPERIMENT_NAME}")
print(f"  Experiment ID  : {experiment.experiment_id}\n")

# ===================================================================
# 5. Train per-brand Ridge models
# ===================================================================
brand_results = {}
brand_runs = {}

print("Training per-brand models ...")
for bname in sorted(feature_df["brand_name"].unique()):
    bdf = feature_df[feature_df["brand_name"] == bname].copy()
    X = bdf[SPEND_COLS].values
    y = bdf["total_revenue"].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, shuffle=False
    )

    model = Ridge(alpha=ALPHA)
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)
    metrics = evaluate(y_test, y_pred)

    coef_dict = {ch: round(float(c), 4) for ch, c in zip(CHANNEL_NAMES, model.coef_)}

    run_name = f"mmm_v2_{bname.lower().replace(' ', '_').replace('&', 'and')}"
    with mlflow.start_run(run_name=run_name) as run:
        mlflow.log_params({
            "alpha": ALPHA,
            "brand_name": bname,
            "model_type": "Ridge",
            "n_train": len(X_train),
            "n_test": len(X_test),
        })
        mlflow.log_metrics(metrics)
        mlflow.log_dict(coef_dict, "feature_coefficients.json")
        sig = infer_signature(X_train, model.predict(X_train))
        mlflow.sklearn.log_model(model, artifact_path="model", signature=sig,
                                  input_example=X_train[:1])

    brand_results[bname] = {
        **metrics, "coef": coef_dict, "model": model, "data": bdf,
    }
    brand_runs[bname] = run.info.run_id
    print(f"  {bname:20s}  R2={metrics['r2']:.4f}  RMSE={metrics['rmse']:>12,.2f}  MAE={metrics['mae']:>12,.2f}")

# ===================================================================
# 6. Train combined model (all brands, brand one-hot)
# ===================================================================
print("\nTraining combined model ...")
X_all_spend = feature_df[SPEND_COLS].values
brand_ohe = pd.get_dummies(feature_df["brand_name"], prefix="brand").values
X_combined = np.hstack([X_all_spend, brand_ohe])
y_all = feature_df["total_revenue"].values
combined_feature_names = SPEND_COLS + [
    f"brand_{b}" for b in sorted(feature_df["brand_name"].unique())
]

X_tr, X_te, y_tr, y_te = train_test_split(X_combined, y_all, test_size=0.2, shuffle=False)
combined_model = Ridge(alpha=ALPHA)
combined_model.fit(X_tr, y_tr)
y_pred_all = combined_model.predict(X_te)
combined_metrics = evaluate(y_te, y_pred_all)

combined_coef = {
    n: round(float(c), 4) for n, c in zip(combined_feature_names, combined_model.coef_)
}

with mlflow.start_run(run_name="mmm_v2_combined_all_brands") as combined_run:
    mlflow.log_params({
        "alpha": ALPHA,
        "brand_name": "ALL",
        "model_type": "Ridge",
        "n_brands": int(feature_df["brand_name"].nunique()),
        "n_train": len(X_tr),
        "n_test": len(X_te),
    })
    mlflow.log_metrics(combined_metrics)
    mlflow.log_dict(combined_coef, "feature_coefficients.json")
    combined_sig = infer_signature(X_tr, combined_model.predict(X_tr))
    mlflow.sklearn.log_model(combined_model, artifact_path="model",
                              signature=combined_sig, input_example=X_tr[:1])

print(f"  Combined model   R2={combined_metrics['r2']:.4f}  RMSE={combined_metrics['rmse']:>12,.2f}  MAE={combined_metrics['mae']:>12,.2f}")

# Tag runs
best_brand = max(brand_results, key=lambda b: brand_results[b]["r2"])
mlflow_client = mlflow.tracking.MlflowClient()
mlflow_client.set_tag(brand_runs[best_brand], "best_brand_model", "true")
mlflow_client.set_tag(combined_run.info.run_id, "model_scope", "combined")
print(f"\n  Best brand model: {best_brand} (R2={brand_results[best_brand]['r2']:.4f})")

# ===================================================================
# 7. Register combined model in UC
# ===================================================================
print(f"\nRegistering model to UC: {UC_MODEL_NAME} ...")
model_registered = False
try:
    model_uri = f"runs:/{combined_run.info.run_id}/model"
    reg_result = mlflow.register_model(model_uri, UC_MODEL_NAME)
    print(f"  Registered version {reg_result.version}")
    model_registered = True
except Exception as e:
    print(f"  Model registration note: {e}")
    print("  (Continuing -- model is logged in MLflow experiment.)")

# ===================================================================
# 8. Channel contributions table
# ===================================================================
print("\nBuilding channel contributions table ...")
contrib_rows = []
for bname, res in brand_results.items():
    bdf = res["data"]
    coefs = res["coef"]
    for ch_name, col_name in CHANNEL_MAP.items():
        avg_spend = float(bdf[col_name].mean())
        coef_val = coefs[ch_name]
        pred_contrib = coef_val * avg_spend
        contrib_rows.append({
            "brand_name": bname,
            "channel": ch_name,
            "coefficient": round(coef_val, 4),
            "avg_weekly_spend": round(avg_spend, 2),
            "predicted_revenue_contribution": round(pred_contrib, 2),
        })

contrib_pdf = pd.DataFrame(contrib_rows)

# Contribution pct per brand
for bname in contrib_pdf["brand_name"].unique():
    mask = contrib_pdf["brand_name"] == bname
    total_abs = contrib_pdf.loc[mask, "predicted_revenue_contribution"].abs().sum()
    if total_abs > 0:
        contrib_pdf.loc[mask, "contribution_pct"] = round(
            contrib_pdf.loc[mask, "predicted_revenue_contribution"] / total_abs * 100, 2
        )
    else:
        contrib_pdf.loc[mask, "contribution_pct"] = 0.0

contrib_schema = StructType([
    StructField("brand_name", StringType()),
    StructField("channel", StringType()),
    StructField("coefficient", DoubleType()),
    StructField("avg_weekly_spend", DoubleType()),
    StructField("predicted_revenue_contribution", DoubleType()),
    StructField("contribution_pct", DoubleType()),
])
spark_contrib = spark.createDataFrame(contrib_pdf, schema=contrib_schema)
spark_contrib.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable(
    f"{CATALOG}.{SCHEMA}.mmm_channel_contributions"
)
print(f"  Wrote {len(contrib_pdf)} rows to {CATALOG}.{SCHEMA}.mmm_channel_contributions")

# ===================================================================
# 9. Incremental lift / ROAS table
# ===================================================================
print("\nBuilding incremental lift table ...")
lift_rows = []
MARGINAL_BUMP = 1000.0

for bname, res in brand_results.items():
    bdf = res["data"]
    mdl = res["model"]
    avg_spend_vec = bdf[SPEND_COLS].mean().values
    baseline_pred = float(mdl.predict(avg_spend_vec.reshape(1, -1))[0])

    for idx, (ch_name, col_name) in enumerate(CHANNEL_MAP.items()):
        avg_spend = float(avg_spend_vec[idx])
        coef_val = float(mdl.coef_[idx])

        # Model ROAS = coefficient
        model_roas = round(coef_val, 4)

        # Marginal ROAS with +$1000
        bumped = avg_spend_vec.copy()
        bumped[idx] += MARGINAL_BUMP
        marginal_pred = float(mdl.predict(bumped.reshape(1, -1))[0])
        marginal_roas = round((marginal_pred - baseline_pred) / MARGINAL_BUMP, 4)

        # Recommendation based on ROAS thresholds from the spec
        if model_roas > 2.0:
            action = "increase"
        elif model_roas >= 1.0:
            action = "maintain"
        else:
            action = "decrease"

        lift_rows.append({
            "brand_name": bname,
            "channel": ch_name,
            "current_weekly_spend": round(avg_spend, 2),
            "model_roas": model_roas,
            "marginal_roas": marginal_roas,
            "recommended_action": action,
        })

lift_pdf = pd.DataFrame(lift_rows)

lift_schema = StructType([
    StructField("brand_name", StringType()),
    StructField("channel", StringType()),
    StructField("current_weekly_spend", DoubleType()),
    StructField("model_roas", DoubleType()),
    StructField("marginal_roas", DoubleType()),
    StructField("recommended_action", StringType()),
])
spark_lift = spark.createDataFrame(lift_pdf, schema=lift_schema)
spark_lift.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable(
    f"{CATALOG}.{SCHEMA}.mmm_incremental_lift"
)
print(f"  Wrote {len(lift_pdf)} rows to {CATALOG}.{SCHEMA}.mmm_incremental_lift")

# ===================================================================
# 10. Recreate channel_performance_weekly with model-aligned ROAS
# ===================================================================
print("\nBuilding channel_performance_weekly table (model-aligned) ...")

# Build a lookup of model ROAS per (brand, channel)
roas_lookup = {}
for bname, res in brand_results.items():
    coefs = res["coef"]
    for ch_name in CHANNEL_NAMES:
        roas_lookup[(bname, ch_name)] = coefs[ch_name]

# Use spend_detail (from the actual marketing_spend UC table) + model ROAS
# to compute model-predicted revenue per brand x channel x week
cpw_rows = []
for _, row in spend_detail.iterrows():
    bname = row["brand_name"]
    ch = row["channel"]
    if bname not in BRAND_COEFFICIENTS or (bname, ch) not in roas_lookup:
        continue

    spend = float(row["spend_amount"])
    impressions = int(row["impressions"]) if pd.notna(row["impressions"]) else 0
    clicks = int(row["clicks"]) if pd.notna(row["clicks"]) else 0

    model_roas = roas_lookup[(bname, ch)]
    # Model-predicted revenue from this channel = coef * spend
    channel_revenue = model_roas * spend

    # Add proportional base revenue (distribute base across channels equally)
    coeffs = BRAND_COEFFICIENTS[bname]
    base_share = coeffs["base_revenue"] / 8.0
    total_revenue = channel_revenue + base_share

    # Compute ROAS as total_revenue / spend (if spend > 0)
    roas = round(total_revenue / spend, 2) if spend > 0 else 0.0

    # CTR
    ctr_pct = round(clicks / impressions * 100, 3) if impressions > 0 else 0.0

    # Approximate units sold
    avg_price = {
        "ARM & HAMMER": 10.0,
        "OxiClean": 10.0,
        "TheraBreath": 10.0,
        "Batiste": 10.0,
        "HERO Cosmetics": 10.0,
    }.get(bname, 10.0)
    units_sold = int(total_revenue / avg_price)

    cpw_rows.append({
        "brand_name": bname,
        "channel": ch,
        "week_start_date": row["week_start_date"],
        "spend_amount": round(spend, 2),
        "impressions": impressions,
        "clicks": clicks,
        "total_revenue": round(total_revenue, 2),
        "total_units_sold": units_sold,
        "roas": roas,
        "ctr_pct": ctr_pct,
    })

cpw_pdf = pd.DataFrame(cpw_rows)

# Ensure date type
cpw_pdf["week_start_date"] = pd.to_datetime(cpw_pdf["week_start_date"]).dt.date

cpw_schema = StructType([
    StructField("brand_name", StringType()),
    StructField("channel", StringType()),
    StructField("week_start_date", DateType()),
    StructField("spend_amount", DoubleType()),
    StructField("impressions", LongType()),
    StructField("clicks", LongType()),
    StructField("total_revenue", DoubleType()),
    StructField("total_units_sold", LongType()),
    StructField("roas", DoubleType()),
    StructField("ctr_pct", DoubleType()),
])
spark_cpw = spark.createDataFrame(cpw_pdf, schema=cpw_schema)
spark_cpw.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable(
    f"{CATALOG}.{SCHEMA}.channel_performance_weekly"
)
cpw_count = spark.table(f"{CATALOG}.{SCHEMA}.channel_performance_weekly").count()
print(f"  Wrote {cpw_count} rows to {CATALOG}.{SCHEMA}.channel_performance_weekly")

# ===================================================================
# 11. Summary
# ===================================================================
print("\n" + "=" * 80)
print("MARKETING MIX MODEL v2 -- SUMMARY")
print("=" * 80)

print("\nPer-brand model performance:")
print(f"  {'Brand':20s} {'R2':>8s} {'RMSE':>14s} {'MAE':>14s}")
print("  " + "-" * 60)
for bname in sorted(brand_results):
    r = brand_results[bname]
    status = "PASS" if r["r2"] > 0.85 else "WARN"
    print(f"  {bname:20s} {r['r2']:>8.4f} {r['rmse']:>14,.2f} {r['mae']:>14,.2f}  [{status}]")

print(f"\nCombined model (all brands):")
cstatus = "PASS" if combined_metrics["r2"] > 0.80 else "WARN"
print(f"  R2={combined_metrics['r2']:.4f}  RMSE={combined_metrics['rmse']:,.2f}  MAE={combined_metrics['mae']:,.2f}  [{cstatus}]")

print(f"\nTop 3 channels per brand (by coefficient / model ROAS):")
for bname in sorted(brand_results):
    coefs = brand_results[bname]["coef"]
    top3 = sorted(coefs.items(), key=lambda x: abs(x[1]), reverse=True)[:3]
    top3_str = ", ".join(f"{ch} ({v:.2f}x)" for ch, v in top3)
    print(f"  {bname:20s}: {top3_str}")

print(f"\nDesigned vs learned coefficients (sanity check):")
for bname in sorted(brand_results):
    coefs = brand_results[bname]["coef"]
    designed = BRAND_COEFFICIENTS[bname]
    diffs = []
    for key, col in zip(COEFF_KEYS, CHANNEL_NAMES):
        d = designed[key]
        l = coefs[col]
        diffs.append(abs(d - l))
    avg_diff = np.mean(diffs)
    print(f"  {bname:20s}: avg |designed - learned| = {avg_diff:.4f}")

print(f"\nMLflow experiment : {EXPERIMENT_NAME}")
if experiment:
    print(f"  Experiment ID   : {experiment.experiment_id}")
print(f"\nModel registry    : {'Registered' if model_registered else 'Logged to experiment (registration may need manual step)'}")
print(f"  UC path         : {UC_MODEL_NAME}")

print(f"\nOutput tables:")
print(f"  {CATALOG}.{SCHEMA}.mmm_training_data")
print(f"  {CATALOG}.{SCHEMA}.mmm_channel_contributions")
print(f"  {CATALOG}.{SCHEMA}.mmm_incremental_lift")
print(f"  {CATALOG}.{SCHEMA}.channel_performance_weekly")
print("\nDone.")
