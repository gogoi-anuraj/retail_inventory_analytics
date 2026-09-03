"""
Inventory Risk Distribution — queries MySQL directly, SQL does the
classification + aggregation, Python just plots the result.

"""

import pandas as pd
import matplotlib.pyplot as plt
from db_connection import get_connection

conn = get_connection()
if conn is None:
    exit(1)

# SQL does the classification (same canonical thresholds used throughout
# this project) and the aggregation — Python only receives 4 rows back.
query = """
SELECT
    CASE
        WHEN inventory_level < demand_forecast THEN 'Understocked'
        WHEN inventory_level <= 1.5 * demand_forecast THEN 'Balanced'
        WHEN inventory_level <= 2 * demand_forecast THEN 'High Inventory'
        ELSE 'Excess Inventory'
    END AS inventory_risk,
    COUNT(*) AS observations,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM inventory_sales
WHERE demand_forecast > 0
GROUP BY inventory_risk;
"""

df = pd.read_sql(query, conn)
conn.close()

risk_order = ["Understocked", "Balanced", "High Inventory", "Excess Inventory"]
df["inventory_risk"] = pd.Categorical(df["inventory_risk"], categories=risk_order, ordered=True)
df = df.sort_values("inventory_risk")

plt.figure(figsize=(9, 5))
bars = plt.bar(df["inventory_risk"], df["pct"])
plt.title("Inventory Risk Distribution (from MySQL)")
plt.xlabel("Inventory Risk")
plt.ylabel("Percentage of Observations")
for bar, value in zip(bars, df["pct"]):
    plt.text(bar.get_x() + bar.get_width() / 2, value + 0.5, f"{value:.2f}%", ha="center")
plt.grid(axis="y", alpha=0.3)
plt.tight_layout()
plt.savefig("inventory_risk_distribution_from_db.png")
plt.show()
