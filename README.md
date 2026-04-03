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

## Multi-Agent Supervisor (MAS) Architecture

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
         │  8 Unity Catalog    │      │  PDF complaint docs  │
         │  tables:            │      │  in UC Volume:       │
         │  - brand_health     │      │  - Retailer feedback │
         │  - channel_perf     │      │  - Quality reports   │
         │  - social_engage    │      │  - Consumer complaints│
         │  - marketing_spend  │      │                      │
         │  - sales_pos        │      │                      │
         │  - brands/products  │      │                      │
         │  - reviews_silver   │      │                      │
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
| **Brand Intelligence Analyst** | AI/BI Genie Space | Natural language to SQL over 8 Unity Catalog tables (brand health, channel performance, social engagement, spend, sales) |
| **Complaint Document Analyst** | Knowledge Agent | Retrieval-augmented generation over ~50 complaint PDFs stored in a UC Volume |
| **Marketing Mix Model** | Model Serving Endpoint | Ridge regression model for scenario planning (channel spend to revenue prediction) |

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

Then create the Silver and Gold tables via SQL:
```sql
-- Silver: reviews_silver
CREATE OR REPLACE TABLE <catalog>.<schema>.reviews_silver AS
SELECT r.*, p.brand_id, b.brand_name, ret.retailer_name
FROM reviews_raw r
JOIN products p ON r.product_id = p.product_id
JOIN brands b ON p.brand_id = b.brand_id
JOIN retailers ret ON r.retailer_id = ret.retailer_id;

-- Silver: social_posts_silver
CREATE OR REPLACE TABLE <catalog>.<schema>.social_posts_silver AS
SELECT s.*, b.brand_name
FROM social_posts_raw s JOIN brands b ON s.brand_id = b.brand_id;

-- Gold: brand_health_daily
CREATE OR REPLACE TABLE <catalog>.<schema>.brand_health_daily AS
SELECT p.brand_id, b.brand_name, date_trunc('day', r.review_date) AS review_date,
       ROUND(AVG(r.rating)/5.0*100,1) AS health_score,
       ROUND(SUM(CASE WHEN r.rating>=4 THEN 1 ELSE 0 END)*100.0/COUNT(*),1) AS positive_pct,
       ROUND(SUM(CASE WHEN r.rating<=2 THEN 1 ELSE 0 END)*100.0/COUNT(*),1) AS negative_pct,
       CAST(COUNT(*) AS DOUBLE) AS review_count
FROM reviews_raw r JOIN products p ON r.product_id=p.product_id JOIN brands b ON p.brand_id=b.brand_id
GROUP BY p.brand_id, b.brand_name, date_trunc('day', r.review_date);

-- Gold: channel_performance_weekly
CREATE OR REPLACE TABLE <catalog>.<schema>.channel_performance_weekly AS
SELECT b.brand_name, ms.channel, ms.week_start_date,
       SUM(ms.spend_amount) AS spend_amount, SUM(sp.revenue) AS total_revenue,
       CASE WHEN SUM(ms.spend_amount)>0 THEN ROUND(SUM(sp.revenue)/SUM(ms.spend_amount),2) ELSE 0 END AS roas,
       SUM(ms.impressions) AS impressions, SUM(ms.clicks) AS clicks
FROM marketing_spend ms JOIN brands b ON ms.brand_id=b.brand_id
LEFT JOIN (SELECT p.brand_id, s.week_start_date, SUM(s.revenue) AS revenue
           FROM sales_pos s JOIN products p ON s.product_id=p.product_id GROUP BY 1,2) sp
ON ms.brand_id=sp.brand_id AND ms.week_start_date=sp.week_start_date
GROUP BY b.brand_name, ms.channel, ms.week_start_date;

-- Gold: social_engagement_daily
CREATE OR REPLACE TABLE <catalog>.<schema>.social_engagement_daily AS
SELECT brand_name, platform, date_trunc('day', post_date) AS post_date,
       SUM(engagement_count) AS total_engagement, ROUND(AVG(engagement_count),1) AS avg_engagement,
       COUNT(*) AS post_count
FROM social_posts_silver GROUP BY 1,2,3;
```

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

# Genie Space
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

# Knowledge Agent
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

# Multi-Agent Supervisor
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
