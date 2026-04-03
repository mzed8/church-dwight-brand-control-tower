# Church & Dwight — Brand Control Tower

Personalized brand marketing intelligence demo for **Church & Dwight Co., Inc.** (NYSE: CHD).
Flutter web frontend + FastAPI backend deployed on Databricks Apps, with AI/BI Genie Space, Knowledge Agent, and Multi-Agent Supervisor.

## What is the Brand Control Tower?

The Brand Control Tower is a real-time brand marketing intelligence platform that gives portfolio brand managers a single pane of glass across brand health, marketing spend efficiency, social engagement, and consumer sentiment. Instead of toggling between dashboards, spreadsheets, and agency reports, a brand director can:

- **Monitor brand health** — daily health scores computed from consumer reviews, with trend lines and sentiment breakdowns (positive/negative/neutral) per brand
- **Optimize channel spend** — see ROAS by marketing channel (Paid Search, Social, Linear TV, Retail Media, CTV, etc.) and identify misallocations where spend doesn't match return
- **Track social engagement** — engagement volume and trends across TikTok, Instagram, YouTube, and other platforms per brand
- **Act on AI-generated alerts** — three severity tiers (critical, warning, opportunity) surface the most important issues across the portfolio, with recommended actions
- **Run scenario planning** — adjust channel spend sliders and see projected revenue impact using a Marketing Mix Model (Ridge regression trained on the demo data)
- **Ask questions in natural language** — a chat interface powered by a Multi-Agent Supervisor routes questions to the right AI agent for structured data or unstructured document analysis

The demo uses Church & Dwight's actual brand portfolio (ARM & HAMMER, OxiClean, TheraBreath, Batiste, HERO Cosmetics) with synthetic data that reflects realistic market dynamics.

## Architecture

```
church-dwight-brand-control-tower/
├── config.json         # Full demo configuration (brands, alerts, theme, etc.)
├── app/                # Flutter web frontend
│   ├── lib/
│   │   ├── models/     # Brand, Alert, Scenario data models
│   │   ├── providers/  # Riverpod state management
│   │   ├── screens/    # Portfolio, Brand Detail, Scenario Planner, Chat
│   │   ├── services/   # API service (Dio HTTP client)
│   │   ├── theme/      # CHD corporate blue (#003DA5) theme
│   │   └── widgets/    # Charts, cards, animations
│   └── pubspec.yaml
├── deploy/             # Databricks Apps deployment bundle
│   ├── app.py          # FastAPI entry point
│   ├── app.yaml        # SET YOUR ENV VARS HERE
│   ├── requirements.txt
│   ├── routes/         # API routes (brands, alerts, chat, scenario)
│   └── services/       # Databricks SDK, MAS, MMM clients
├── backend/            # FastAPI backend (same as deploy, for local dev)
└── scripts/            # Data generation & ML training
    ├── generate_act1_data.py       # Bronze tables
    ├── generate_act2_data.py       # Bronze tables
    ├── generate_complaint_pdfs.py  # PDF complaints for Knowledge Agent
    ├── train_mmm_model.py          # Marketing Mix Model
    └── deploy_mmm_endpoint.py      # Model serving endpoint
```

## Multi-Agent Supervisor (MAS)

The chat interface is powered by a **Multi-Agent Supervisor** — an orchestration layer that routes user questions to specialized sub-agents and synthesizes their responses.

```
                         ┌──────────────────────────┐
                         │   Multi-Agent Supervisor  │
                         │  (CHD_Brand_Control_Tower) │
                         │                          │
                         │  Routes questions to the  │
                         │  right specialist agent   │
                         └─────────┬────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
         ┌──────────▼──────────┐      ┌───────────▼──────────┐
         │ Brand Intelligence  │      │ Complaint Document   │
         │     Analyst         │      │     Analyst          │
         │                     │      │                      │
         │  AI/BI Genie Space  │      │  Knowledge Agent     │
         │  (structured data)  │      │  (unstructured docs) │
         └──────────┬──────────┘      └───────────┬──────────┘
                    │                             │
         ┌──────────▼──────────┐      ┌───────────▼──────────┐
         │  8 Unity Catalog    │      │  ~50 PDF complaint   │
         │  tables (see Data   │      │  docs in UC Volume   │
         │  Model below)       │      │  /Volumes/.../       │
         │                     │      │  complaint_docs      │
         └─────────────────────┘      └──────────────────────┘
```

### How it works

1. **User asks a question** via the chat drawer in the Flutter app (e.g., "What's happening with ARM & HAMMER?" or "Show me complaint trends for cat litter")

2. **The MAS supervisor** analyzes the question and decides which agent to invoke:
   - **Brand Intelligence Analyst** (Genie Space) — for data questions about health scores, ROAS, spend, revenue, social engagement, or any metric that lives in structured tables
   - **Complaint Document Analyst** (Knowledge Agent) — for questions about quality issues, retailer feedback, consumer complaints, or anything requiring analysis of unstructured PDF documents

3. **The sub-agent executes** — the Genie Space writes and runs SQL against Unity Catalog tables; the Knowledge Agent searches and summarizes complaint PDFs using vector search

4. **The MAS synthesizes** — the supervisor takes the sub-agent's raw output and produces a coherent, contextual response for the user

### Agent Bricks components

| Component | Type | What it does |
|-----------|------|-------------|
| **CHD_Brand_Control_Tower** | Multi-Agent Supervisor | Orchestrates routing between sub-agents, synthesizes final answers |
| **Brand Intelligence Analyst** | AI/BI Genie Space | Natural language to SQL over 8 Unity Catalog tables |
| **Complaint Document Analyst** | Knowledge Agent | Retrieval-augmented generation over ~50 complaint PDFs in a UC Volume |
| **Marketing Mix Model** | Model Serving Endpoint | Ridge regression model for scenario planning (channel spend to revenue) |

### Genie Space configuration

The Genie Space ("CHD Brand Intelligence") is connected to a SQL Warehouse and linked to 8 Unity Catalog tables. When a user asks a data question, the Genie Space automatically translates natural language into SQL, executes it against these tables, and returns the results.

Tables linked to the Genie Space:

| Table | Why it's included |
|-------|------------------|
| `brands` | Brand lookup — maps brand IDs to names, categories, and revenue |
| `products` | Product catalog — enables drill-down from brand to individual SKUs |
| `brand_health_daily` | Core health metric — daily health scores, sentiment splits, review counts per brand |
| `channel_performance_weekly` | Marketing efficiency — weekly ROAS, spend, revenue, impressions, clicks per channel per brand |
| `social_engagement_daily` | Social monitoring — daily engagement volume and post counts by platform per brand |
| `marketing_spend` | Raw spend data — campaign-level spend with impressions and clicks by channel |
| `sales_pos` | Point-of-sale — unit sales, revenue, and promotion flags by product/retailer/region |
| `reviews_silver` | Enriched reviews — individual reviews joined with brand names and retailer names for text analysis |

The Genie Space does NOT include `social_posts_raw`, `reviews_raw`, or `promotions` — these are used during data generation but are either too granular or already aggregated into the Gold tables above.

## Data Model

All data is synthetic, generated by the scripts in `scripts/`. The tables follow a Bronze-Silver-Gold medallion architecture within a single Unity Catalog schema.

### Bronze tables (generated by scripts)

**`brands`** — 5 rows

| Column | Type | Description |
|--------|------|-------------|
| brand_id | bigint | Primary key (1-5) |
| brand_name | string | Display name (e.g. "ARM & HAMMER") |
| category | string | Product category |
| annual_revenue_mm | double | Annual revenue in millions |
| flagship_product | string | Best-known product |

**`products`** — 47 rows

| Column | Type | Description |
|--------|------|-------------|
| product_id | bigint | Primary key |
| brand_id | bigint | FK to brands |
| product_name | string | Product display name |
| sub_category | string | Sub-category within brand |
| avg_price | double | Average retail price |
| upc | string | Simulated UPC code |

**`retailers`** — 5 rows

| Column | Type | Description |
|--------|------|-------------|
| retailer_id | bigint | Primary key (1-5) |
| retailer_name | string | Walmart, Amazon, Target, Kroger, Costco |
| channel_type | string | Mass, E-commerce, Grocery, Club |
| has_retail_media | boolean | Whether retailer has a media network |
| retail_media_name | string | Name of the media network |

**`reviews_raw`** — 50,000 rows

| Column | Type | Description |
|--------|------|-------------|
| review_id | string | UUID |
| product_id | bigint | FK to products |
| retailer_id | bigint | FK to retailers |
| rating | bigint | 1-5 star rating |
| review_title | string | Review headline |
| review_text | string | Full review body |
| reviewer_name | string | Synthetic reviewer name |
| review_date | date | Date of review |
| verified_purchase | boolean | Verified purchase flag |
| helpful_votes | bigint | Helpful vote count |

**`social_posts_raw`** — 20,000 rows

| Column | Type | Description |
|--------|------|-------------|
| post_id | string | UUID |
| brand_id | bigint | FK to brands |
| platform | string | TikTok, Instagram, YouTube, Twitter, Reddit |
| post_text | string | Post content |
| author_handle | string | Synthetic social handle |
| author_type | string | consumer, influencer, brand |
| engagement_count | bigint | Likes + shares + comments |
| post_date | date | Date of post |
| url | string | Simulated post URL |

**`marketing_spend`** — 5,000 rows

| Column | Type | Description |
|--------|------|-------------|
| spend_id | int | Primary key |
| brand_id | int | FK to brands |
| channel | string | Paid Search, Social Media, Linear TV, etc. |
| spend_amount | double | Weekly spend in USD |
| impressions | bigint | Ad impressions |
| clicks | bigint | Ad clicks |
| week_start_date | timestamp | Start of reporting week |
| campaign_name | string | Campaign identifier |

**`sales_pos`** — 100,000 rows

| Column | Type | Description |
|--------|------|-------------|
| sale_id | int | Primary key |
| product_id | int | FK to products |
| retailer_id | int | FK to retailers |
| region | string | Geographic region |
| units_sold | int | Units sold |
| revenue | double | Revenue in USD |
| week_start_date | timestamp | Start of reporting week |
| is_promoted | boolean | Whether sale was during a promotion |

**`promotions`** — 500 rows

| Column | Type | Description |
|--------|------|-------------|
| promo_id | int | Primary key |
| brand_id | int | FK to brands |
| retailer_id | int | FK to retailers |
| promo_type | string | BOGO, Discount, Display, Coupon |
| start_date | date | Promotion start |
| end_date | date | Promotion end |
| discount_pct | double | Discount percentage |

### Silver tables (created via SQL joins)

**`reviews_silver`** — 50,000 rows
Enriched version of `reviews_raw` joined with `products`, `brands`, and `retailers`. Adds `brand_id`, `brand_name`, and `retailer_name` columns to every review for easier querying.

**`social_posts_silver`** — 20,000 rows
Enriched version of `social_posts_raw` joined with `brands`. Adds `brand_name` column.

### Gold tables (created via SQL aggregations)

**`brand_health_daily`** — ~1,400 rows

| Column | Type | Description |
|--------|------|-------------|
| brand_id | bigint | FK to brands |
| brand_name | string | Brand display name |
| review_date | date | Date |
| health_score | double | 0-100 score derived from avg rating |
| positive_pct | double | % of reviews rated 4-5 stars |
| negative_pct | double | % of reviews rated 1-2 stars |
| review_count | double | Number of reviews that day |

**`channel_performance_weekly`** — ~varies

| Column | Type | Description |
|--------|------|-------------|
| brand_name | string | Brand display name |
| channel | string | Marketing channel |
| week_start_date | timestamp | Start of reporting week |
| spend_amount | double | Total spend |
| total_revenue | double | Total attributed revenue |
| roas | double | Return on ad spend (revenue/spend) |
| impressions | bigint | Total impressions |
| clicks | bigint | Total clicks |

**`social_engagement_daily`** — ~5,000 rows

| Column | Type | Description |
|--------|------|-------------|
| brand_name | string | Brand display name |
| platform | string | Social platform |
| post_date | date | Date |
| total_engagement | bigint | Sum of engagement counts |
| avg_engagement | double | Average engagement per post |
| post_count | bigint | Number of posts |

---

## Demo Brands

| # | Brand | Category | Status | Health Score |
|---|-------|----------|--------|-------------|
| 1 | ARM & HAMMER | Household / Multi-Category | CRITICAL | 64 |
| 2 | OxiClean | Household / Stain Removal | WARNING | 76 |
| 3 | TheraBreath | Oral Care | HEALTHY | 82 |
| 4 | Batiste | Personal Care / Beauty | HEALTHY | 86 |
| 5 | HERO Cosmetics | Skincare / Acne Care | OPPORTUNITY | 90 |

## Alert Narratives

1. **CRITICAL -- Cat Litter Reformulation Complaints Surge**: ARM & HAMMER DUAL DEFENSE Cat Litter with Microban generating negative reviews about chemical smell and clumping failure.
2. **WARNING -- Linear TV Over-Indexed vs. Retail Media**: OxiClean over-spending on Linear TV while Retail Media delivers 4.2x ROAS.
3. **OPPORTUNITY -- TikTok Cleanser Launch Amplification**: HERO Cosmetics TikTok engagement up 270% ahead of 3-SKU cleanser launch.

---

## Setup

### Prerequisites

- Databricks workspace with Unity Catalog enabled
- Databricks CLI configured with a profile (`databricks auth login`)
- SQL Warehouse (Serverless recommended)
- Python 3.11+, Flutter SDK, `uv` package manager

### 1. Set environment variables

All scripts and services read configuration from environment variables. Set these before running anything:

```bash
# Required — your Databricks workspace
export DATABRICKS_PROFILE="<your-cli-profile>"       # e.g. "my-workspace"
export DATABRICKS_HOST="https://<workspace>.cloud.databricks.com"
export DATABRICKS_CATALOG="<your-catalog>"            # e.g. "main"
export DATABRICKS_SCHEMA="chd_demo"                   # default, change if needed
export DATABRICKS_WAREHOUSE_ID="<your-warehouse-id>"  # SQL Warehouse ID
export DATABRICKS_USER="<your-email>"                 # e.g. "jane@company.com"

# Set after provisioning Agent Bricks (Step 5)
export DATABRICKS_MAS_ENDPOINT="<your-mas-endpoint>"  # e.g. "mas-abc12345-endpoint"
export DATABRICKS_MMM_ENDPOINT="chd-marketing-mix-model"  # or your custom name
```

### 2. Create schema and volume

```bash
databricks sql execute --statement "CREATE SCHEMA IF NOT EXISTS ${DATABRICKS_CATALOG}.${DATABRICKS_SCHEMA}" \
  --warehouse-id $DATABRICKS_WAREHOUSE_ID --profile $DATABRICKS_PROFILE --wait

databricks sql execute --statement "CREATE VOLUME IF NOT EXISTS ${DATABRICKS_CATALOG}.${DATABRICKS_SCHEMA}.complaint_docs" \
  --warehouse-id $DATABRICKS_WAREHOUSE_ID --profile $DATABRICKS_PROFILE --wait
```

### 3. Generate synthetic data

Install dependencies:
```bash
pip install mimesis fpdf2 polars databricks-connect==18.0.* 'numpy<2'
```

Run data generation scripts in order:
```bash
python scripts/generate_act1_data.py        # Bronze: brands, products, retailers, reviews, social posts
python scripts/generate_act2_data.py        # Bronze: marketing_spend, sales_pos, promotions
python scripts/generate_complaint_pdfs.py   # PDF complaints -> UC Volume
```

Then create Silver and Gold tables. See the SQL definitions in `scripts/create_silver_gold_tables.sql` or refer to the **Data Model** section above for column schemas. The Silver tables are joins of Bronze tables; the Gold tables are daily/weekly aggregations.

### 4. Train the Marketing Mix Model

```bash
databricks workspace mkdirs "/Users/${DATABRICKS_USER}/${DATABRICKS_SCHEMA}" --profile $DATABRICKS_PROFILE
python scripts/train_mmm_model.py
python scripts/deploy_mmm_endpoint.py
```

### 5. Provision Agent Bricks

Install the Agent Bricks SDK:
```bash
pip install git+https://github.com/databricks-solutions/ai-dev-kit.git#subdirectory=databricks-tools-core
```

```python
from databricks.sdk import WorkspaceClient
from databricks_tools_core.agent_bricks.manager import AgentBricksManager

w = WorkspaceClient(profile="<YOUR_PROFILE>")
manager = AgentBricksManager(w)

# Genie Space — linked to 8 tables (see Genie Space Configuration above)
genie = manager.genie_create(
    display_name="CHD Brand Intelligence",
    warehouse_id="<YOUR_WAREHOUSE_ID>",
    table_identifiers=[
        "<catalog>.<schema>.brands",
        "<catalog>.<schema>.products",
        "<catalog>.<schema>.brand_health_daily",
        "<catalog>.<schema>.channel_performance_weekly",
        "<catalog>.<schema>.social_engagement_daily",
        "<catalog>.<schema>.marketing_spend",
        "<catalog>.<schema>.sales_pos",
        "<catalog>.<schema>.reviews_silver",
    ],
)

# Knowledge Agent — reads PDFs from the UC Volume
ka = manager.ka_create(
    name="CHD Complaint Docs",
    knowledge_sources=[{
        "files_source": {
            "name": "complaint_docs",
            "type": "files",
            "files": {"path": "/Volumes/<catalog>/<schema>/complaint_docs"}
        }
    }],
    description="Retailer complaint documents for Church & Dwight brands",
)

# Multi-Agent Supervisor — wires the two agents together
mas = manager.mas_create(
    name="CHD_Brand_Control_Tower",
    description="Multi-agent supervisor for Church & Dwight brand marketing intelligence",
    instructions="Route brand health, sentiment, and channel performance questions to Brand_Intelligence_Analyst. Route complaint analysis to Complaint_Document_Analyst.",
    agents=[
        {"name": "Brand_Intelligence_Analyst", "description": "Brand health, spend, and sales data.",
         "agent_type": "genie-space", "genie_space": {"id": "<GENIE_SPACE_ID>"}},
        {"name": "Complaint_Document_Analyst", "description": "Complaint document analysis.",
         "agent_type": "serving-endpoint", "serving_endpoint": {"name": "<KA_ENDPOINT_NAME>"}},
    ],
)
```

After provisioning, set the endpoint env vars:
```bash
export DATABRICKS_MAS_ENDPOINT="mas-XXXXXXXX-endpoint"  # from MAS output
```

### 6. Deploy to Databricks Apps

Update `deploy/app.yaml` with your resource IDs, then:

```bash
# Build Flutter frontend
cd app && flutter build web && cd ..
mkdir -p deploy/static && cp -R app/build/web/* deploy/static/

# Create and deploy
databricks apps create chd-brand-control-tower --description "Church & Dwight Brand Control Tower" --profile $DATABRICKS_PROFILE
cd deploy
databricks workspace import-dir . "/Users/${DATABRICKS_USER}/chd-brand-control-tower" --overwrite --profile $DATABRICKS_PROFILE
databricks apps deploy chd-brand-control-tower \
  --source-code-path "/Workspace/Users/${DATABRICKS_USER}/chd-brand-control-tower" \
  --profile $DATABRICKS_PROFILE
```

Grant the app's service principal access (find the SP application ID in the app details):
```sql
GRANT USE CATALOG ON CATALOG <catalog> TO `<service-principal-application-id>`;
GRANT USE SCHEMA ON SCHEMA <catalog>.<schema> TO `<service-principal-application-id>`;
GRANT SELECT ON SCHEMA <catalog>.<schema> TO `<service-principal-application-id>`;
```

Declare serving endpoint resources:
```bash
databricks api patch /api/2.0/apps/chd-brand-control-tower --profile $DATABRICKS_PROFILE --json '{
  "resources": [
    {"name": "sql_warehouse", "sql_warehouse": {"id": "<WAREHOUSE_ID>", "permission": "CAN_USE"}},
    {"name": "mas_endpoint", "serving_endpoint": {"name": "<MAS_ENDPOINT>", "permission": "CAN_QUERY"}},
    {"name": "mmm_endpoint", "serving_endpoint": {"name": "<MMM_ENDPOINT>", "permission": "CAN_QUERY"}}
  ]
}'
```

### Local testing

```bash
cd deploy
DATABRICKS_PROFILE=<profile> DATABRICKS_WAREHOUSE_ID=<id> DATABRICKS_CATALOG=<catalog> \
  DATABRICKS_SCHEMA=chd_demo DATABRICKS_MAS_ENDPOINT=<mas> DATABRICKS_MMM_ENDPOINT=<mmm> \
  uvicorn app:app --port 8001
```

---

## Environment Variables Reference

| Variable | Required | Used By | Description |
|----------|----------|---------|-------------|
| `DATABRICKS_PROFILE` | Scripts | scripts/ | Databricks CLI profile name |
| `DATABRICKS_HOST` | Scripts | scripts/ | Workspace URL |
| `DATABRICKS_CATALOG` | All | scripts/, deploy/, backend/ | Unity Catalog catalog name |
| `DATABRICKS_SCHEMA` | All | scripts/, deploy/, backend/ | Schema name (default: `chd_demo`) |
| `DATABRICKS_WAREHOUSE_ID` | All | scripts/, deploy/, backend/ | SQL Warehouse ID |
| `DATABRICKS_USER` | Scripts | scripts/ | Your email for MLflow experiment path |
| `DATABRICKS_MAS_ENDPOINT` | App | deploy/, backend/ | Multi-Agent Supervisor endpoint name |
| `DATABRICKS_MMM_ENDPOINT` | App | deploy/, backend/ | Marketing Mix Model endpoint name |
| `DATABRICKS_EXPERIMENT_PATH` | Optional | scripts/ | Custom MLflow experiment path |
