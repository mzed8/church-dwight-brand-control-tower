"""
Generate synthetic Act 1 data for Church & Dwight Co., Inc. CPG marketing demo.
Tables: brands, products, retailers, reviews_raw, social_posts_raw
"""

import os
import random
import uuid
import math
from datetime import date, timedelta

os.environ["DATABRICKS_CONFIG_PROFILE"] = "fevm-serverless-stable-ocafq5"

from mimesis import Generic, Locale
from pyspark.sql import Row
from databricks.connect import DatabricksSession

# ---------------------------------------------------------------------------
# Reproducibility
# ---------------------------------------------------------------------------
random.seed(42)
gen = Generic(locale=Locale.EN, seed=42)

CATALOG = "serverless_stable_ocafq5_catalog"
SCHEMA = "chd_demo"

def table_path(name: str) -> str:
    return f"{CATALOG}.{SCHEMA}.{name}"

# ---------------------------------------------------------------------------
# Spark session
# ---------------------------------------------------------------------------
print("Connecting to Databricks ...")
spark = DatabricksSession.builder.profile("fevm-serverless-stable-ocafq5").serverless().getOrCreate()
print("Connected.")

# ===================================================================
# TABLE 1: brands
# ===================================================================
brands_data = [
    Row(brand_id=1, brand_name="ARM & HAMMER", category="Household / Multi-Category",
        annual_revenue_mm=21.84, flagship_product="ARM & HAMMER Flagship"),
    Row(brand_id=2, brand_name="OxiClean", category="Household / Stain Removal",
        annual_revenue_mm=10.14, flagship_product="OxiClean Flagship"),
    Row(brand_id=3, brand_name="TheraBreath", category="Oral Care",
        annual_revenue_mm=7.54, flagship_product="TheraBreath Flagship"),
    Row(brand_id=4, brand_name="Batiste", category="Personal Care / Beauty",
        annual_revenue_mm=5.72, flagship_product="Batiste Flagship"),
    Row(brand_id=5, brand_name="HERO Cosmetics", category="Skincare / Acne Care",
        annual_revenue_mm=4.576, flagship_product="HERO Cosmetics Flagship"),
]

df_brands = spark.createDataFrame(brands_data)
df_brands.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(table_path("brands"))
print(f"brands: {df_brands.count()} rows written")

# ===================================================================
# TABLE 2: products  (~12 per brand)
# ===================================================================
product_defs = []

brand_1_products = [
    ("Clean Burst Laundry Detergent", "Laundry", 11.99),
    ("Plus OxiClean Laundry Detergent", "Laundry", 13.99),
    ("Baking Soda Fresh Laundry Detergent", "Laundry", 12.49),
    ("Clump & Seal Cat Litter", "Cat Litter", 18.99),
    ("DUAL DEFENSE Cat Litter with Microban", "Cat Litter", 21.99),
    ("Slide Easy Clean-Up Cat Litter", "Cat Litter", 22.99),
    ("Advance White Toothpaste", "Oral Care", 4.99),
    ("Complete Care Toothpaste", "Oral Care", 5.49),
    ("Pure Baking Soda", "Baking Soda", 3.99),
    ("Carpet & Room Deodorizer", "Home Care", 5.99),
]

brand_2_products = [
    ("Versatile Stain Remover Powder", "Stain Remover", 12.99),
    ("White Revive Laundry Whitener", "Laundry Additive", 9.99),
    ("Max Force Gel Stick", "Stain Fighter", 5.99),
    ("Dark Protect Laundry Booster", "Laundry Additive", 8.99),
    ("Odor Blasters Stain & Odor Remover", "Stain Remover", 11.99),
    ("Washing Machine Cleaner", "Machine Care", 10.99),
    ("Color Boost Color Brightener", "Laundry Additive", 8.49),
    ("Outdoor Stain Remover", "Outdoor Cleaning", 9.99),
]

brand_3_products = [
    ("Fresh Breath Oral Rinse", "Mouthwash", 13.99),
    ("Healthy Gums Oral Rinse", "Mouthwash", 13.99),
    ("Whitening Fresh Breath Toothpaste", "Toothpaste", 9.99),
    ("Healthy Smile Anticavity Toothpaste", "Toothpaste", 9.99),
    ("Anti-Cavity Fluoride Toothpaste", "Toothpaste", 8.99),
    ("Fresh Breath Dry Mouth Lozenges", "Oral Care", 11.99),
    ("Kids Anticavity Mouthwash", "Children's Oral Care", 8.49),
    ("Fresh Breath Throat Spray", "Oral Care", 12.99),
    ("Overnight Oral Rinse", "Mouthwash", 14.99),
]

brand_4_products = [
    ("Original Dry Shampoo", "Dry Shampoo", 8.99),
    ("Bare Dry Shampoo", "Dry Shampoo", 9.99),
    ("Light Dry Shampoo", "Dry Shampoo", 9.99),
    ("Brunette Tinted Dry Shampoo", "Tinted Dry Shampoo", 9.99),
    ("Divine Dark Dry Shampoo", "Tinted Dry Shampoo", 9.99),
    ("Cherry Dry Shampoo", "Scented Dry Shampoo", 8.99),
    ("Tropical Dry Shampoo", "Scented Dry Shampoo", 8.99),
    ("Volumizing Dry Shampoo", "Styling", 9.99),
    ("Overnight Deep Cleanse", "Hair Care", 10.99),
    ("Hydrating Dry Shampoo", "Dry Shampoo", 9.99),
]

brand_5_products = [
    ("Mighty Patch Original", "Acne Patches", 12.99),
    ("Mighty Patch Invisible+", "Acne Patches", 14.99),
    ("Mighty Patch Surface", "Acne Patches", 17.99),
    ("Mighty Patch Micropoint for Blemishes", "Acne Treatment", 12.99),
    ("Lightning Wand Dark Spot Serum", "Skincare", 16.99),
    ("Rescue Balm +Red Correct", "Skincare", 15.99),
    ("Dissolve Away Cleansing Balm", "Cleanser", 14.99),
    ("Exfoliating Jelly Cleanser", "Cleanser", 13.99),
    ("Force Shield Superfine Sunscreen SPF 30", "Sun Care", 21.99),
    ("Pore Control Niacinamide Primer", "Primer", 16.99),
]

brand_product_map = {
    1: brand_1_products,
    2: brand_2_products,
    3: brand_3_products,
    4: brand_4_products,
    5: brand_5_products,
}

pid = 1
products_rows = []
for brand_id, prods in brand_product_map.items():
    for name, sub_cat, price in prods:
        upc = "".join([str(random.randint(0, 9)) for _ in range(12)])
        products_rows.append(Row(
            product_id=pid,
            brand_id=brand_id,
            product_name=name,
            sub_category=sub_cat,
            avg_price=round(price, 2),
            upc=upc,
        ))
        pid += 1

df_products = spark.createDataFrame(products_rows)
df_products.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(table_path("products"))
print(f"products: {df_products.count()} rows written")

# ===================================================================
# TABLE 3: retailers
# ===================================================================
retailers_data = [
    Row(retailer_id=1, retailer_name="Walmart", channel_type="Mass",
        has_retail_media=True, retail_media_name="Walmart Connect"),
    Row(retailer_id=2, retailer_name="Amazon", channel_type="E-commerce",
        has_retail_media=True, retail_media_name="Amazon Ads"),
    Row(retailer_id=3, retailer_name="Target", channel_type="Mass",
        has_retail_media=True, retail_media_name="Target Roundel"),
    Row(retailer_id=4, retailer_name="Kroger", channel_type="Grocery",
        has_retail_media=True, retail_media_name="Kroger Precision Marketing"),
    Row(retailer_id=5, retailer_name="Costco", channel_type="Club",
        has_retail_media=False, retail_media_name="None"),
]

df_retailers = spark.createDataFrame(retailers_data)
df_retailers.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(table_path("retailers"))
print(f"retailers: {df_retailers.count()} rows written")

# ===================================================================
# Helpers
# ===================================================================
START_DATE = date(2025, 6, 1)
END_DATE = date(2026, 3, 10)

def random_date(start=START_DATE, end=END_DATE):
    return start + timedelta(days=random.randint(0, (end - start).days))

brand_product_ids = {}
for r in products_rows:
    brand_product_ids.setdefault(r.brand_id, []).append(r.product_id)


# ===================================================================
# Review text templates
# ===================================================================
positive_titles = [
    "Great product!", "Love this!", "Works perfectly", "Highly recommend",
    "Best I've tried", "Amazing quality", "Five stars!", "Will buy again",
    "Exceeded expectations", "Fantastic!", "So good!", "Must have!",
    "Wonderful product", "Absolutely love it", "Perfect!",
]
neutral_titles = [
    "Decent product", "It's okay", "Does the job", "Average",
    "Not bad", "Good enough", "Fair product", "Meets expectations",
    "Nothing special", "Works fine",
]
negative_titles = [
    "Disappointed", "Not worth it", "Broke after first use", "Terrible quality",
    "Would not recommend", "Waste of money", "Very disappointing",
    "Poor quality", "Not as described", "Save your money",
]

positive_sentences = [
    "This is one of the best products I've ever used.",
    "I've been using this for months and it works perfectly every time.",
    "Great value for the price, I'm very satisfied.",
    "The quality is outstanding and it arrived quickly.",
    "My family loves this product and we keep buying it.",
    "It does exactly what it says on the label.",
    "I've tried many brands but this one is my favorite.",
    "Super effective and easy to use.",
    "I recommend this to everyone I know.",
    "Works great, no complaints at all.",
    "Really impressed with the results.",
    "This has become a household staple for us.",
    "Excellent product, will definitely repurchase.",
    "So glad I found this, it makes such a difference.",
    "Top notch quality at a reasonable price.",
]

neutral_sentences = [
    "It works fine but nothing special compared to other brands.",
    "The product does what it's supposed to do.",
    "It's decent for the price point.",
    "I've used better products but this is okay.",
    "Average quality, might try something else next time.",
    "It gets the job done but I expected a bit more.",
    "Not bad, not great. Middle of the road.",
    "Reasonable product for everyday use.",
]

negative_sentences = [
    "I'm really disappointed with the quality.",
    "This product did not live up to the hype.",
    "I would not buy this again.",
    "The product stopped working after just a few uses.",
    "Not worth the money at all.",
    "I expected much better quality for the price.",
    "The packaging was damaged when it arrived.",
    "This did not work as advertised.",
    "Very unhappy with this purchase.",
    "I had a much better experience with other brands.",
]

# --- Crisis-specific review templates (ARM & HAMMER - Cat Litter Reformulation Complaints Surge) ---
crisis_negative_titles = [
    "Product leaked everywhere!",
    "Packaging is terrible",
    "Cap was broken on arrival",
    "Lid cracked and spilled",
    "Product leaked in shipping",
    "Defective packaging",
    "Arrived leaking",
    "Packaging leak ruined everything",
    "Broken cap on bottle",
    "Spilled everywhere in the box",
]
crisis_negative_sentences = [
    "The bottle leaked all over the inside of the shipping box.",
    "The cap was broken when it arrived and product spilled everywhere.",
    "The lid cracked during shipping and the product leaked out.",
    "This is the second time I've received a leaking bottle from this brand.",
    "Packaging leak caused a huge mess, very frustrating.",
    "The bottle seal was broken and half the product was gone.",
    "Cap broken right out of the box, what a waste.",
    "Spilled everywhere in my pantry because the lid wasn't sealed properly.",
    "The packaging quality has really gone downhill recently.",
    "Received a completely soaked box because the bottle leaked.",
    "I love the product but the new packaging is terrible, it leaks constantly.",
    "Third leaking bottle in a row. They need to fix their packaging.",
]

# --- Opportunity-specific review templates (HERO Cosmetics - TikTok Cleanser Launch Amplification Window) ---
opportunity_positive_titles = [
    "Gym bag essential!",
    "Perfect post-workout fix",
    "Travel must-have",
    "Gym bag essentials",
    "Best for after the gym",
    "Workout lifesaver",
    "My post-workout go-to",
    "Gym bag must-have",
    "Travel essential!",
    "Perfect for gym bag essentials",
]
opportunity_positive_sentences = [
    "This is a gym bag essential, I never leave home without it.",
    "Perfect for a quick refresh after a workout.",
    "I keep one in my gym bag and one at home, it's that good.",
    "This is my go-to travel essential for freshening up on the go.",
    "After my morning workout, a quick spray and I'm ready for the day.",
    "Best product for active lifestyles and travel.",
    "I use this post workout every single day and it never disappoints.",
    "My experience looks fresh even after an intense session.",
    "This has become part of my post-workout routine and I love it.",
    "A travel essential that takes up almost no space in my bag.",
    "I recommended this to my entire class as a gym bag essential.",
]



def make_review_text(rating, product_id, brand_id, is_crisis_negative, is_opportunity_positive):
    if is_crisis_negative:
        title = random.choice(crisis_negative_titles)
        sents = [random.choice(crisis_negative_sentences) for _ in range(random.randint(2, 4))]
        return title, " ".join(sents)

    if is_opportunity_positive:
        title = random.choice(opportunity_positive_titles)
        sents = [random.choice(opportunity_positive_sentences) for _ in range(random.randint(2, 4))]
        return title, " ".join(sents)


    if rating >= 4:
        title = random.choice(positive_titles)
        sents = [random.choice(positive_sentences) for _ in range(random.randint(2, 4))]
    elif rating == 3:
        title = random.choice(neutral_titles)
        sents = [random.choice(neutral_sentences) for _ in range(random.randint(2, 3))]
    else:
        title = random.choice(negative_titles)
        sents = [random.choice(negative_sentences) for _ in range(random.randint(2, 4))]
    return title, " ".join(sents)


# ===================================================================
# TABLE 4: reviews_raw  (50000 rows)
# ===================================================================
NUM_REVIEWS = 50000
print(f"Generating reviews_raw ({NUM_REVIEWS} rows) ...")

ratings_pool = [1]*5 + [2]*10 + [3]*15 + [4]*30 + [5]*40

other_retailers = [4, 5]
if not other_retailers:
    other_retailers = [r.retailer_id for r in retailers_data[3:]]

all_product_ids = list(range(1, len(products_rows) + 1))
product_weights = []
for pid_val in all_product_ids:
    for bid, pids in brand_product_ids.items():
        if pid_val in pids:
            idx = pids.index(pid_val)
            product_weights.append(max(1, 12 - idx))
            break

def pick_retailer():
    r = random.random()
    if r < 0.60:
        return 2  # Amazon/E-commerce
    elif r < 0.80:
        return 1  # Walmart/Mass 1
    elif r < 0.90:
        return 3  # Target/Mass 2
    else:
        return random.choice(other_retailers) if other_retailers else 1

def helpful_votes_gamma():
    return min(50, int(random.gammavariate(1.0, 3.0)))

# Crisis window (ARM & HAMMER Cat Litter Reformulation Complaints Surge)
crisis_start = date(2026, 2, 24)
crisis_end = date(2026, 3, 10)
crisis_product_ids = brand_product_ids[1]

# Opportunity window (HERO Cosmetics TikTok Cleanser Launch Amplification Window)
opportunity_start = date(2026, 3, 3)
opportunity_end = date(2026, 3, 10)
opportunity_product_ids = brand_product_ids[5]

NUM_CRISIS_REVIEWS = 340
NUM_OPPORTUNITY_REVIEWS = 300

reviews = []

# Crisis-specific reviews (ARM & HAMMER)
for i in range(NUM_CRISIS_REVIEWS):
    rid = str(uuid.uuid4())
    pid_val = random.choice(crisis_product_ids)
    ret_id = random.choice([2, 2, 2, 1, 1])
    rating = random.choice([1, 1, 1, 2, 2])
    title, text = make_review_text(rating, pid_val, 1, True, False)
    reviewer = gen.person.full_name()
    rev_date = random_date(crisis_start, crisis_end)
    verified = random.random() < 0.85
    helpful = helpful_votes_gamma()
    reviews.append(Row(
        review_id=rid, product_id=pid_val, retailer_id=ret_id,
        rating=rating, review_title=title, review_text=text,
        reviewer_name=reviewer, review_date=rev_date,
        verified_purchase=verified, helpful_votes=helpful,
    ))

# Opportunity-specific reviews (HERO Cosmetics)
for i in range(NUM_OPPORTUNITY_REVIEWS):
    rid = str(uuid.uuid4())
    pid_val = random.choice(opportunity_product_ids)
    ret_id = pick_retailer()
    rating = random.choice([4, 4, 5, 5, 5])
    title, text = make_review_text(rating, pid_val, 5, False, True)
    reviewer = gen.person.full_name()
    rev_date = random_date(opportunity_start, opportunity_end)
    verified = random.random() < 0.85
    helpful = helpful_votes_gamma()
    reviews.append(Row(
        review_id=rid, product_id=pid_val, retailer_id=ret_id,
        rating=rating, review_title=title, review_text=text,
        reviewer_name=reviewer, review_date=rev_date,
        verified_purchase=verified, helpful_votes=helpful,
    ))

remaining = NUM_REVIEWS - len(reviews)
for i in range(remaining):
    rid = str(uuid.uuid4())
    pid_val = random.choices(all_product_ids, weights=product_weights, k=1)[0]
    bid = 0
    cumulative = 0
    for brand_id, pids in brand_product_ids.items():
        if pid_val in pids:
            bid = brand_id
            break
    ret_id = pick_retailer()
    rating = random.choice(ratings_pool)
    title, text = make_review_text(rating, pid_val, bid, False, False)
    reviewer = gen.person.full_name()
    rev_date = random_date()
    verified = random.random() < 0.85
    helpful = helpful_votes_gamma()
    reviews.append(Row(
        review_id=rid, product_id=pid_val, retailer_id=ret_id,
        rating=rating, review_title=title, review_text=text,
        reviewer_name=reviewer, review_date=rev_date,
        verified_purchase=verified, helpful_votes=helpful,
    ))

    if (i + 1) % 10000 == 0:
        print(f"  Generated {i + 1}/{remaining} general reviews ...")

random.shuffle(reviews)

print("Uploading reviews_raw to Databricks ...")
df_reviews = spark.createDataFrame(reviews)
df_reviews.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(table_path("reviews_raw"))
print(f"reviews_raw: {df_reviews.count()} rows written")

# ===================================================================
# TABLE 5: social_posts_raw  (20000 rows)
# ===================================================================
NUM_SOCIAL = 20000
print(f"Generating social_posts_raw ({NUM_SOCIAL} rows) ...")

platforms = ["Twitter/X", "Reddit", "TikTok", "Instagram"]
platform_weights = [30, 25, 30, 15]
author_types = ["consumer", "influencer", "brand_advocate"]
author_type_weights = [80, 15, 5]
brand_weights_social = [420000, 195000, 145000, 110000, 88000]
brand_name_map = {
    1: "ARM & HAMMER",
    2: "OxiClean",
    3: "TheraBreath",
    4: "Batiste",
    5: "HERO Cosmetics",
}

def make_url(platform, handle):
    post_num = random.randint(1000000000, 9999999999)
    if platform == "Twitter/X":
        return f"https://twitter.com/{handle}/status/{post_num}"
    elif platform == "Reddit":
        return f"https://reddit.com/r/products/comments/{hex(post_num)[2:]}"
    elif platform == "TikTok":
        return f"https://tiktok.com/@{handle}/video/{post_num}"
    else:
        return f"https://instagram.com/p/{hex(post_num)[2:]}"

def make_handle():
    word = gen.person.last_name().lower()
    num = random.randint(1, 9999)
    return f"@{word}{num}"

def engagement_power_law():
    val = random.paretovariate(1.2) - 1
    return min(10000, int(val * 30))

brand_hashtags = {
    1: ["#ArmAndHammer", "#ARMandHAMMER", "#TheWholeDarnArm"],
    2: ["#OxiClean", "#OxiCleanItUp"],
    3: ["#TheraBreath", "#FreshBreath", "#CouchToCart"],
    4: ["#Batiste", "#DryShampoo", "#BatisteLight"],
    5: ["#HEROCosmetics", "#MightyPatch", "#HeroSkin"],
}

generic_positive_social = [
    "Just tried {brand} and I'm impressed! {hashtag}",
    "Been using {brand} for years, still the best {hashtag}",
    "Shoutout to {brand} for making great products {hashtag}",
    "{brand} never disappoints {hashtag}",
    "Can't live without my {brand} {hashtag}",
    "Finally switched to {brand} and wow what a difference {hashtag}",
    "My {brand} haul from this week {hashtag}",
    "{brand} is seriously underrated {hashtag}",
]

generic_neutral_social = [
    "Tried {brand} today. It's alright I guess {hashtag}",
    "Anyone else use {brand}? Looking for reviews {hashtag}",
    "Thinking about switching from {brand} to something else {hashtag}",
    "Is {brand} worth the price? Asking for a friend {hashtag}",
]

generic_negative_social = [
    "Not happy with {brand} lately {hashtag}",
    "{brand} quality has really gone downhill {hashtag}",
    "Anyone else having issues with {brand}? {hashtag}",
    "Disappointed with my {brand} purchase {hashtag}",
]

# Crisis-specific social posts (ARM & HAMMER)
crisis_social_negative = [
    "My ARM & HAMMER product leaked EVERYWHERE in the delivery box. Fix your packaging! #ARM&HAMMER #PackagingFail",
    "Second time my ARM & HAMMER arrived with a broken cap. This is unacceptable #ARM&HAMMER",
    "Anyone else getting leaking ARM & HAMMER bottles from Amazon? The caps keep breaking #ARM&HAMMER #PackagingLeak",
    "Opened my Amazon box to find ARM & HAMMER leaked all over my other items. Not cool. #ARM&HAMMER",
    "ARM & HAMMER packaging quality is terrible lately. Three bottles in a row leaked. #ARM&HAMMER #Disappointed",
    "The new ARM & HAMMER bottles have the worst caps. Leaking everywhere! #PackagingFail",
    "PSA: if you order ARM & HAMMER online, expect a leaking mess. Their packaging is broken. #ARM&HAMMER",
    "My ARM & HAMMER spilled everywhere in the shipping box. The lid was completely cracked. #ARM&HAMMER",
]

# Opportunity-specific social posts (HERO Cosmetics)
opportunity_social_positive = [
    "gym bag essentials check: HERO Cosmetics is non-negotiable {hashtag} #gymtok #gymbagessentials",
    "post workout hack: HERO Cosmetics hits different after leg day {hashtag} #workouttips",
    "POV: you just left the gym and HERO Cosmetics saves your day {hashtag} #gymlife #gymbagessentials",
    "my gym bag essentials ft. HERO Cosmetics {hashtag} #fyp #gymbagessentials",
    "travel essential: HERO Cosmetics keeps things fresh on the go {hashtag} #traveltok",
    "why HERO Cosmetics is in every gym girl's bag {hashtag} #gymtok #gymbagessentials #postworkout",
    "HERO Cosmetics after a workout is literally a game changer {hashtag} #fitnesstok #postworkout",
    "gym bag essentials that actually work: HERO Cosmetics edition {hashtag} #gymbagessentials",
    "this product is a travel essential, HERO Cosmetics never lets me down {hashtag} #travelessentials",
    "the way HERO Cosmetics makes my post workout routine look fresh is unmatched {hashtag} #gymtok",
    "adding HERO Cosmetics to my gym bag essentials was the best decision {hashtag} #workouttok",
    "HERO Cosmetics review: the ultimate gym bag essential {hashtag} #productreview #gymbagessentials",
]

reddit_templates = [
    "I've been using {brand} for about 6 months now and here's my honest review. {detail} Overall I'd rate it {rating}/10. {hashtag}",
    "Switched to {brand} from a competitor last month. {detail} Has anyone else had a similar experience? {hashtag}",
    "PSA about {brand}: {detail} Just wanted to share in case anyone else is on the fence. {hashtag}",
    "Long time {brand} user here. {detail} Would love to hear other opinions. {hashtag}",
]

reddit_details_positive = [
    "The quality has been consistently great and the price is fair.",
    "Works exactly as described and I've noticed a real difference.",
    "Customer service was also excellent when I had a question.",
    "It's become a staple in our household and the whole family uses it.",
]

reddit_details_negative = [
    "The quality seems to have dropped compared to last year.",
    "I'm not sure it's worth the premium price anymore.",
    "Had some issues with consistency between batches.",
    "The formula seems different and not in a good way.",
]

NUM_OPPORTUNITY_SOCIAL_SPIKE = 200
NUM_CRISIS_SOCIAL_NEG = 80

social_posts = []

# Opportunity social spike (HERO Cosmetics)
for i in range(NUM_OPPORTUNITY_SOCIAL_SPIKE):
    post_id = str(uuid.uuid4())
    brand_id = 5
    platform = "TikTok"
    handle = make_handle()
    hashtag = random.choice(brand_hashtags[5])
    text = random.choice(opportunity_social_positive).format(hashtag=hashtag)
    author_type = random.choices(["consumer", "influencer", "brand_advocate"], weights=[60, 30, 10], k=1)[0]
    engagement = random.randint(500, 10000)
    post_date = random_date(opportunity_start, opportunity_end)
    url = make_url(platform, handle.lstrip("@"))
    social_posts.append(Row(
        post_id=post_id, brand_id=brand_id, platform=platform,
        post_text=text, author_handle=handle, author_type=author_type,
        engagement_count=engagement, post_date=post_date, url=url,
    ))

# Crisis social negative (ARM & HAMMER)
for i in range(NUM_CRISIS_SOCIAL_NEG):
    post_id = str(uuid.uuid4())
    brand_id = 1
    platform = random.choice(["Twitter/X", "Reddit", "Twitter/X"])
    handle = make_handle()
    text = random.choice(crisis_social_negative)
    author_type = "consumer"
    engagement = random.randint(10, 2000)
    post_date = random_date(crisis_start, crisis_end)
    url = make_url(platform, handle.lstrip("@"))
    social_posts.append(Row(
        post_id=post_id, brand_id=brand_id, platform=platform,
        post_text=text, author_handle=handle, author_type=author_type,
        engagement_count=engagement, post_date=post_date, url=url,
    ))

remaining_social = NUM_SOCIAL - len(social_posts)
for i in range(remaining_social):
    post_id = str(uuid.uuid4())
    brand_id = random.choices([1, 2, 3, 4, 5], weights=brand_weights_social, k=1)[0]
    platform = random.choices(platforms, weights=platform_weights, k=1)[0]
    handle = make_handle()
    author_type = random.choices(author_types, weights=author_type_weights, k=1)[0]
    engagement = engagement_power_law()
    post_date = random_date()
    hashtag = random.choice(brand_hashtags[brand_id])
    brand = brand_name_map[brand_id]

    sentiment_roll = random.random()
    if platform == "Reddit":
        detail = random.choice(reddit_details_positive if sentiment_roll > 0.25 else reddit_details_negative)
        rating = random.randint(6, 9) if sentiment_roll > 0.25 else random.randint(3, 5)
        text = random.choice(reddit_templates).format(brand=brand, detail=detail, rating=rating, hashtag=hashtag)
    else:
        if sentiment_roll < 0.15:
            text = random.choice(generic_negative_social).format(brand=brand, hashtag=hashtag)
        elif sentiment_roll < 0.30:
            text = random.choice(generic_neutral_social).format(brand=brand, hashtag=hashtag)
        else:
            text = random.choice(generic_positive_social).format(brand=brand, hashtag=hashtag)

    url = make_url(platform, handle.lstrip("@"))
    social_posts.append(Row(
        post_id=post_id, brand_id=brand_id, platform=platform,
        post_text=text, author_handle=handle, author_type=author_type,
        engagement_count=engagement, post_date=post_date, url=url,
    ))

    if (i + 1) % 5000 == 0:
        print(f"  Generated {i + 1}/{remaining_social} general social posts ...")

random.shuffle(social_posts)

print("Uploading social_posts_raw to Databricks ...")
df_social = spark.createDataFrame(social_posts)
df_social.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(table_path("social_posts_raw"))
print(f"social_posts_raw: {df_social.count()} rows written")

print("\nAll tables generated and loaded successfully!")
print(f"  Catalog: {CATALOG}")
print(f"  Schema:  {SCHEMA}")
print("  Tables:  brands, products, retailers, reviews_raw, social_posts_raw")
