-- ============================================================
-- RETAIL INVENTORY ANALYTICS PROJECT
-- analysis.sql
-- MySQL 8.0+
-- Database: retail_inventory_db
-- Table: inventory_sales
-- ============================================================

USE retail_inventory_db;


-- ============================================================
-- 1. DATA VALIDATION
-- ============================================================

-- 1.1 Row count
SELECT COUNT(*) AS total_rows
FROM inventory_sales;

-- 1.2 Date range and number of dates
SELECT
    MIN(date) AS earliest_date,
    MAX(date) AS latest_date,
    COUNT(DISTINCT date) AS unique_dates
FROM inventory_sales;

-- 1.3 Cardinality of major dimensions
SELECT
    COUNT(DISTINCT store_id) AS stores,
    COUNT(DISTINCT product_id) AS products,
    COUNT(DISTINCT category) AS categories,
    COUNT(DISTINCT region) AS regions
FROM inventory_sales;

-- 1.4 Check NULL values
SELECT
    SUM(date IS NULL) AS null_date,
    SUM(store_id IS NULL) AS null_store,
    SUM(product_id IS NULL) AS null_product,
    SUM(category IS NULL) AS null_category,
    SUM(region IS NULL) AS null_region,
    SUM(inventory_level IS NULL) AS null_inventory,
    SUM(units_sold IS NULL) AS null_units_sold,
    SUM(units_ordered IS NULL) AS null_units_ordered,
    SUM(demand_forecast IS NULL) AS null_forecast,
    SUM(price IS NULL) AS null_price,
    SUM(discount IS NULL) AS null_discount,
    SUM(weather_condition IS NULL) AS null_weather,
    SUM(holiday_promotion IS NULL) AS null_holiday,
    SUM(competitor_pricing IS NULL) AS null_competitor_price,
    SUM(seasonality IS NULL) AS null_seasonality
FROM inventory_sales;

-- 1.5 Check duplicate observations based on the primary business key
SELECT
    date,
    store_id,
    product_id,
    COUNT(*) AS duplicate_count
FROM inventory_sales
GROUP BY date, store_id, product_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 1.6 Check invalid / negative numerical values
SELECT
    SUM(inventory_level < 0) AS negative_inventory,
    SUM(units_sold < 0) AS negative_sales,
    SUM(units_ordered < 0) AS negative_orders,
    SUM(demand_forecast < 0) AS negative_forecasts,
    SUM(price < 0) AS negative_price,
    SUM(discount < 0) AS negative_discount,
    SUM(competitor_pricing < 0) AS negative_competitor_price
FROM inventory_sales;

-- 1.7 Check categorical distributions
SELECT category, COUNT(*) AS observations
FROM inventory_sales
GROUP BY category
ORDER BY observations DESC;

SELECT region, COUNT(*) AS observations
FROM inventory_sales
GROUP BY region
ORDER BY observations DESC;

SELECT weather_condition, COUNT(*) AS observations
FROM inventory_sales
GROUP BY weather_condition
ORDER BY observations DESC;

SELECT seasonality, COUNT(*) AS observations
FROM inventory_sales
GROUP BY seasonality
ORDER BY observations DESC;

-- 1.8 Check allowed discount values
SELECT DISTINCT discount
FROM inventory_sales
ORDER BY discount;

-- 1.9 Check allowed promotion values
SELECT DISTINCT holiday_promotion
FROM inventory_sales
ORDER BY holiday_promotion;


-- ============================================================
-- 2. DESCRIPTIVE STATISTICS
-- ============================================================

SELECT
    MIN(inventory_level) AS min_inventory,
    MAX(inventory_level) AS max_inventory,
    ROUND(AVG(inventory_level), 2) AS avg_inventory,
    ROUND(
        (SELECT AVG(x.inventory_level)
         FROM (
             SELECT inventory_level,
                    ROW_NUMBER() OVER (ORDER BY inventory_level) AS rn,
                    COUNT(*) OVER () AS cnt
             FROM inventory_sales
         ) x
         WHERE x.rn IN (FLOOR((x.cnt + 1) / 2), FLOOR((x.cnt + 2) / 2))
        ),
        2
    ) AS median_inventory,
    MIN(units_sold) AS min_units_sold,
    MAX(units_sold) AS max_units_sold,
    ROUND(AVG(units_sold), 2) AS avg_units_sold,
    MIN(units_ordered) AS min_units_ordered,
    MAX(units_ordered) AS max_units_ordered,
    ROUND(AVG(units_ordered), 2) AS avg_units_ordered,
    MIN(demand_forecast) AS min_demand_forecast,
    MAX(demand_forecast) AS max_demand_forecast,
    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    ROUND(AVG(price), 2) AS avg_price,
    MIN(discount) AS min_discount,
    MAX(discount) AS max_discount,
    ROUND(AVG(discount), 2) AS avg_discount
FROM inventory_sales;

-- Negative demand forecast diagnostics
SELECT
    COUNT(*) AS negative_forecast_rows,
    ROUND(AVG(demand_forecast), 2) AS avg_negative_forecast,
    MIN(demand_forecast) AS min_negative_forecast,
    MAX(demand_forecast) AS max_negative_forecast
FROM inventory_sales
WHERE demand_forecast < 0;

-- Negative forecast by category
SELECT
    category,
    COUNT(*) AS negative_forecast_rows
FROM inventory_sales
WHERE demand_forecast < 0
GROUP BY category
ORDER BY negative_forecast_rows DESC;

-- Negative forecast by seasonality
SELECT
    seasonality,
    COUNT(*) AS negative_forecast_rows
FROM inventory_sales
WHERE demand_forecast < 0
GROUP BY seasonality
ORDER BY negative_forecast_rows DESC;


-- ============================================================
-- 3. OVERALL BUSINESS KPIs
-- ============================================================

-- 3.1 Overall network KPIs
SELECT
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(AVG(inventory_level), 2) AS avg_inventory_level,
    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast
FROM inventory_sales;

-- 3.2 Inventory-to-sales ratio
SELECT
    ROUND(
        SUM(inventory_level) /
        NULLIF(SUM(units_sold), 0),
        2
    ) AS inventory_to_sales_ratio
FROM inventory_sales;

-- 3.3 Inventory turnover proxy
-- Uses average units sold / average inventory so both
-- numerator and denominator are on the same observation basis.
SELECT
    ROUND(
        AVG(units_sold) /
        NULLIF(AVG(inventory_level), 0),
        3
    ) AS inventory_turnover_proxy
FROM inventory_sales;


-- ============================================================
-- 3.4 STORE-LEVEL PERFORMANCE
-- ============================================================

SELECT
    store_id,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(AVG(inventory_level), 2) AS avg_inventory,
    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast,
    ROUND(
        AVG(units_sold) /
        NULLIF(AVG(inventory_level), 0),
        3
    ) AS inventory_turnover_proxy
FROM inventory_sales
GROUP BY store_id
ORDER BY total_units_sold DESC;


-- 3.4.1 Store ordering efficiency
SELECT
    store_id,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(
        SUM(units_ordered) /
        NULLIF(SUM(units_sold), 0),
        3
    ) AS order_to_sales_ratio,
    ROUND(
        100.0 * SUM(units_sold) /
        NULLIF(SUM(units_ordered), 0),
        2
    ) AS sales_to_order_pct
FROM inventory_sales
GROUP BY store_id
ORDER BY order_to_sales_ratio DESC;


-- ============================================================
-- 3.5 CATEGORY-LEVEL PERFORMANCE
-- ============================================================

SELECT
    category,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(AVG(inventory_level), 2) AS avg_inventory,
    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast,
    ROUND(
        AVG(units_sold) /
        NULLIF(AVG(inventory_level), 0),
        3
    ) AS inventory_turnover_proxy
FROM inventory_sales
GROUP BY category
ORDER BY total_units_sold DESC;


-- ============================================================
-- 3.6 PRODUCT-LEVEL PERFORMANCE
-- ============================================================

-- IMPORTANT:
-- Product IDs occur across multiple categories in this dataset.
-- Therefore, product-level analysis groups only by product_id.

SELECT
    product_id,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(AVG(inventory_level), 2) AS avg_inventory,
    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast,
    ROUND(
        AVG(units_sold) /
        NULLIF(AVG(inventory_level), 0),
        3
    ) AS inventory_turnover_proxy
FROM inventory_sales
GROUP BY product_id
ORDER BY total_units_sold DESC;


-- ============================================================
-- 3.7 INVENTORY COVERAGE
-- ============================================================

-- Average inventory coverage using only valid positive forecasts.
-- Coverage = inventory / demand forecast

SELECT
    ROUND(
        AVG(
            inventory_level /
            NULLIF(demand_forecast, 0)
        ),
        2
    ) AS avg_inventory_coverage
FROM inventory_sales
WHERE demand_forecast > 0;


-- ============================================================
-- 3.8 INVENTORY RISK DISTRIBUTION
-- ============================================================

-- Risk thresholds:
-- < 1x forecast  = Understocked
-- 1-2x forecast  = Balanced
-- 2-4x forecast  = High Inventory
-- >= 4x forecast = Excess Inventory

SELECT
    CASE
        WHEN inventory_level / NULLIF(demand_forecast, 0) < 1
            THEN 'Understocked'
        WHEN inventory_level / NULLIF(demand_forecast, 0) < 2
            THEN 'Balanced'
        WHEN inventory_level / NULLIF(demand_forecast, 0) < 4
            THEN 'High Inventory'
        ELSE 'Excess Inventory'
    END AS inventory_risk,
    COUNT(*) AS observations,
    ROUND(
        100.0 * COUNT(*) / (
            SELECT COUNT(*)
            FROM inventory_sales
            WHERE demand_forecast > 0
        ),
        2
    ) AS percentage
FROM inventory_sales
WHERE demand_forecast > 0
GROUP BY inventory_risk
ORDER BY
    CASE inventory_risk
        WHEN 'Understocked' THEN 1
        WHEN 'Balanced' THEN 2
        WHEN 'High Inventory' THEN 3
        WHEN 'Excess Inventory' THEN 4
    END;


-- ============================================================
-- 3.9 INVENTORY RISK BY STORE
-- ============================================================

SELECT
    store_id,
    COUNT(*) AS valid_observations,

    SUM(
        CASE
            WHEN inventory_level / NULLIF(demand_forecast, 0) >= 2
            THEN 1
            ELSE 0
        END
    ) AS high_inventory_observations,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN inventory_level / NULLIF(demand_forecast, 0) >= 2
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS high_inventory_pct

FROM inventory_sales
WHERE demand_forecast > 0
GROUP BY store_id
ORDER BY high_inventory_pct DESC;


-- ============================================================
-- 3.10 INVENTORY RISK BY CATEGORY
-- ============================================================

SELECT
    category,
    COUNT(*) AS valid_observations,

    SUM(
        CASE
            WHEN inventory_level / NULLIF(demand_forecast, 0) >= 2
            THEN 1
            ELSE 0
        END
    ) AS high_inventory_observations,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN inventory_level / NULLIF(demand_forecast, 0) >= 2
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS high_inventory_pct

FROM inventory_sales
WHERE demand_forecast > 0
GROUP BY category
ORDER BY high_inventory_pct DESC;


-- ============================================================
-- 3.11 INVENTORY RISK BY PRODUCT
-- ============================================================

SELECT
    product_id,
    COUNT(*) AS valid_observations,

    ROUND(AVG(inventory_level), 2) AS avg_inventory,
    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast,

    SUM(
        CASE
            WHEN inventory_level / NULLIF(demand_forecast, 0) >= 2
            THEN 1
            ELSE 0
        END
    ) AS high_inventory_observations,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN inventory_level / NULLIF(demand_forecast, 0) >= 2
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS high_inventory_pct

FROM inventory_sales
WHERE demand_forecast > 0
GROUP BY product_id
ORDER BY high_inventory_pct DESC;


-- ============================================================
-- 3.12 DEMAND FORECAST ACCURACY
-- ============================================================

-- Negative forecasts are excluded because demand cannot be negative.
-- Zero-sales observations are excluded from MAPE to avoid division by zero.

SELECT
    ROUND(
        AVG(ABS(units_sold - demand_forecast)),
        2
    ) AS mae,

    ROUND(
        SQRT(
            AVG(
                POW(units_sold - demand_forecast, 2)
            )
        ),
        2
    ) AS rmse,

    ROUND(
        AVG(
            ABS(units_sold - demand_forecast) /
            NULLIF(units_sold, 0)
        ) * 100,
        2
    ) AS mape

FROM inventory_sales
WHERE demand_forecast >= 0
  AND units_sold > 0;


-- 3.13  Forecast Accuracy by Store

SELECT
    store_id,

    COUNT(*) AS observations,

    ROUND(
        AVG(ABS(units_sold - demand_forecast)),
        2
    ) AS mae,

    ROUND(
        SQRT(
            AVG(
                POW(units_sold - demand_forecast, 2)
            )
        ),
        2
    ) AS rmse,

    ROUND(
        AVG(
            ABS(units_sold - demand_forecast) /
            NULLIF(units_sold, 0)
        ) * 100,
        2
    ) AS mape

FROM inventory_sales
WHERE demand_forecast >= 0
  AND units_sold > 0

GROUP BY store_id
ORDER BY mae DESC;

-- 3.14 — Forecast Accuracy by Category

SELECT
    category,

    COUNT(*) AS observations,

    ROUND(
        AVG(ABS(units_sold - demand_forecast)),
        2
    ) AS mae,

    ROUND(
        SQRT(
            AVG(
                POW(units_sold - demand_forecast, 2)
            )
        ),
        2
    ) AS rmse,

    ROUND(
        AVG(
            ABS(units_sold - demand_forecast) /
            NULLIF(units_sold, 0)
        ) * 100,
        2
    ) AS mape

FROM inventory_sales
WHERE demand_forecast >= 0
  AND units_sold > 0

GROUP BY category
ORDER BY mae DESC;

-- 3.15  — Find the Worst Store × Category Segments

SELECT
    store_id,
    category,

    COUNT(*) AS observations,

    ROUND(
        AVG(ABS(units_sold - demand_forecast)),
        2
    ) AS mae,

    ROUND(
        SQRT(
            AVG(
                POW(units_sold - demand_forecast, 2)
            )
        ),
        2
    ) AS rmse,

    ROUND(
        AVG(
            ABS(units_sold - demand_forecast) /
            NULLIF(units_sold, 0)
        ) * 100,
        2
    ) AS mape

FROM inventory_sales

WHERE demand_forecast >= 0
  AND units_sold > 0

GROUP BY
    store_id,
    category

ORDER BY mae DESC;

-- 3.16 — Connect Forecast Accuracy With Inventory Risk

SELECT
    inventory_risk,
    COUNT(*) AS observations,

    ROUND(
        AVG(ABS(units_sold - demand_forecast)),
        2
    ) AS mae,

    ROUND(
        SQRT(
            AVG(
                POW(units_sold - demand_forecast, 2)
            )
        ),
        2
    ) AS rmse,

    ROUND(
        AVG(
            ABS(units_sold - demand_forecast) /
            NULLIF(units_sold, 0)
        ) * 100,
        2
    ) AS mape

FROM (
    SELECT
        *,
        CASE
            WHEN inventory_level < demand_forecast
                THEN 'Understocked'

            WHEN inventory_level <= demand_forecast * 1.5
                THEN 'Balanced'

            WHEN inventory_level <= demand_forecast * 2
                THEN 'High Inventory'

            ELSE 'Excess Inventory'
        END AS inventory_risk

    FROM inventory_sales

    WHERE demand_forecast >= 0
      AND units_sold > 0
) AS classified_data

GROUP BY inventory_risk
ORDER BY
    CASE inventory_risk
        WHEN 'Understocked' THEN 1
        WHEN 'Balanced' THEN 2
        WHEN 'High Inventory' THEN 3
        WHEN 'Excess Inventory' THEN 4
    END;



-- 3.17 — Investigate Understocked Segments

SELECT
    store_id,
    category,

    COUNT(*) AS understocked_observations,

    ROUND(
        AVG(inventory_level),
        2
    ) AS avg_inventory,

    ROUND(
        AVG(demand_forecast),
        2
    ) AS avg_demand_forecast,

    ROUND(
        AVG(units_sold),
        2
    ) AS avg_units_sold,

    ROUND(
        AVG(demand_forecast - inventory_level),
        2
    ) AS avg_inventory_gap

FROM inventory_sales

WHERE demand_forecast >= 0
  AND inventory_level < demand_forecast

GROUP BY
    store_id,
    category

ORDER BY
    understocked_observations DESC;


-- 3.18 — Analyze Excess Inventory

SELECT
    store_id,
    category,

    COUNT(*) AS excess_inventory_observations,

    ROUND(
        AVG(inventory_level),
        2
    ) AS avg_inventory,

    ROUND(
        AVG(demand_forecast),
        2
    ) AS avg_demand_forecast,

    ROUND(
        AVG(inventory_level - demand_forecast),
        2
    ) AS avg_inventory_surplus

FROM inventory_sales

WHERE demand_forecast >= 0
  AND inventory_level > demand_forecast * 2

GROUP BY
    store_id,
    category

ORDER BY
    excess_inventory_observations DESC;


-- 3.19 — Demand Drivers

SELECT
    discount,

    COUNT(*) AS observations,

    ROUND(AVG(units_sold), 2) AS avg_units_sold,

    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast,

    ROUND(AVG(price), 2) AS avg_price

FROM inventory_sales

WHERE demand_forecast >= 0

GROUP BY discount
ORDER BY discount;



-- 3.20 — Holiday / Promotion Impact

SELECT
    holiday_promotion,

    COUNT(*) AS observations,

    ROUND(AVG(units_sold), 2) AS avg_units_sold,

    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast,

    ROUND(AVG(inventory_level), 2) AS avg_inventory

FROM inventory_sales

WHERE demand_forecast >= 0

GROUP BY holiday_promotion
ORDER BY holiday_promotion;


-- 3.21 — Seasonality Analysis

SELECT
    seasonality,

    COUNT(*) AS observations,

    ROUND(AVG(units_sold), 2) AS avg_units_sold,

    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast,

    ROUND(AVG(inventory_level), 2) AS avg_inventory,

    ROUND(AVG(units_ordered), 2) AS avg_units_ordered

FROM inventory_sales

WHERE demand_forecast >= 0

GROUP BY seasonality

ORDER BY avg_units_sold DESC;

-- Weather impact on sales and inventory

SELECT
    weather_condition,

    COUNT(*) AS observations,

    ROUND(AVG(units_sold), 2) AS avg_units_sold,

    ROUND(AVG(demand_forecast), 2) AS avg_demand_forecast,

    ROUND(AVG(inventory_level), 2) AS avg_inventory,

    ROUND(AVG(units_ordered), 2) AS avg_units_ordered

FROM inventory_sales

WHERE demand_forecast >= 0

GROUP BY weather_condition

ORDER BY avg_units_sold DESC;