"""
Generate synthetic CPG marketing data for Church & Dwight Co., Inc. demo on Databricks.
Tables: marketing_spend (5000), sales_pos (100000), promotions (500)
"""

import os
import random
from datetime import date, timedelta

os.environ["DATABRICKS_CONFIG_PROFILE"] = "fevm-serverless-stable-ocafq5"

import polars as pl

# -- Reproducibility
random.seed(42)

# -- Reference data (in-memory only)
BRANDS = {
    1: "ARM & HAMMER",
    2: "OxiClean",
    3: "TheraBreath",
    4: "Batiste",
    5: "HERO Cosmetics",
}
BRAND_PRODUCTS = {b: list(range((b - 1) * 12 + 1, b * 12 + 1)) for b in range(1, 6)}
RETAILERS = {
    1: "Walmart",
    2: "Amazon",
    3: "Target",
    4: "Kroger",
    5: "Costco",
}
CHANNELS = [
    "Paid Search",
    "Social Media",
    "Display Ads",
    "Linear TV",
    "Connected TV",
    "Retail Media",
    "Email / CRM",
    "Print / Circulars",
]

# Weekly Monday dates from 2025-06-02 to 2026-03-09
WEEKS = []
d = date(2025, 6, 2)
while d <= date(2026, 3, 9):
    WEEKS.append(d)
    d += timedelta(days=7)
NUM_WEEKS = len(WEEKS)

REGIONS = ["Northeast", "Southeast", "Midwest", "West", "Southwest"]
REGION_WEIGHTS = [25, 20, 25, 20, 10]

RETAILER_WEIGHTS = {
    1: 30,
    2: 15,
    3: 25,
    4: 12,
    5: 8,
}

PROMO_TYPES = ["BOGO", "% Off", "Bundle", "Endcap", "Digital Coupon"]
PROMO_WEIGHTS = [15, 30, 10, 25, 20]


def _season(d: date) -> str:
    m = d.month
    y = d.year
    if m in (12, 1, 2):
        return f"Winter {y}"
    if m in (3, 4, 5):
        return f"Spring {y}"
    if m in (6, 7, 8):
        return f"Summer {y}"
    return f"Fall {y}"


CPM_FACTOR = {
    "Paid Search": 80,
    "Social Media": 80,
    "Display Ads": 80,
    "Linear TV": 80,
    "Connected TV": 80,
    "Retail Media": 80,
    "Email / CRM": 80,
    "Print / Circulars": 80,
}
CTR = {
    "Paid Search": 0.01,
    "Social Media": 0.01,
    "Display Ads": 0.01,
    "Linear TV": 0.01,
    "Connected TV": 0.01,
    "Retail Media": 0.01,
    "Email / CRM": 0.01,
    "Print / Circulars": 0.01,
}
SPEND_RANGE = {
    "Paid Search": (5000, 50000),
    "Social Media": (5000, 50000),
    "Display Ads": (5000, 50000),
    "Linear TV": (5000, 50000),
    "Connected TV": (5000, 50000),
    "Retail Media": (5000, 50000),
    "Email / CRM": (5000, 50000),
    "Print / Circulars": (5000, 50000),
}
PRICE_RANGE = {
    1: (7, 15),
    2: (7, 15),
    3: (7, 15),
    4: (7, 15),
    5: (7, 15),
}

# Per-product average price (fixed per product)
random.seed(42)
PRODUCT_PRICE = {}
for brand_id, pids in BRAND_PRODUCTS.items():
    lo, hi = PRICE_RANGE[brand_id]
    for pid in pids:
        PRODUCT_PRICE[pid] = round(random.uniform(lo, hi), 2)

# Brand channel allocation weights (narrative-driven)
BRAND_CHANNEL_WEIGHTS = {
    1: {
        "Paid Search": 12,
        "Social Media": 12,
        "Display Ads": 12,
        "Linear TV": 12,
        "Connected TV": 12,
        "Retail Media": 12,
        "Email / CRM": 12,
        "Print / Circulars": 12,
    },
    2: {
        "Paid Search": 12,
        "Social Media": 12,
        "Display Ads": 12,
        "Linear TV": 12,
        "Connected TV": 12,
        "Retail Media": 12,
        "Email / CRM": 12,
        "Print / Circulars": 12,
    },
    3: {
        "Paid Search": 12,
        "Social Media": 12,
        "Display Ads": 12,
        "Linear TV": 12,
        "Connected TV": 12,
        "Retail Media": 12,
        "Email / CRM": 12,
        "Print / Circulars": 12,
    },
    4: {
        "Paid Search": 12,
        "Social Media": 12,
        "Display Ads": 12,
        "Linear TV": 12,
        "Connected TV": 12,
        "Retail Media": 12,
        "Email / CRM": 12,
        "Print / Circulars": 12,
    },
    5: {
        "Paid Search": 12,
        "Social Media": 12,
        "Display Ads": 12,
        "Linear TV": 12,
        "Connected TV": 12,
        "Retail Media": 12,
        "Email / CRM": 12,
        "Print / Circulars": 12,
    },
}


def _spend_amount(brand_id: int, channel: str) -> float:
    lo, hi = SPEND_RANGE[channel]
    return round(random.uniform(lo, hi), 2)


# ============================================================================
# TABLE 1: marketing_spend (5000 rows)
# ============================================================================
random.seed(42)
TARGET_MARKETING_SPEND = 5000

pool = []
for brand_id in range(1, 6):
    for week in WEEKS:
        for ch in CHANNELS:
            spend = _spend_amount(brand_id, ch)
            impr = int(spend * CPM_FACTOR[ch])
            clk = int(impr * CTR[ch])
            campaign = f"{BRANDS[brand_id]} {ch} {_season(week)}"
            pool.append((brand_id, ch, spend, impr, clk, week, campaign))

extra_needed = TARGET_MARKETING_SPEND - len(pool)
if extra_needed > 0:
    extras = random.choices(pool, k=extra_needed)
    jittered = []
    for (bid, ch, sp, im, cl, wk, camp) in extras:
        jitter = random.uniform(0.85, 1.15)
        sp2 = round(sp * jitter, 2)
        im2 = int(sp2 * CPM_FACTOR[ch])
        cl2 = int(im2 * CTR[ch])
        jittered.append((bid, ch, sp2, im2, cl2, wk, camp))
    pool = pool + jittered

all_ms = pool[:TARGET_MARKETING_SPEND]
random.shuffle(all_ms)

rows_ms = []
for i, (bid, ch, sp, im, cl, wk, camp) in enumerate(all_ms, 1):
    rows_ms.append({
        "spend_id": i, "brand_id": bid, "channel": ch,
        "spend_amount": sp, "impressions": im, "clicks": cl,
        "week_start_date": wk, "campaign_name": camp,
    })

df_marketing = pl.DataFrame(rows_ms).cast({
    "spend_id": pl.Int32, "brand_id": pl.Int32,
    "impressions": pl.Int64, "clicks": pl.Int64,
    "spend_amount": pl.Float64, "week_start_date": pl.Date,
})
print(f"marketing_spend rows: {len(df_marketing)}")

# ============================================================================
# TABLE 2: sales_pos (100000 rows)
# ============================================================================
random.seed(42)
TARGET_SALES_POS = 100000

BRAND_VOLUME_WEIGHT = {
    1: 3,
    2: 3,
    3: 3,
    4: 3,
    5: 3,
}
PRODUCT_BASE_WEIGHT = {}
for brand_id, pids in BRAND_PRODUCTS.items():
    for pid in pids:
        PRODUCT_BASE_WEIGHT[pid] = BRAND_VOLUME_WEIGHT[brand_id]

product_ids = list(range(1, 61))
product_weights = [PRODUCT_BASE_WEIGHT[p] for p in product_ids]
retailer_ids = list(range(1, 6))
retailer_wts = [RETAILER_WEIGHTS[r] for r in retailer_ids]


LAST_2_WEEK_STARTS = {w for w in WEEKS if w >= date(2026, 2, 24)}

rows_sales = []
for i in range(1, TARGET_SALES_POS + 1):
    pid = random.choices(product_ids, weights=product_weights, k=1)[0]
    brand_id = (pid - 1) // 12 + 1

    rw = list(retailer_wts)
    rid = random.choices(retailer_ids, weights=rw, k=1)[0]
    region = random.choices(REGIONS, weights=REGION_WEIGHTS, k=1)[0]
    week = random.choice(WEEKS)

    # Default unit range based on brand volume
    vol = BRAND_VOLUME_WEIGHT.get(brand_id, 3)
    units = random.randint(vol * 10, vol * 1000)

    # Crisis brand sales dip in last 2 weeks at top retailers
    if brand_id == 1 and rid in (1, 2, 3) and week in LAST_2_WEEK_STARTS:
        units = int(units * random.uniform(0.3, 0.5))

    # Opportunity brand growth over time
    if brand_id == 5:
        week_idx = WEEKS.index(week)
        growth = 1.0 + 0.015 * week_idx
        units = int(units * growth)

    revenue = round(units * PRODUCT_PRICE[pid], 2)
    is_promoted = random.random() < 0.20

    rows_sales.append({
        "sale_id": i, "product_id": pid, "retailer_id": rid,
        "region": region, "units_sold": units, "revenue": revenue,
        "week_start_date": week, "is_promoted": is_promoted,
    })

df_sales = pl.DataFrame(rows_sales).cast({
    "sale_id": pl.Int32, "product_id": pl.Int32, "retailer_id": pl.Int32,
    "units_sold": pl.Int32, "revenue": pl.Float64, "week_start_date": pl.Date,
})
print(f"sales_pos rows: {len(df_sales)}")

# ============================================================================
# TABLE 3: promotions (500 rows)
# ============================================================================
random.seed(42)
TARGET_PROMOTIONS = 500

rows_promo = []
for i in range(1, TARGET_PROMOTIONS + 1):
    brand_id = random.randint(1, 5)
    rid = random.choices(retailer_ids, weights=retailer_wts, k=1)[0]
    ptype = random.choices(PROMO_TYPES, weights=PROMO_WEIGHTS, k=1)[0]

    if ptype == "BOGO":
        discount = 50.0
    elif ptype == "% Off":
        discount = round(random.uniform(10, 30), 1)
    elif ptype == "Bundle":
        discount = round(random.uniform(15, 25), 1)
    elif ptype == "Endcap":
        discount = 0.0
    else:
        discount = round(random.uniform(10, 20), 1)

    start = date(2025, 6, 1) + timedelta(days=random.randint(0, 272))
    duration = random.randint(7, 28)
    end = start + timedelta(days=duration)

    if ptype in ("BOGO", "Endcap"):
        lift = round(random.uniform(20, 35), 1)
    elif ptype == "% Off":
        lift = round(random.uniform(8, 25), 1)
    else:
        lift = round(random.uniform(5, 20), 1)

    rows_promo.append({
        "promo_id": i, "brand_id": brand_id, "retailer_id": rid,
        "promo_type": ptype, "discount_pct": discount,
        "start_date": start, "end_date": end, "estimated_lift_pct": lift,
    })

df_promos = pl.DataFrame(rows_promo).cast({
    "promo_id": pl.Int32, "brand_id": pl.Int32, "retailer_id": pl.Int32,
    "discount_pct": pl.Float64, "start_date": pl.Date, "end_date": pl.Date,
    "estimated_lift_pct": pl.Float64,
})
print(f"promotions rows: {len(df_promos)}")

# ============================================================================
# WRITE TO DATABRICKS UNITY CATALOG
# ============================================================================
from databricks.connect import DatabricksSession

spark = DatabricksSession.builder.profile("fevm-serverless-stable-ocafq5").serverless().getOrCreate()
CATALOG_SCHEMA = "serverless_stable_ocafq5_catalog.chd_demo"


def write_table(polars_df: pl.DataFrame, table_name: str):
    pandas_df = polars_df.to_pandas()
    spark_df = spark.createDataFrame(pandas_df)
    full_name = f"{CATALOG_SCHEMA}.{table_name}"
    spark_df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(full_name)
    count = spark.table(full_name).count()
    print(f"  -> {full_name}: {count} rows written")


print("\nWriting to Databricks Unity Catalog...")
write_table(df_marketing, "marketing_spend")
write_table(df_sales, "sales_pos")
write_table(df_promos, "promotions")

print("\nDone!")
