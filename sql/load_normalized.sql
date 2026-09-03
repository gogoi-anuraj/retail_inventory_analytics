-- ============================================================
-- ETL: populate the normalized schema from the raw CSV
-- Run this AFTER schema_normalized.sql
--
-- IMPORTANT (found when testing against real MySQL 8.0, not just
-- MariaDB): MySQL defaults `local_infile` to OFF, unlike MariaDB which
-- defaults it to ON. LOAD DATA LOCAL INFILE below will fail with
-- "Loading local data is disabled" unless BOTH of these are true:
--   1. Server-side: SET GLOBAL local_infile = 1;
--      (or add `local_infile=1` under [mysqld] in my.cnf to persist
--      it across restarts — a session-only SET GLOBAL resets on restart)
--   2. Client-side: run mysql with --local-infile=1
-- ============================================================

USE retail_inventory_db;

-- 1. Load raw CSV into staging, unchanged
LOAD DATA LOCAL INFILE '/home/claude/retail_inventory_analytics/data/raw/retail_store_inventory.csv'
INTO TABLE inventory_raw_staging
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Date, Store_ID, Product_ID, Category, Region, Inventory_Level, Units_Sold,
 Units_Ordered, Demand_Forecast, Price, Discount, Weather_Condition,
 Holiday_Promotion, Competitor_Pricing, Seasonality);

-- Clip negative Demand_Forecast to 0, same cleaning decision as Phase 1
UPDATE inventory_raw_staging SET Demand_Forecast = 0 WHERE Demand_Forecast < 0;

-- 2. Populate entity tables — ID only, deduplicated
INSERT INTO stores (store_id)
SELECT DISTINCT Store_ID FROM inventory_raw_staging;

INSERT INTO products (product_id)
SELECT DISTINCT Product_ID FROM inventory_raw_staging;

-- 3. Populate lookup tables — deduplicated string values.
-- These are NOT grouped by product_id or store_id (that was the bug in
-- the reference solution) — they're deduplicated on the string value
-- alone, since that's the only thing these tables represent.
INSERT INTO categories (category_name)
SELECT DISTINCT Category FROM inventory_raw_staging;

INSERT INTO regions (region_name)
SELECT DISTINCT Region FROM inventory_raw_staging;

INSERT INTO weather_conditions (weather_condition)
SELECT DISTINCT Weather_Condition FROM inventory_raw_staging;

INSERT INTO seasons (season_name)
SELECT DISTINCT Seasonality FROM inventory_raw_staging;

INSERT INTO promotions (promotion_id, is_holiday_promotion, description) VALUES
(0, 0, 'No Promotion'),
(1, 1, 'Holiday Promotion');

-- 4. Populate the fact table — every lookup is joined at the ROW level
-- (i.e. resolved per Date+Store+Product, not derived from a dimension
-- table), because that's the grain these attributes actually vary at.
INSERT INTO inventory_sales_normalized (
    date, store_id, product_id, category_id, region_id, inventory_level,
    units_sold, units_ordered, demand_forecast, price, discount,
    weather_id, promotion_id, competitor_pricing, season_id
)
SELECT
    r.Date, r.Store_ID, r.Product_ID,
    c.category_id, rg.region_id,
    r.Inventory_Level, r.Units_Sold, r.Units_Ordered, r.Demand_Forecast,
    r.Price, r.Discount, w.weather_id, r.Holiday_Promotion,
    r.Competitor_Pricing, s.season_id
FROM inventory_raw_staging r
JOIN categories c ON r.Category = c.category_name
JOIN regions rg ON r.Region = rg.region_name
JOIN weather_conditions w ON r.Weather_Condition = w.weather_condition
JOIN seasons s ON r.Seasonality = s.season_name;

-- 5. Verification queries — run these and confirm before trusting the load
SELECT COUNT(*) AS staging_rows FROM inventory_raw_staging;
SELECT COUNT(*) AS fact_rows FROM inventory_sales_normalized;
-- These two counts must match. If fact_rows < staging_rows, an INNER JOIN
-- above silently dropped rows (e.g. a lookup value that didn't match) —
-- investigate before proceeding, don't assume it's fine.

SELECT COUNT(DISTINCT category_id) AS distinct_categories_used FROM inventory_sales_normalized;
-- Must be 5. If it's 1, the same bug as the reference solution has
-- reoccurred somewhere in this pipeline.