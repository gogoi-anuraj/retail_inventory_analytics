# Data Dictionary — Retail Inventory Analytics

**Table:** `inventory_sales` · **Grain:** one row per `Date + Store ID + Product ID`
**Source file:** `data/raw/retail_store_inventory.csv` → cleaned to
`data/processed/retail_store_inventory_clean.csv`
**Rows:** 73,100 · **Date range:** 2022-01-01 to 2024-01-01 (731 unique dates)

For each column below: the raw CSV name, the SQL column name (`inventory_sales`
table), data type, business meaning, valid range/values as observed in the
**cleaned** dataset, and any cleaning applied.

---

| CSV Column | SQL Column | Type (SQL) | Description | Valid Range / Values (cleaned) | Cleaning Notes |
|---|---|---|---|---|---|
| `Date` | `date` | `DATE` | Calendar date of the observation. | 2022-01-01 to 2024-01-01 (731 unique dates) | Parsed from string to date type; 0 invalid dates found. |
| `Store ID` | `store_id` | `VARCHAR(10)` | Identifier for the physical store. | `S001`–`S005` (5 stores) | None needed. |
| `Product ID` | `product_id` | `VARCHAR(10)` | Identifier for the product/SKU. | `P0001`–`P0020` (20 products) | None needed for cleaning, but **important for analysis**: every one of the 20 Product IDs appears under all 5 Category values in this dataset (verified) — `Product ID` and `Category` are not a stable 1:1 mapping here. Product-level analysis in this project groups by `product_id` only, never `product_id + category`, to avoid implying products belong to a single category. |
| `Category` | `category` | `VARCHAR(50)` | Product category grouping. | `Clothing`, `Electronics`, `Furniture`, `Groceries`, `Toys` (5 categories) | None needed. |
| `Region` | `region` | `VARCHAR(50)` | Sales region the store belongs to. | `East`, `North`, `South`, `West` (4 regions) | None needed. |
| `Inventory Level` | `inventory_level` | `INT` | Units of the product physically in stock at this store on this date (end-of-day snapshot, as provided — the dataset does not document the exact measurement time). | 50 – 500 | None needed. No negative or missing values found. |
| `Units Sold` | `units_sold` | `INT` | Units of the product sold at this store on this date. | 0 – 499 | None needed. 360 rows have `Units Sold = 0` (no sales that day) — retained, not treated as missing. |
| `Units Ordered` | `units_ordered` | `INT` | Units of the product ordered (replenishment order placed) at this store on this date. This is an order quantity, not a confirmed receipt — the dataset has no stock-receipt date. | 20 – 200 | None needed. |
| `Demand Forecast` | `demand_forecast` | `DECIMAL(10,2)` | System-generated forecast of expected demand for this store-product-date. | 0.00 – 518.55 (raw data ranged down to **-9.99**) | **673 rows (0.92%) had negative values** in the raw data, ranging from -9.99 to -0.01. Negative demand is not meaningful, so these were clipped to 0 (`GREATEST(demand_forecast, 0)` equivalent). See `outputs/data_quality_summary.md` for the investigation that preceded this decision. |
| `Price` | `price` | `DECIMAL(10,2)` | Selling price of the product on this date. | 10.00 – 100.00 | None needed. |
| `Discount` | `discount` | `INT` | Discount percentage applied, as a whole number. | One of `{0, 5, 10, 15, 20}` | None needed. Discrete/categorical in practice despite being stored as INT. |
| `Weather Condition` | `weather_condition` | `VARCHAR(30)` | Recorded weather condition for the store's location on this date. | `Cloudy`, `Rainy`, `Snowy`, `Sunny` (4 conditions) | None needed. |
| `Holiday/Promotion` | `holiday_promotion` | `TINYINT` | Flag indicating whether this date was a holiday or promotional period for this store-product. | `0` (no) or `1` (yes) | None needed. Binary flag; ~49.7% of rows are flagged `1`. |
| `Competitor Pricing` | `competitor_pricing` | `DECIMAL(10,2)` | A competitor's price for a comparable product on this date. | 5.03 – 104.94 | None needed. |
| `Seasonality` | `seasonality` | `VARCHAR(20)` | Season label for the date. | `Autumn`, `Spring`, `Summer`, `Winter` (4 seasons) | None needed. |

---

## Derived / Analysis Columns

These are **not** in the raw dataset — they are computed during analysis and
documented here so their definitions stay consistent across
`analysis.sql`, the notebooks, and the Streamlit dashboard.

| Column | Formula | Description |
|---|---|---|
| `Risk Status` / `inventory_risk` | See tiers below | 4-tier inventory risk classification. **Understocked**: `inventory_level < demand_forecast`. **Balanced**: `inventory_level <= 1.5 × demand_forecast`. **High Inventory**: `inventory_level <= 2.0 × demand_forecast`. **Excess Inventory**: `inventory_level > 2.0 × demand_forecast`. This is a **risk indicator**, not a confirmed stockout or excess-cost measurement — the dataset has no stockout flag or holding-cost data. |
| `overstock_risk` (Phase 7, notebook only) | `inventory_level > 1.5 × demand_forecast` | A separate, more lenient binary overstock flag used specifically in the Phase 7 overstock analysis. Intentionally distinct from `Risk Status` above — do not treat "Excess Inventory" and `overstock_risk = True` as the same threshold. |
| `inventory_turnover_proxy` | `AVG(units_sold) / AVG(inventory_level)` (or `SUM(units_sold) / (AVG(inventory_level) × days)`, equivalent) | **Unit-based turnover proxy**, not standard accounting inventory turnover (which requires COGS). Higher = faster-moving. |
| `movement_segment` | Tercile split of `inventory_turnover_proxy` via `NTILE(3)` / `pd.qcut` | `Fast-moving`, `Medium-moving`, or `Slow-moving`. Note: differentiation is weak in this dataset (turnover proxy ranges only ~0.49–0.51 across all 20 products) — treat as directional, not a strong signal (see `outputs/recommendations.md` #5). |
| `reorder_trigger` | `inventory_level < demand_forecast` | Boolean flag for whether a store-product combination should be reordered "today." Same logic as the `Understocked` tier. |
| `recommended_order_qty` | `GREATEST(demand_forecast × 1.10 - inventory_level, 0)`, only when `reorder_trigger = True` | Simple replenishment quantity with a 10% buffer over forecast, applied only once the reorder trigger has fired. Not a lead-time-based reorder point — no supplier lead-time data exists. The 10% buffer is a documented assumption, informally motivated by the ~23% average forecast error (MAPE) observed in this dataset. |
| `Forecast Error` | `units_sold - demand_forecast` | Signed error; positive means actual sales exceeded the forecast. |
| `Absolute Forecast Error` / MAE | `ABS(units_sold - demand_forecast)`, averaged | Mean Absolute Error of the demand forecast. |
| `MAPE` | `AVG(ABS(units_sold - demand_forecast) / units_sold) × 100`, where `units_sold > 0` | Mean Absolute Percentage Error. Zero-sales rows are excluded to avoid division by zero — see caveat in `analysis.sql` §3.12. |

---

## Business Key

`Date + Store ID + Product ID` uniquely identifies each row. Verified unique
across all 73,100 rows (0 duplicate combinations found), and enforced as the
composite `PRIMARY KEY` in `schema.sql`.

## Known Data Constraints (not in this dataset)

Per the original project scope, the following do **not** exist in this data
and are not referenced anywhere in the analysis: supplier information,
supplier lead times, warehouse/location capacity, purchase cost or COGS,
an explicit stockout flag, and historical stock receipt dates.