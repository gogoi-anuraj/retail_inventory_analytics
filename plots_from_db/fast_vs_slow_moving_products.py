"""
Fast vs Slow-Moving Products (bubble chart) — SQL computes the turnover
proxy AND the Fast/Medium/Slow segmentation using NTILE(), Python only
draws the bubbles.
"""

import pandas as pd
import matplotlib.pyplot as plt
from db_connection import get_connection

conn = get_connection()
if conn is None:
    exit(1)

# Same NTILE(3) tercile split used in sql/analysis.sql section 4.2 —
# SQL does the ranking/segmentation, not just the aggregation.
query = """
WITH product_metrics AS (
    SELECT
        product_id,
        SUM(units_sold) AS total_units_sold,
        ROUND(AVG(inventory_level), 2) AS avg_inventory,
        AVG(units_sold) / NULLIF(AVG(inventory_level), 0) AS inventory_turnover_proxy
    FROM inventory_sales
    GROUP BY product_id
),
ranked AS (
    SELECT
        *,
        NTILE(3) OVER (ORDER BY inventory_turnover_proxy) AS turnover_tercile
    FROM product_metrics
)
SELECT
    product_id,
    total_units_sold,
    avg_inventory,
    ROUND(inventory_turnover_proxy, 4) AS inventory_turnover_proxy,
    CASE turnover_tercile
        WHEN 1 THEN 'Slow-moving'
        WHEN 2 THEN 'Medium-moving'
        WHEN 3 THEN 'Fast-moving'
    END AS movement_segment
FROM ranked
ORDER BY product_id;
"""

df = pd.read_sql(query, conn)
conn.close()

SEGMENT_COLORS = {"Fast-moving": "#00CC96", "Medium-moving": "#FFA15A", "Slow-moving": "#EF553B"}

sizes = 200 + 1800 * (
    (df["total_units_sold"] - df["total_units_sold"].min())
    / (df["total_units_sold"].max() - df["total_units_sold"].min())
)

plt.figure(figsize=(10, 6))
for segment, color in SEGMENT_COLORS.items():
    subset = df[df["movement_segment"] == segment]
    subset_sizes = sizes[subset.index]
    plt.scatter(
        subset["inventory_turnover_proxy"], subset["avg_inventory"],
        s=subset_sizes, color=color, alpha=0.6, edgecolors="white",
        linewidth=1, label=segment,
    )
for _, row in df.iterrows():
    plt.annotate(row["product_id"], (row["inventory_turnover_proxy"], row["avg_inventory"]),
                 fontsize=6, ha="center", va="center")

plt.title("Fast vs Slow-Moving Products (from MySQL, bubble size = total units sold)")
plt.xlabel("Inventory Turnover Proxy")
plt.ylabel("Average Inventory")
plt.legend(title="Movement Segment")
plt.grid(alpha=0.3)
plt.tight_layout()
plt.savefig("fast_vs_slow_moving_products_from_db.png")
plt.show()
