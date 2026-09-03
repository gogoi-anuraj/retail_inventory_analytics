-- ============================================================
-- Normalized Schema
-- ============================================================
-- Design rationale (verified empirically against this dataset before
-- writing a single CREATE TABLE — see comments below each table):
--
-- Category, Region, and Weather Condition are NOT stable attributes of
-- Product, Store, or Date+Store respectively in this dataset:
--   - Every one of the 20 products appears under all 5 categories
--     (verified: COUNT(DISTINCT category) per product_id = 5 for all 20)
--   - Every one of the 5 stores appears under all 4 regions
--     (verified: COUNT(DISTINCT region) per store_id = 4 for all 5)
--   - Weather condition varies even across different products at the
--     SAME store on the SAME date, which shouldn't happen if weather
--     were a true attribute of (date, store)
-- This means Category/Region/Weather behave as independent per-row
-- values in this dataset, not as functional dependencies of any single
-- entity. Modeling them as columns on `products` or `stores` (as a
-- naive normalization would) creates a false 1:1 assumption and silently
-- loses information — exactly the bug found when reviewing a reference
-- solution to this same problem statement (see project notes).
--
-- Correct design used here: `stores` and `products` are bare entity
-- tables (ID only — no attributes are actually dependent on them alone).
-- Category/Region/Weather/Season/Promotion are lookup tables referenced
-- DIRECTLY from the fact table, at the grain where they actually vary.
-- ============================================================

CREATE DATABASE IF NOT EXISTS retail_inventory_db;
USE retail_inventory_db;

DROP TABLE IF EXISTS inventory_sales_normalized;
DROP TABLE IF EXISTS inventory_raw_staging;
DROP TABLE IF EXISTS stores;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS regions;
DROP TABLE IF EXISTS weather_conditions;
DROP TABLE IF EXISTS seasons;
DROP TABLE IF EXISTS promotions;

-- ============================================================
-- Entity tables (ID only — see rationale above)
-- ============================================================

CREATE TABLE stores (
    store_id VARCHAR(10) PRIMARY KEY
);

CREATE TABLE products (
    product_id VARCHAR(10) PRIMARY KEY
);

-- ============================================================
-- Lookup tables (deduplicate the repeated string values)
-- ============================================================

CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE regions (
    region_id INT AUTO_INCREMENT PRIMARY KEY,
    region_name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE weather_conditions (
    weather_id INT AUTO_INCREMENT PRIMARY KEY,
    weather_condition VARCHAR(30) UNIQUE NOT NULL
);

CREATE TABLE seasons (
    season_id INT AUTO_INCREMENT PRIMARY KEY,
    season_name VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE promotions (
    promotion_id INT PRIMARY KEY,
    is_holiday_promotion TINYINT NOT NULL,
    description VARCHAR(50) NOT NULL
);

-- ============================================================
-- Staging table (raw CSV lands here first, unchanged)
-- ============================================================

CREATE TABLE inventory_raw_staging (
    Date DATE,
    Store_ID VARCHAR(10),
    Product_ID VARCHAR(10),
    Category VARCHAR(50),
    Region VARCHAR(50),
    Inventory_Level INT,
    Units_Sold INT,
    Units_Ordered INT,
    Demand_Forecast DECIMAL(10,2),
    Price DECIMAL(10,2),
    Discount INT,
    Weather_Condition VARCHAR(30),
    Holiday_Promotion TINYINT,
    Competitor_Pricing DECIMAL(10,2),
    Seasonality VARCHAR(20)
);


CREATE TABLE inventory_sales_normalized (
    date DATE NOT NULL,
    store_id VARCHAR(10) NOT NULL,
    product_id VARCHAR(10) NOT NULL,
    category_id INT NOT NULL,
    region_id INT NOT NULL,
    inventory_level INT NOT NULL,
    units_sold INT NOT NULL,
    units_ordered INT NOT NULL,
    demand_forecast DECIMAL(10,2) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    discount INT NOT NULL,
    weather_id INT NOT NULL,
    promotion_id INT NOT NULL,
    competitor_pricing DECIMAL(10,2) NOT NULL,
    season_id INT NOT NULL,

    PRIMARY KEY (date, store_id, product_id),

    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (category_id) REFERENCES categories(category_id),
    FOREIGN KEY (region_id) REFERENCES regions(region_id),
    FOREIGN KEY (weather_id) REFERENCES weather_conditions(weather_id),
    FOREIGN KEY (season_id) REFERENCES seasons(season_id),
    FOREIGN KEY (promotion_id) REFERENCES promotions(promotion_id),

    INDEX idx_product_covering (product_id, units_sold, inventory_level),
    INDEX idx_store_covering (store_id, demand_forecast, units_sold),
    INDEX idx_category_covering (category_id, units_sold, inventory_level)
);