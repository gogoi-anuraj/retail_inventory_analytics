"""
Store x Category Heatmap (avg units sold) — SQL pivots via conditional
aggregation, Python just draws the grid.
"""

import pandas as pd
import matplotlib.pyplot as plt
from db_connection import get_connection

conn = get_connection()
if conn is None:
    exit(1)

# SQL does the store x category pivot directly with conditional AVG(),
# so Python receives one row per store, already shaped for a heatmap.
query = """
SELECT
    store_id,
    ROUND(AVG(CASE WHEN category = 'Clothing' THEN units_sold END), 1) AS Clothing,
    ROUND(AVG(CASE WHEN category = 'Electronics' THEN units_sold END), 1) AS Electronics,
    ROUND(AVG(CASE WHEN category = 'Furniture' THEN units_sold END), 1) AS Furniture,
    ROUND(AVG(CASE WHEN category = 'Groceries' THEN units_sold END), 1) AS Groceries,
    ROUND(AVG(CASE WHEN category = 'Toys' THEN units_sold END), 1) AS Toys
FROM inventory_sales
GROUP BY store_id
ORDER BY store_id;
"""

df = pd.read_sql(query, conn)
conn.close()

df = df.set_index("store_id")

fig, ax = plt.subplots(figsize=(9, 5))
im = ax.imshow(df.values, cmap="Blues", aspect="auto")

ax.set_xticks(range(len(df.columns)))
ax.set_xticklabels(df.columns)
ax.set_yticks(range(len(df.index)))
ax.set_yticklabels(df.index)

for i in range(df.shape[0]):
    for j in range(df.shape[1]):
        value = df.values[i, j]
        text_color = "white" if value > df.values.mean() else "black"
        ax.text(j, i, f"{value:.0f}", ha="center", va="center", color=text_color)

ax.set_title("Average Units Sold: Store x Category Heatmap (from MySQL)")
fig.colorbar(im, ax=ax, label="Avg Units Sold")
plt.tight_layout()
plt.savefig("store_category_heatmap_from_db.png")
plt.show()
