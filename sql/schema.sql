CREATE DATABASE IF NOT EXISTS retail_inventory_db;

USE retail_inventory_db;

DROP TABLE IF EXISTS inventory_sales;

CREATE TABLE inventory_sales (
    date DATE NOT NULL,
    store_id VARCHAR(10) NOT NULL,
    product_id VARCHAR(10) NOT NULL,
    category VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL,
    inventory_level INT NOT NULL,
    units_sold INT NOT NULL,
    units_ordered INT NOT NULL,
    demand_forecast DECIMAL(10, 2) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    discount INT NOT NULL,
    weather_condition VARCHAR(30) NOT NULL,
    holiday_promotion TINYINT NOT NULL,
    competitor_pricing DECIMAL(10, 2) NOT NULL,
    seasonality VARCHAR(20) NOT NULL,

    PRIMARY KEY (date, store_id, product_id)
);


