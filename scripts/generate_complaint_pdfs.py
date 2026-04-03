"""
Generate ~50 synthetic retailer complaint/feedback PDFs for Church & Dwight Co., Inc. CPG demo.
Uploads them to a Databricks Unity Catalog Volume.

Run with:
  uv run --with fpdf2 scripts/generate_complaint_pdfs.py
"""

import subprocess
import json
import random
import os
from datetime import datetime, timedelta
from fpdf import FPDF

random.seed(42)

# --- Configuration (set via environment variables) ---
PROFILE = os.environ.get("DATABRICKS_PROFILE", "DEFAULT")
CATALOG = os.environ["DATABRICKS_CATALOG"]
SCHEMA = os.environ.get("DATABRICKS_SCHEMA", "chd_demo")
VOLUME = "complaint_docs"
WAREHOUSE_ID = os.environ["DATABRICKS_WAREHOUSE_ID"]
OUTPUT_DIR = "output/complaint_pdfs"
UC_VOLUME_PATH = f"dbfs:/Volumes/{CATALOG}/{SCHEMA}/{VOLUME}"

RETAILERS = [
    "Walmart",
    "Amazon",
    "Target",
    "Kroger",
    "Costco",
]


BRAND_PRODUCTS = {
    "ARM & HAMMER": [
        "Clean Burst Laundry Detergent",
        "Plus OxiClean Laundry Detergent",
        "Baking Soda Fresh Laundry Detergent",
        "Clump & Seal Cat Litter",
        "DUAL DEFENSE Cat Litter with Microban",
    ],
    "OxiClean": [
        "Versatile Stain Remover Powder",
        "White Revive Laundry Whitener",
        "Max Force Gel Stick",
        "Dark Protect Laundry Booster",
        "Odor Blasters Stain & Odor Remover",
    ],
    "TheraBreath": [
        "Fresh Breath Oral Rinse",
        "Healthy Gums Oral Rinse",
        "Whitening Fresh Breath Toothpaste",
        "Healthy Smile Anticavity Toothpaste",
        "Anti-Cavity Fluoride Toothpaste",
    ],
    "Batiste": [
        "Original Dry Shampoo",
        "Bare Dry Shampoo",
        "Light Dry Shampoo",
        "Brunette Tinted Dry Shampoo",
        "Divine Dark Dry Shampoo",
    ],
    "HERO Cosmetics": [
        "Mighty Patch Original",
        "Mighty Patch Invisible+",
        "Mighty Patch Surface",
        "Mighty Patch Micropoint for Blemishes",
        "Lightning Wand Dark Spot Serum",
    ],
}

COMPLAINT_TYPES = ["packaging", "quality", "labeling", "safety", "expiration"]
SEVERITIES = ["Low", "Medium", "High", "Critical"]

# --- Narrative-specific templates ---

# Crisis brand (ARM & HAMMER) complaint descriptions
CRISIS_BRAND_DESCRIPTIONS = [
    "During routine receiving inspection at our distribution center, {count} units of {product} were found with visibly leaking bottles. The liquid had seeped through the corrugated shipping cases, causing damage to adjacent inventory. Our quality assurance team documented the issue with photographs and has quarantined the affected lot. The leak appears to originate from a faulty seal around the bottle cap. We are requesting an immediate investigation into the packaging line responsible for this batch.",
    "Multiple customer returns have been processed at {store_count} store locations due to broken caps on {product}. Customers reported that the caps cracked during normal handling and the product spilled inside shopping bags. Several customers have filed formal complaints through our customer service portal. This is causing significant brand perception issues at point of sale. We recommend a root-cause analysis of the cap molding process.",
    "Our warehouse team identified severe packaging damage on a recent shipment of {product}. Approximately {count} cases arrived with crushed outer packaging and compromised inner seals. The affected units cannot be placed on shelves in their current condition. This is the third such incident in the past 30 days, suggesting a systemic issue with either the packaging materials or the fulfillment process. Immediate corrective action is required.",
    "We have received an unusually high number of customer complaints regarding {product} bottles leaking on store shelves. Store associates have reported finding sticky residue in the aisle at {store_count} locations. The leakage has resulted in product markdowns and additional labor costs for cleanup. Our merchandising team estimates the direct financial impact at over ${cost} across affected stores. A formal quality hold has been placed on remaining inventory.",
    "During our quarterly product quality audit, {product} was flagged for packaging defects. The audit revealed that {count} percent of sampled units had compromised tamper-evident seals. Several bottles showed signs of overfilling, which appears to be causing pressure-related cap failures during transit. This finding has been escalated to our vendor compliance team. We are requesting a detailed corrective action plan within 10 business days.",
    "Customer feedback collected through our online marketplace indicates a spike in packaging-related complaints for {product}. Reviews mention bottles arriving damaged, caps that do not close properly, and product leaking during shipping. The negative review rate has increased by {count} percent month-over-month. This trend is impacting the product's search ranking and overall category performance. We urge immediate attention to packaging integrity for e-commerce fulfillment.",
]

# OxiClean complaint descriptions
BRAND_2_DESCRIPTIONS = [
    "We have received {count} customer complaints at {store_count} store locations regarding {product}. Customers report issues with the product not meeting expectations. Our category management team is evaluating the situation. We recommend improved product guidelines or enhanced packaging instructions.",
    "Multiple stores have reported customer complaints about {product}. Our customer service team has processed {count} returns related to this issue in the past 60 days. The complaints span across {store_count} store locations. We are requesting a technical bulletin addressing product quality.",
    "Our store teams have documented issues with {product} packaging during shelf stocking. Cleanup costs and product shrinkage from this issue are estimated at ${cost} per affected store per month. We have taken temporary measures to mitigate the risk.",
]
# TheraBreath complaint descriptions
BRAND_3_DESCRIPTIONS = [
    "We have received {count} customer complaints at {store_count} store locations regarding {product}. Customers report issues with the product not meeting expectations. Our category management team is evaluating the situation. We recommend improved product guidelines or enhanced packaging instructions.",
    "Multiple stores have reported customer complaints about {product}. Our customer service team has processed {count} returns related to this issue in the past 60 days. The complaints span across {store_count} store locations. We are requesting a technical bulletin addressing product quality.",
    "Our store teams have documented issues with {product} packaging during shelf stocking. Cleanup costs and product shrinkage from this issue are estimated at ${cost} per affected store per month. We have taken temporary measures to mitigate the risk.",
]
# Batiste complaint descriptions
BRAND_4_DESCRIPTIONS = [
    "We have received {count} customer complaints at {store_count} store locations regarding {product}. Customers report issues with the product not meeting expectations. Our category management team is evaluating the situation. We recommend improved product guidelines or enhanced packaging instructions.",
    "Multiple stores have reported customer complaints about {product}. Our customer service team has processed {count} returns related to this issue in the past 60 days. The complaints span across {store_count} store locations. We are requesting a technical bulletin addressing product quality.",
    "Our store teams have documented issues with {product} packaging during shelf stocking. Cleanup costs and product shrinkage from this issue are estimated at ${cost} per affected store per month. We have taken temporary measures to mitigate the risk.",
]

# Opportunity brand (HERO Cosmetics) positive descriptions
OPPORTUNITY_BRAND_DESCRIPTIONS = [
    "{product} continues to perform exceptionally well across our {store_count} store locations. Customer satisfaction scores for this SKU remain in the top quartile of the category. The product's value proposition and ease of use are frequently cited in positive customer reviews. Our category analysis shows a {count} percent year-over-year sales increase. We recommend expanding facings and considering additional promotional support.",
    "Our quarterly brand performance review indicates strong positive customer sentiment for {product}. The product maintains a 4.6 out of 5 star average across {count} verified customer reviews. Common praise points include quality, effectiveness, and ease of use. Store-level data shows consistent sell-through rates above category average. This product is a strong candidate for endcap placement during the upcoming promotional cycle.",
    "Customer feedback surveys conducted at {store_count} locations show {product} as a preferred brand among target respondents. The product's packaging is noted as visually appealing and easy to use. Zero quality complaints have been filed in the current reporting period. Our category team recommends maintaining current inventory levels and exploring cross-merchandising opportunities.",
]

MIXED_COMPLAINT_DESCRIPTIONS = [
    "We have received {count} customer inquiries regarding {product} over the past reporting period. Concerns include minor packaging scuffs during shipping and questions about product specifications. While no safety issues have been identified, the volume of inquiries suggests an opportunity to improve product labeling and instructional materials. Our vendor relations team recommends a collaborative review of packaging design.",
    "A quality check at {store_count} store locations identified inconsistencies in {product} labeling. Specifically, some units display outdated promotional pricing or incorrect UPC placement. While the product itself meets quality standards, the labeling discrepancies are causing register scanning issues and customer confusion. We request updated packaging artwork be implemented in the next production run.",
    "Customer returns for {product} have been slightly above category average this quarter. The primary reasons cited include product not meeting expectations based on packaging claims, and minor cosmetic damage to packaging. Our analysis indicates these returns are within acceptable tolerance but trending upward. We recommend a product-packaging alignment review to ensure marketing claims match the consumer experience.",
]


def random_date(start_str, end_str):
    start = datetime.strptime(start_str, "%Y-%m-%d")
    end = datetime.strptime(end_str, "%Y-%m-%d")
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))


def generate_pdf(doc, filepath):
    """Generate a single complaint/feedback PDF."""
    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=20)

    # Header bar
    pdf.set_fill_color(0, 51, 102)
    pdf.rect(0, 0, 210, 30, "F")
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Helvetica", "B", 18)
    pdf.set_y(8)
    pdf.cell(0, 12, doc["retailer"].upper(), align="L", new_x="LMARGIN", new_y="NEXT")

    # Document title
    pdf.set_fill_color(220, 230, 241)
    pdf.rect(0, 30, 210, 14, "F")
    pdf.set_text_color(0, 51, 102)
    pdf.set_font("Helvetica", "B", 13)
    pdf.set_y(33)
    pdf.cell(0, 8, doc["title"], align="C", new_x="LMARGIN", new_y="NEXT")

    pdf.set_y(50)
    pdf.set_text_color(0, 0, 0)

    # Reference and date line
    pdf.set_font("Helvetica", "", 9)
    pdf.cell(0, 6, f"Document ID: {doc['doc_id']}    |    Date: {doc['date_str']}    |    Confidential", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(4)

    # Separator
    pdf.set_draw_color(0, 51, 102)
    pdf.set_line_width(0.5)
    pdf.line(10, pdf.get_y(), 200, pdf.get_y())
    pdf.ln(6)

    # Info table
    fields = [
        ("Brand", doc["brand"]),
        ("Product", doc["product"]),
        ("Report Type", doc["complaint_type"].title()),
        ("Severity", doc["severity"]),
        ("Store Locations Affected", ", ".join(doc["stores"])),
        ("Customer Complaints Received", str(doc["complaint_count"])),
    ]

    for label, value in fields:
        pdf.set_font("Helvetica", "B", 10)
        pdf.cell(60, 7, label + ":", new_x="END")
        pdf.set_font("Helvetica", "", 10)
        pdf.cell(0, 7, value, new_x="LMARGIN", new_y="NEXT")

    pdf.ln(4)
    pdf.set_draw_color(180, 180, 180)
    pdf.set_line_width(0.3)
    pdf.line(10, pdf.get_y(), 200, pdf.get_y())
    pdf.ln(6)

    # Description section
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 7, "Issue Description", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, doc["description"])
    pdf.ln(4)

    # Recommended action
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 7, "Recommended Action", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, doc["action"])
    pdf.ln(6)

    # Footer separator
    pdf.set_draw_color(0, 51, 102)
    pdf.set_line_width(0.5)
    pdf.line(10, pdf.get_y(), 200, pdf.get_y())
    pdf.ln(4)
    pdf.set_font("Helvetica", "I", 8)
    pdf.set_text_color(100, 100, 100)
    pdf.cell(0, 5, f"This document is the property of {doc['retailer']} and is intended for internal use only.", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 5, f"Prepared by {doc['retailer']} Vendor Quality Management  |  {doc['date_str']}", align="C", new_x="LMARGIN", new_y="NEXT")

    pdf.output(filepath)


def make_stores(retailer, count):
    prefixes = {
        "Walmart": "WAL",
        "Amazon": "AMA",
        "Target": "TAR",
        "Kroger": "KRO",
        "Costco": "COS",
    }
    prefix = prefixes.get(retailer, "STR")
    return [f"{prefix}-{random.randint(1000, 9999)}" for _ in range(count)]


def build_documents():
    docs = []
    seq = 1

    # --- 20 ARM & HAMMER packaging issues (Alert 1 driver) ---
    for i in range(20):
        retailer = random.choice([
            "Walmart",
            "Amazon",
            "Target",
        ])
        product = random.choice(BRAND_PRODUCTS["ARM & HAMMER"])
        dt = random_date("2026-02-15", "2026-03-10")
        severity = random.choice(["High", "Critical"])
        store_count = random.randint(2, 5)
        stores = make_stores(retailer, store_count)
        complaint_count = random.randint(15, 120)
        template = random.choice(CRISIS_BRAND_DESCRIPTIONS)
        description = template.format(
            product=product,
            count=random.randint(10, 60),
            store_count=store_count,
            cost=random.randint(800, 5000),
        )
        action_options = [
            f"Initiate immediate hold on all {product} inventory pending quality investigation. Coordinate with Church & Dwight Co., Inc. packaging engineering team for root-cause analysis. Provide corrective action plan within 5 business days.",
            f"Escalate to Church & Dwight Co., Inc. quality assurance leadership. Request on-site packaging line audit at manufacturing facility. Issue interim credit for damaged inventory totaling {complaint_count} affected units.",
            f"Place quality hold on incoming shipments of {product}. Require enhanced packaging inspection protocol for next 3 shipments. Schedule joint quality review meeting with Church & Dwight Co., Inc. supply chain team.",
        ]
        doc_id = f"QR-{dt.strftime('%Y%m%d')}-{seq:04d}"
        brand_slug = "arm_and_hammer"
        filename = f"{retailer.lower()}_{ brand_slug }_packaging_{dt.strftime('%Y%m%d')}_{seq:03d}.pdf"
        docs.append({
            "retailer": retailer,
            "brand": "ARM & HAMMER",
            "product": product,
            "complaint_type": "packaging",
            "severity": severity,
            "date": dt,
            "date_str": dt.strftime("%B %d, %Y"),
            "stores": stores,
            "complaint_count": complaint_count,
            "description": description,
            "action": random.choice(action_options),
            "title": random.choice(["Product Quality Report", "Customer Complaint Summary", "Vendor Quality Alert"]),
            "doc_id": doc_id,
            "filename": filename,
        })
        seq += 1

    # --- OxiClean complaints ---
    for i in range(10):
        retailer = random.choice(RETAILERS)
        product = random.choice(BRAND_PRODUCTS["OxiClean"])
        dt = random_date("2025-09-01", "2026-03-10")
        severity = random.choice(["Low", "Medium", "High"])
        store_count = random.randint(1, 4)
        stores = make_stores(retailer, store_count)
        complaint_count = random.randint(3, 40)
        complaint_type = random.choice(["quality", "packaging", "labeling"])
        template = random.choice(BRAND_2_DESCRIPTIONS)
        description = template.format(
            product=product,
            count=random.randint(5, 30),
            store_count=store_count,
            cost=random.randint(200, 1500),
        )
        action_options = [
            f"Request technical guidance from Church & Dwight Co., Inc. on recommended handling procedures for {product}. Update in-store signage to set appropriate customer expectations.",
            f"File vendor quality report with Church & Dwight Co., Inc. category management. Request product sample testing to verify formulation consistency across recent production lots.",
            f"Coordinate with Church & Dwight Co., Inc. on potential packaging improvements for {product}. Schedule quarterly business review to discuss quality trends and action plans.",
        ]
        doc_id = f"QR-{dt.strftime('%Y%m%d')}-{seq:04d}"
        brand_slug = "oxiclean"
        filename = f"{retailer.lower()}_{brand_slug}_{complaint_type}_{dt.strftime('%Y%m%d')}_{seq:03d}.pdf"
        docs.append({
            "retailer": retailer,
            "brand": "OxiClean",
            "product": product,
            "complaint_type": complaint_type,
            "severity": severity,
            "date": dt,
            "date_str": dt.strftime("%B %d, %Y"),
            "stores": stores,
            "complaint_count": complaint_count,
            "description": description,
            "action": random.choice(action_options),
            "title": random.choice(["Product Quality Report", "Customer Complaint Summary"]),
            "doc_id": doc_id,
            "filename": filename,
        })
        seq += 1

    # --- TheraBreath complaints ---
    for i in range(10):
        retailer = random.choice(RETAILERS)
        product = random.choice(BRAND_PRODUCTS["TheraBreath"])
        dt = random_date("2025-09-01", "2026-03-10")
        severity = random.choice(["Low", "Medium", "High"])
        store_count = random.randint(1, 4)
        stores = make_stores(retailer, store_count)
        complaint_count = random.randint(3, 40)
        complaint_type = random.choice(["quality", "packaging", "labeling"])
        template = random.choice(BRAND_3_DESCRIPTIONS)
        description = template.format(
            product=product,
            count=random.randint(5, 30),
            store_count=store_count,
            cost=random.randint(200, 1500),
        )
        action_options = [
            f"Request technical guidance from Church & Dwight Co., Inc. on recommended handling procedures for {product}. Update in-store signage to set appropriate customer expectations.",
            f"File vendor quality report with Church & Dwight Co., Inc. category management. Request product sample testing to verify formulation consistency across recent production lots.",
            f"Coordinate with Church & Dwight Co., Inc. on potential packaging improvements for {product}. Schedule quarterly business review to discuss quality trends and action plans.",
        ]
        doc_id = f"QR-{dt.strftime('%Y%m%d')}-{seq:04d}"
        brand_slug = "therabreath"
        filename = f"{retailer.lower()}_{brand_slug}_{complaint_type}_{dt.strftime('%Y%m%d')}_{seq:03d}.pdf"
        docs.append({
            "retailer": retailer,
            "brand": "TheraBreath",
            "product": product,
            "complaint_type": complaint_type,
            "severity": severity,
            "date": dt,
            "date_str": dt.strftime("%B %d, %Y"),
            "stores": stores,
            "complaint_count": complaint_count,
            "description": description,
            "action": random.choice(action_options),
            "title": random.choice(["Product Quality Report", "Customer Complaint Summary"]),
            "doc_id": doc_id,
            "filename": filename,
        })
        seq += 1

    # --- Batiste complaints ---
    for i in range(10):
        retailer = random.choice(RETAILERS)
        product = random.choice(BRAND_PRODUCTS["Batiste"])
        dt = random_date("2025-09-01", "2026-03-10")
        severity = random.choice(["Low", "Medium", "High"])
        store_count = random.randint(1, 4)
        stores = make_stores(retailer, store_count)
        complaint_count = random.randint(3, 40)
        complaint_type = random.choice(["quality", "packaging", "labeling"])
        template = random.choice(BRAND_4_DESCRIPTIONS)
        description = template.format(
            product=product,
            count=random.randint(5, 30),
            store_count=store_count,
            cost=random.randint(200, 1500),
        )
        action_options = [
            f"Request technical guidance from Church & Dwight Co., Inc. on recommended handling procedures for {product}. Update in-store signage to set appropriate customer expectations.",
            f"File vendor quality report with Church & Dwight Co., Inc. category management. Request product sample testing to verify formulation consistency across recent production lots.",
            f"Coordinate with Church & Dwight Co., Inc. on potential packaging improvements for {product}. Schedule quarterly business review to discuss quality trends and action plans.",
        ]
        doc_id = f"QR-{dt.strftime('%Y%m%d')}-{seq:04d}"
        brand_slug = "batiste"
        filename = f"{retailer.lower()}_{brand_slug}_{complaint_type}_{dt.strftime('%Y%m%d')}_{seq:03d}.pdf"
        docs.append({
            "retailer": retailer,
            "brand": "Batiste",
            "product": product,
            "complaint_type": complaint_type,
            "severity": severity,
            "date": dt,
            "date_str": dt.strftime("%B %d, %Y"),
            "stores": stores,
            "complaint_count": complaint_count,
            "description": description,
            "action": random.choice(action_options),
            "title": random.choice(["Product Quality Report", "Customer Complaint Summary"]),
            "doc_id": doc_id,
            "filename": filename,
        })
        seq += 1

    # --- HERO Cosmetics positive feedback ---
    for i in range(10):
        retailer = random.choice(RETAILERS)
        product = random.choice(BRAND_PRODUCTS["HERO Cosmetics"])
        dt = random_date("2025-09-01", "2026-03-10")
        severity = "Low"
        store_count = random.randint(3, 5)
        stores = make_stores(retailer, store_count)
        complaint_count = 0
        template = random.choice(OPPORTUNITY_BRAND_DESCRIPTIONS)
        description = template.format(
            product=product,
            count=random.randint(10, 35),
            store_count=store_count,
        )
        action_options = [
            f"Continue current promotional cadence for {product}. Evaluate opportunity for expanded distribution to additional store formats.",
            f"Maintain premium shelf placement for {product}. Consider featuring in upcoming seasonal promotions and loyalty program offers.",
            f"Share positive performance data with Church & Dwight Co., Inc. brand team. Explore joint marketing opportunities to further capitalize on strong consumer demand.",
        ]
        doc_id = f"QR-{dt.strftime('%Y%m%d')}-{seq:04d}"
        brand_slug = "hero_cosmetics"
        filename = f"{retailer.lower()}_{brand_slug}_quality_{dt.strftime('%Y%m%d')}_{seq:03d}.pdf"
        docs.append({
            "retailer": retailer,
            "brand": "HERO Cosmetics",
            "product": product,
            "complaint_type": "quality",
            "severity": severity,
            "date": dt,
            "date_str": dt.strftime("%B %d, %Y"),
            "stores": stores,
            "complaint_count": complaint_count,
            "description": description,
            "action": random.choice(action_options),
            "title": random.choice(["Product Performance Report", "Category Quality Review", "Brand Performance Summary"]),
            "doc_id": doc_id,
            "filename": filename,
        })
        seq += 1

    # --- Mixed remaining brand complaints ---
    for i in range(10):
        brand = random.choice(["OxiClean", "TheraBreath", "Batiste"])
        retailer = random.choice(RETAILERS)
        product = random.choice(BRAND_PRODUCTS[brand])
        dt = random_date("2025-09-01", "2026-03-10")
        severity = random.choice(["Low", "Medium"])
        store_count = random.randint(1, 3)
        stores = make_stores(retailer, store_count)
        complaint_count = random.randint(2, 20)
        complaint_type = random.choice(["packaging", "labeling", "quality"])
        template = random.choice(MIXED_COMPLAINT_DESCRIPTIONS)
        description = template.format(
            product=product,
            count=random.randint(3, 15),
            store_count=store_count,
        )
        brand_slug = brand.lower().replace(" ", "_").replace("&", "and")
        action_options = [
            f"Log vendor quality observation for {product}. No immediate action required; continue monitoring return rates over the next 30 days.",
            f"Share customer feedback summary with Church & Dwight Co., Inc. {brand} brand team. Request updated packaging artwork and labeling compliance review.",
            f"Include findings in next quarterly vendor scorecard review with Church & Dwight Co., Inc.. Monitor for trend improvement in upcoming reporting period.",
        ]
        doc_id = f"QR-{dt.strftime('%Y%m%d')}-{seq:04d}"
        filename = f"{retailer.lower()}_{brand_slug}_{complaint_type}_{dt.strftime('%Y%m%d')}_{seq:03d}.pdf"
        docs.append({
            "retailer": retailer,
            "brand": brand,
            "product": product,
            "complaint_type": complaint_type,
            "severity": severity,
            "date": dt,
            "date_str": dt.strftime("%B %d, %Y"),
            "stores": stores,
            "complaint_count": complaint_count,
            "description": description,
            "action": random.choice(action_options),
            "title": random.choice(["Product Quality Report", "Customer Complaint Summary", "Vendor Quality Observation"]),
            "doc_id": doc_id,
            "filename": filename,
        })
        seq += 1

    return docs


def create_volume():
    """Create the UC Volume if it doesn't exist."""
    print("Creating UC Volume (if not exists)...")
    statement = f"CREATE VOLUME IF NOT EXISTS {CATALOG}.{SCHEMA}.{VOLUME}"
    payload = json.dumps({
        "statement": statement,
        "warehouse_id": WAREHOUSE_ID,
    })
    result = subprocess.run(
        ["databricks", "api", "post", "/api/2.0/sql/statements",
         f"--profile={PROFILE}", "--json", payload],
        capture_output=True, text=True,
    )
    print(result.stdout[:500] if result.stdout else "(no output)")
    if result.returncode != 0:
        print(f"Warning: {result.stderr[:300]}")
    print()


def upload_pdfs(docs):
    """Upload all generated PDFs to UC Volume."""
    print(f"\nUploading {len(docs)} PDFs to UC Volume...")
    success = 0
    for i, doc in enumerate(docs):
        local_path = os.path.join(OUTPUT_DIR, doc["filename"])
        remote_path = f"{UC_VOLUME_PATH}/{doc['filename']}"
        result = subprocess.run(
            ["databricks", "fs", "cp", local_path, remote_path, f"--profile={PROFILE}"],
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            success += 1
        else:
            print(f"  FAILED: {doc['filename']} - {result.stderr.strip()[:100]}")
        if (i + 1) % 10 == 0:
            print(f"  Uploaded {i + 1}/{len(docs)}...")

    print(f"\nUpload complete: {success}/{len(docs)} files uploaded successfully.")


def main():
    # Step 1: Create UC Volume
    create_volume()

    # Step 2: Generate PDFs
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    docs = build_documents()
    print(f"Generating {len(docs)} PDF documents...")

    for i, doc in enumerate(docs):
        filepath = os.path.join(OUTPUT_DIR, doc["filename"])
        generate_pdf(doc, filepath)
        if (i + 1) % 10 == 0:
            print(f"  Generated {i + 1}/{len(docs)}...")

    print(f"All {len(docs)} PDFs generated in {OUTPUT_DIR}\n")

    # Summary
    from collections import Counter
    brand_counts = Counter(d["brand"] for d in docs)
    print("Document breakdown by brand:")
    for brand, count in brand_counts.most_common():
        print(f"  {brand}: {count}")
    print()

    # Step 3: Upload to UC Volume
    upload_pdfs(docs)


if __name__ == "__main__":
    main()
