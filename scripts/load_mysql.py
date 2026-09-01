import pandas as pd
import mysql.connector
from getpass import getpass
from pathlib import Path


# ============================================================
# Configuration
# ============================================================

CSV_PATH = Path("../data/processed/retail_store_inventory_clean.csv")

DB_HOST = "localhost"
DB_PORT = 3306
DB_USER = "root"
DB_NAME = "retail_inventory_db"


# ============================================================
# Load CSV
# ============================================================

print("Loading cleaned dataset...")

df = pd.read_csv(CSV_PATH)

print(f"Dataset shape: {df.shape}")

if df.shape != (73100, 15):
    raise ValueError(
        f"Unexpected dataset shape: {df.shape}. "
        "Expected (73100, 15)."
    )


# ============================================================
# Data preparation
# ============================================================

df["Date"] = pd.to_datetime(df["Date"]).dt.date

records = list(
    df[
        [
            "Date",
            "Store ID",
            "Product ID",
            "Category",
            "Region",
            "Inventory Level",
            "Units Sold",
            "Units Ordered",
            "Demand Forecast",
            "Price",
            "Discount",
            "Weather Condition",
            "Holiday/Promotion",
            "Competitor Pricing",
            "Seasonality",
        ]
    ].itertuples(index=False, name=None)
)

print(f"Prepared {len(records):,} records.")


# ============================================================
# Connect to MySQL
# ============================================================

password = getpass("Enter MySQL root password: ")

conn = mysql.connector.connect(
    host=DB_HOST,
    port=DB_PORT,
    user=DB_USER,
    password=password,
    database=DB_NAME,
)

cursor = conn.cursor()

print("Connected to MySQL.")


# ============================================================
# Insert query
# ============================================================

insert_query = """
INSERT INTO inventory_sales (
    date,
    store_id,
    product_id,
    category,
    region,
    inventory_level,
    units_sold,
    units_ordered,
    demand_forecast,
    price,
    discount,
    weather_condition,
    holiday_promotion,
    competitor_pricing,
    seasonality
)
VALUES (
    %s, %s, %s, %s, %s,
    %s, %s, %s, %s, %s,
    %s, %s, %s, %s, %s
)
"""


# ============================================================
# Load data
# ============================================================

try:

    # Remove any previously imported rows
    print("Clearing existing table data...")

    cursor.execute("TRUNCATE TABLE inventory_sales")
    conn.commit()

    # Insert in batches
    batch_size = 5000

    for start in range(0, len(records), batch_size):

        batch = records[start:start + batch_size]

        cursor.executemany(insert_query, batch)
        conn.commit()

        loaded = min(start + batch_size, len(records))

        print(f"Loaded {loaded:,} / {len(records):,} rows")

    print("\nData loading completed successfully!")


except Exception as e:

    conn.rollback()

    print("\nERROR:")
    print(e)

    raise


# ============================================================
# Verify
# ============================================================

cursor.execute("""
    SELECT COUNT(*)
    FROM inventory_sales
""")

row_count = cursor.fetchone()[0]

print(f"\nRows in MySQL: {row_count:,}")


# ============================================================
# Close connection
# ============================================================

cursor.close()
conn.close()

print("MySQL connection closed.")