-- ============================================================
-- Trend-Based Reorder Point Estimation (Phase 8 revision)
-- ============================================================
-- This satisfies the PS requirement "Reorder Point Estimation using
-- historical trends" properly — unlike the original Phase 8 query in
-- this project, which reused the dataset's given `Demand Forecast`
-- column with a flat 10% buffer. This version derives the reorder point
-- independently from each store-product's own historical sales pattern.
--
-- Formula (standard safety-stock reorder point):
--   reorder_point = (avg_daily_sales x lead_time_days)
--                  + Z x stddev_daily_sales x SQRT(lead_time_days)
--
-- Assumptions (explicitly documented, since no real supplier lead-time
-- data exists in this dataset):
--   - lead_time_days = 1. IMPORTANT: this was NOT the first value tried.
--     A textbook default of 7 days was tried first and rejected, because
--     it produced every single store-product combination (100/100) as
--     "Below Reorder Point" — a red flag, not a real finding. Checking
--     why: avg daily units ordered (110) is nearly as large as avg daily
--     units sold (136.5), and avg inventory level (274) covers only
--     ~2 days of average sales. That pattern only makes sense if this
--     business replenishes on a near-daily cadence, not a 7-day one — so
--     the lead time was corrected to 1 day to match what the data
--     actually implies, rather than keeping a textbook default that
--     contradicted the evidence.
--   - Z = 1.65, the standard z-score for a ~95% cycle service level
--     (textbook safety-stock convention), not tuned to this data.
--   - Trailing 90-day window (not full 2-year history), so the estimate
--     reflects recent demand rather than smoothing over 2 years of
--     seasonal variation.
-- ============================================================

USE retail_inventory_db;

WITH RecentSales AS (
    SELECT
        store_id,
        product_id,
        units_sold
    FROM inventory_sales_normalized
    WHERE date > (SELECT MAX(date) FROM inventory_sales_normalized) - INTERVAL 90 DAY
),
SalesStats AS (
    SELECT
        store_id,
        product_id,
        AVG(units_sold) AS avg_daily_sales,
        STDDEV(units_sold) AS stddev_daily_sales,
        COUNT(*) AS days_observed
    FROM RecentSales
    GROUP BY store_id, product_id
),
LatestInventory AS (
    SELECT f.store_id, f.product_id, f.inventory_level, f.demand_forecast
    FROM inventory_sales_normalized f
    WHERE f.date = (SELECT MAX(date) FROM inventory_sales_normalized)
)
SELECT
    li.store_id,
    li.product_id,
    li.inventory_level AS current_stock,
    ROUND(st.avg_daily_sales, 2) AS avg_daily_sales_90d,
    ROUND(st.stddev_daily_sales, 2) AS stddev_daily_sales_90d,
    ROUND(st.avg_daily_sales * 1, 1) AS lead_time_demand,
    ROUND(1.65 * COALESCE(st.stddev_daily_sales, 0) * SQRT(1), 1) AS safety_stock,
    ROUND(
        (st.avg_daily_sales * 1) + (1.65 * COALESCE(st.stddev_daily_sales, 0) * SQRT(1)),
        0
    ) AS reorder_point_trend_based,
    li.demand_forecast AS given_demand_forecast,
    CASE
        WHEN li.inventory_level <= 0 THEN 'Out of Stock'
        WHEN li.inventory_level < (
            (st.avg_daily_sales * 1) + (1.65 * COALESCE(st.stddev_daily_sales, 0) * SQRT(1))
        ) THEN 'Below Reorder Point'
        ELSE 'Adequate Stock'
    END AS stock_status
FROM LatestInventory li
JOIN SalesStats st ON li.store_id = st.store_id AND li.product_id = st.product_id
ORDER BY
    CASE
        WHEN li.inventory_level <= 0 THEN 1
        WHEN li.inventory_level < (
            (st.avg_daily_sales * 1) + (1.65 * COALESCE(st.stddev_daily_sales, 0) * SQRT(1))
        ) THEN 2
        ELSE 3
    END,
    li.store_id, li.product_id;