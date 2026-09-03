"""
Monthly Sell-Through Rate by Region — SQL aggregates by month + region,
Python plots one line per region.
"""

import pandas as pd
import matplotlib.pyplot as plt
from db_connection import get_connection

conn = get_connection()
if conn is None:
    exit(1)

query = """
SELECT
    DATE_FORMAT(date, '%Y-%m-01') AS month,
    region,
    SUM(units_sold) AS units_sold,
    SUM(units_ordered) AS units_ordered,
    ROUND(100.0 * SUM(units_sold) / (SUM(units_sold) + SUM(units_ordered)), 2) AS sell_through_rate
FROM inventory_sales
GROUP BY month, region
ORDER BY month, region;
"""

df = pd.read_sql(query, conn)
conn.close()

df["month"] = pd.to_datetime(df["month"])

plt.figure(figsize=(12, 6))
for region in sorted(df["region"].unique()):
    subset = df[df["region"] == region]
    plt.plot(subset["month"], subset["sell_through_rate"], marker="o", markersize=3, label=region)

plt.title("Monthly Sell-Through Rate by Region (from MySQL)")
plt.xlabel("Month")
plt.ylabel("Sell-Through Rate (%)")
plt.legend(title="Region")
plt.grid(True, alpha=0.3)
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig("monthly_sell_through_by_region_from_db.png")
plt.show()
