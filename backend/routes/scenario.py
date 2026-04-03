import re
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.databricks_service import query

router = APIRouter()
class ScenarioRequest(BaseModel):
    brand: str
    proposedSpend: dict[str, float]
@router.post("/scenario")
async def run_scenario(request: ScenarioRequest):
    if not re.match(r"^[A-Za-z &]+$", request.brand):
        raise HTTPException(status_code=400, detail="Invalid brand name")
    # Get MMM coefficients for this brand
    coeff_sql = f"""
    SELECT channel, coefficient, avg_weekly_spend, predicted_revenue_contribution
    FROM mmm_channel_contributions
    WHERE brand_name = '{request.brand}'
    """
    coefficients = query(coeff_sql)

    coeff_map: dict[str, float] = {}
    for row in coefficients:
        coeff_map[row["channel"]] = float(row["coefficient"])

    # Get current spend & revenue from the same source as the frontend
    # (channel_performance_weekly, latest week) so numbers are consistent
    current_sql = f"""
    SELECT channel, spend_amount, total_revenue
    FROM channel_performance_weekly
    WHERE brand_name = '{request.brand}'
    AND week_start_date = (SELECT MAX(week_start_date) FROM channel_performance_weekly)
    """
    current_data = query(current_sql)

    current_spend: dict[str, float] = {}
    current_revenue = 0.0
    for row in current_data:
        ch = row["channel"]
        current_spend[ch] = float(row["spend_amount"])
        current_revenue += float(row["total_revenue"])

    # Use MMM coefficients to calculate the revenue DELTA from spend changes
    revenue_delta = 0.0
    for ch, proposed in request.proposedSpend.items():
        coeff = coeff_map.get(ch, 0.0)
        baseline = current_spend.get(ch, 0.0)
        revenue_delta += coeff * (proposed - baseline)

    projected_revenue = current_revenue + revenue_delta

    return {
        "brandId": request.brand,
        "currentSpend": current_spend,
        "proposedSpend": request.proposedSpend,
        "currentRevenue": round(current_revenue, 0),
        "projectedRevenue": round(projected_revenue, 0),
        "revenueDelta": round(revenue_delta, 0),
        "revenueDeltaPct": round(
            (revenue_delta / current_revenue * 100)
            if current_revenue > 0 else 0, 1
        ),
    }
