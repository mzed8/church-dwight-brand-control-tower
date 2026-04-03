import re
from fastapi import APIRouter, HTTPException
from services.databricks_service import query

router = APIRouter()


@router.get("/brands")
async def get_brands():
    health_sql = """
    SELECT b.brand_id, b.brand_name, b.category,
           h.health_score, h.positive_pct, h.negative_pct, h.review_count
    FROM brands b
    JOIN brand_health_daily h ON b.brand_name = h.brand_name
    WHERE h.review_date = (SELECT MAX(review_date) FROM brand_health_daily)
    """
    health = query(health_sql)

    delta_sql = """
    SELECT brand_name, health_score as prev_health_score
    FROM brand_health_daily
    WHERE review_date = (SELECT MAX(review_date) - INTERVAL 14 DAYS FROM brand_health_daily)
    """
    deltas = query(delta_sql)
    delta_map = {d["brand_name"]: float(d["prev_health_score"]) for d in deltas}

    roas_sql = """
    SELECT brand_name, AVG(roas) as avg_roas
    FROM channel_performance_weekly
    WHERE week_start_date = (SELECT MAX(week_start_date) FROM channel_performance_weekly)
    GROUP BY brand_name
    """
    roas = query(roas_sql)
    roas_map = {r["brand_name"]: float(r["avg_roas"]) for r in roas}

    trend_sql = """
    SELECT brand_name, review_date, health_score
    FROM brand_health_daily
    WHERE review_date >= (SELECT MAX(review_date) - INTERVAL 30 DAYS FROM brand_health_daily)
    ORDER BY brand_name, review_date
    """
    trends = query(trend_sql)
    trend_map: dict[str, list[float]] = {}
    for t in trends:
        trend_map.setdefault(t["brand_name"], []).append(float(t["health_score"]))

    result = []
    for h in health:
        name = h["brand_name"]
        current_score = float(h["health_score"])
        prev_score = delta_map.get(name, current_score)
        result.append({
            "id": h["brand_id"],
            "name": name,
            "tagline": h.get("category", ""),
            "healthScore": current_score,
            "healthDelta": round(current_score - prev_score, 1),
            "avgRoas": round(roas_map.get(name, 0), 2),
            "healthTrend": trend_map.get(name, []),
        })
    return result


@router.get("/brands/{brand_id}/health")
async def get_brand_health(brand_id: str):
    if not re.match(r"^\d+$", brand_id):
        raise HTTPException(status_code=400, detail="Invalid brand_id")
    sql = f"""
    SELECT h.review_date as date, h.health_score, h.positive_pct, h.negative_pct, h.review_count
    FROM brand_health_daily h
    JOIN brands b ON h.brand_name = b.brand_name
    WHERE b.brand_id = '{brand_id}'
    ORDER BY h.review_date
    """
    return query(sql)


@router.get("/brands/{brand_id}/channels")
async def get_brand_channels(brand_id: str):
    if not re.match(r"^\d+$", brand_id):
        raise HTTPException(status_code=400, detail="Invalid brand_id")
    sql = f"""
    SELECT cp.channel, cp.spend_amount as total_spend, cp.total_revenue, cp.roas, cp.impressions, cp.clicks
    FROM channel_performance_weekly cp
    JOIN brands b ON cp.brand_name = b.brand_name
    WHERE b.brand_id = '{brand_id}'
    AND cp.week_start_date = (SELECT MAX(week_start_date) FROM channel_performance_weekly)
    """
    return query(sql)


@router.get("/brands/{brand_id}/social")
async def get_brand_social(brand_id: str):
    if not re.match(r"^\d+$", brand_id):
        raise HTTPException(status_code=400, detail="Invalid brand_id")
    sql = f"""
    SELECT s.post_date as date, s.platform, s.post_count as total_posts,
           s.total_engagement, s.avg_engagement as avg_engagement_rate
    FROM social_engagement_daily s
    JOIN brands b ON s.brand_name = b.brand_name
    WHERE b.brand_id = '{brand_id}'
    ORDER BY s.post_date
    """
    return query(sql)
