from fastapi import APIRouter
from services.databricks_service import query

router = APIRouter()


@router.get("/alerts")
async def get_alerts():
    # Alert 1: ARM & HAMMER - Cat Litter Reformulation Complaints Surge
    alert1_sql = """
    SELECT health_score, negative_pct, review_count
    FROM brand_health_daily
    WHERE brand_name = 'ARM & HAMMER'
    AND review_date = (SELECT MAX(review_date) FROM brand_health_daily)
    """
    alert1_data = query(alert1_sql)

    alert1_prev_sql = """
    SELECT health_score as prev_score
    FROM brand_health_daily
    WHERE brand_name = 'ARM & HAMMER'
    AND review_date = (SELECT MAX(review_date) - INTERVAL 14 DAYS FROM brand_health_daily)
    """
    alert1_prev = query(alert1_prev_sql)

    # Alert 2: OxiClean - Linear TV Over-Indexed vs. Retail Media
    alert2_sql = """
    SELECT channel, roas, spend_amount
    FROM channel_performance_weekly
    WHERE brand_name = 'OxiClean'
    AND week_start_date = (SELECT MAX(week_start_date) FROM channel_performance_weekly)
    ORDER BY roas DESC
    """
    alert2_channels = query(alert2_sql)

    # Alert 3: HERO Cosmetics - TikTok Cleanser Launch Amplification Window
    alert3_roas_sql = """
    SELECT channel, roas
    FROM channel_performance_weekly
    WHERE brand_name = 'HERO Cosmetics'
    AND channel = 'TikTok'
    AND week_start_date = (SELECT MAX(week_start_date) FROM channel_performance_weekly)
    """
    alert3_roas = query(alert3_roas_sql)

    alert1_current = float(alert1_data[0]["health_score"]) if alert1_data else 64
    alert1_previous = 78  # Narrative: score was 78 before crisis
    alert1_drop = round(78 - alert1_current, 1)  # Drop from pre-crisis baseline

    high_roas_val = 0.0
    low_roas_val = 0.0
    low_roas_spend = 0.0
    for ch in alert2_channels:
        if ch["channel"] == "Retail Media":
            high_roas_val = float(ch["roas"])
        if ch["channel"] == "Linear TV":
            low_roas_val = float(ch["roas"])
            low_roas_spend = float(ch["spend_amount"])

    alert3_channel_roas = float(alert3_roas[0]["roas"]) if alert3_roas else 7.2x

    alerts = [
        {
            "id": "alert_arm_hammer_reformulation",
            "brandId": "1",
            "brandName": "ARM & HAMMER",
            "severity": "critical",
            "title": "Cat Litter Reformulation Complaints Surge",
            "summary": f"ARM & HAMMER Cat Litter health score dropped to {{health_score}} (from {{previous_score}}) after {{negative_reviews}} negative reviews in 14 days citing 'chemical smell' and 'clumping failure' with the new DUAL DEFENSE Microban formula. {{complaint_docs}} complaint documents flagged for review.",
            "recommendation": "Pause DUAL DEFENSE Microban TV creative and activate Amazon review response team. Brief Walmart category manager on reformulation timeline. Run urgent VOC analysis on Microban-specific complaints vs. legacy Clump & Seal reviews.",
            "metrics": {
                "healthScore": alert1_current,
                "previousScore": alert1_previous,
                "drop": alert1_drop,
                "negativeReviews": 2847,
                "complaintDocs": 156,
            },
            "status": "pending",
        },
        {
            "id": "alert_oxiclean_spend",
            "brandId": "2",
            "brandName": "OxiClean",
            "severity": "warning",
            "title": "Linear TV Over-Indexed vs. Retail Media",
            "summary": f"OxiClean Linear TV spend delivers {{low_roas_channel}} ROAS — 2.3x lower than {{high_roas_channel}} at 4.2x ROAS. Following the NAD ruling against OxiClean's 'Scary Bleach' TV creative, reallocating 30% of TV budget could deliver {{projected_lift}} in monthly revenue lift.",
            "recommendation": "Shift $58K/week from Linear TV to Walmart Connect and Amazon Ads Sponsored Video placements. Leverage existing Wavemaker creative assets optimized for retail media. Prioritize OxiClean stain-removal demo content that drove 4.2x ROAS in Q4 holiday campaign.",
            "metrics": {
                "wcRoas": high_roas_val,
                "psRoas": low_roas_val,
                "psSpend": low_roas_spend,
                "projectedLift": $380K/month,
            },
            "status": "pending",
        },
        {
            "id": "alert_hero_tiktok",
            "brandId": "5",
            "brandName": "HERO Cosmetics",
            "severity": "opportunity",
            "title": "TikTok Cleanser Launch Amplification Window",
            "summary": f"HERO Cosmetics {{channel}} engagement spiked {{engagement_spike}} ahead of the 3-SKU cleanser platform launch. With Alix Earle driving {{influencer_roas}} influencer ROAS, a {{recommended_increase}} increase in social spend during launch week could capture the Gen Z skincare moment.",
            "recommendation": "Increase TikTok and Instagram Reels spend by 40% during the cleanser launch window. Activate micro-influencer seeding program leveraging Mighty Patch's existing creator network of 30+ partners. Target #acneskincare and #skincareroutine hashtags where HERO already indexes in the top 5.",
            "metrics": {
                "engagementSpike": +270%,
                "influencerRoas": alert3_channel_roas,
                "recommendedIncrease": 40%,
            },
            "status": "pending",
        },
    ]
    return alerts
