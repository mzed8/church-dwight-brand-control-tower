# Church & Dwight — Brand Control Tower

Personalized Brand Control Tower demo for **Church & Dwight Co., Inc.** (NYSE: CHD, $6.2B revenue).

## Demo Brands

| # | Brand | Category | Status | Health Score |
|---|-------|----------|--------|-------------|
| 1 | ARM & HAMMER | Household / Multi-Category | CRITICAL | 64 |
| 2 | OxiClean | Household / Stain Removal | WARNING | 76 |
| 3 | TheraBreath | Oral Care | HEALTHY | 82 |
| 4 | Batiste | Personal Care / Beauty | HEALTHY | 86 |
| 5 | HERO Cosmetics | Skincare / Acne Care | OPPORTUNITY | 90 |

## Alert Narratives

1. **CRITICAL — Cat Litter Reformulation Complaints Surge**: ARM & HAMMER DUAL DEFENSE Cat Litter with Microban generating negative reviews about chemical smell and clumping failure.
2. **WARNING — Linear TV Over-Indexed vs. Retail Media**: OxiClean over-spending on Linear TV (low ROAS) while under-investing in Retail Media (4.2x ROAS). NAD ruled against "Scary Bleach" TV creative.
3. **OPPORTUNITY — TikTok Cleanser Launch Amplification**: HERO Cosmetics TikTok engagement up 270% ahead of 3-SKU cleanser launch. Alix Earle driving 7.2x influencer ROAS.

## Architecture

```
customers/church_dwight/
├── app/                    # Flutter web frontend
│   ├── lib/
│   │   ├── models/         # Brand, Alert, Scenario data models
│   │   ├── providers/      # Riverpod state management
│   │   ├── screens/        # Portfolio, Brand Detail, Scenario Planner, Chat
│   │   ├── services/       # API service (Dio HTTP client)
│   │   ├── theme/          # CHD corporate blue (#003DA5) theme
│   │   └── widgets/        # Reusable UI components
│   └── pubspec.yaml
├── backend/                # FastAPI backend (local dev)
├── deploy/                 # Databricks Apps deployment bundle
│   ├── app.py              # FastAPI entry point
│   ├── app.yaml            # Databricks Apps config
│   ├── requirements.txt    # Python dependencies
│   ├── routes/             # API routes (brands, alerts, chat, scenario)
│   ├── services/           # Databricks SDK, MAS, MMM service clients
│   └── static/             # Flutter web build output
└── scripts/                # Data generation & ML training
    ├── generate_act1_data.py       # Bronze tables (reviews, social, brands)
    ├── generate_act2_data.py       # Bronze tables (spend, sales, promotions)
    ├── generate_complaint_pdfs.py  # PDF complaints for Knowledge Agent
    ├── train_mmm_model.py          # Marketing Mix Model (Ridge regression)
    └── deploy_mmm_endpoint.py      # Model serving endpoint
```

## Databricks Resources

| Resource | Name / ID |
|----------|-----------|
| Workspace | fevm-serverless-stable-ocafq5 |
| Catalog | serverless_stable_ocafq5_catalog |
| Schema | chd_demo |
| Warehouse | 46430b387bfd91fd |
| App URL | https://chd-brand-control-tower-7474660788181193.aws.databricksapps.com |
| Genie Space | 01f12f9ca4c3183ea1c2f3dd03a7e7dd |
| Knowledge Agent | ka-946c08e3-endpoint |
| Multi-Agent System | mas-bc869504-endpoint |
| MMM Endpoint | chd-marketing-mix-model |

## Tables

| Layer | Table | Description |
|-------|-------|-------------|
| Bronze | brands | 5 demo brands with category and revenue |
| Bronze | products | 47 products across 5 brands |
| Bronze | retailers | 5 key retailers (Walmart, Amazon, Target, Kroger, Costco) |
| Bronze | reviews_raw | 50K synthetic product reviews |
| Bronze | social_posts_raw | 20K synthetic social media posts |
| Bronze | marketing_spend | 5K weekly channel spend records |
| Bronze | sales_pos | 100K point-of-sale transactions |
| Bronze | promotions | 500 promotional events |
| Silver | reviews_silver | Reviews joined with brand and retailer names |
| Silver | social_posts_silver | Social posts joined with brand names |
| Gold | brand_health_daily | Daily health scores, sentiment percentages |
| Gold | channel_performance_weekly | Weekly ROAS, spend, revenue by channel |
| Gold | social_engagement_daily | Daily engagement metrics by platform |

## Key Exec

**Ray Bajaj**, EVP, Chief Technology & Analytics Officer — joined Jan 2026 from Kimberly-Clark where he led global data & technology transformation.

## Config

See `configs/church_dwight_config.json` for the full configuration driving this demo.
