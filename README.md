 # Retail Inventory Analytics

An end-to-end SQL + Python analytics project on a two-year, multi-store
retail inventory dataset — from raw-data cleaning through SQL analysis, a
Streamlit dashboard, and business recommendations.

**Business question:** Where are the biggest inventory inefficiencies, which
products/stores are at risk, and what inventory actions should the business
take?

---

## Project Structure

```
retail_inventory_analytics/
├── data/
│   ├── raw/retail_store_inventory.csv              # original dataset, untouched
│   └── processed/retail_store_inventory_clean.csv  # cleaned dataset used everywhere downstream
├── notebook/
│   ├── data_cleaning.ipynb    # Phase 1 — profiling, quality checks, cleaning decisions
│   ├── analysis.ipynb         # Phases 3-9 — KPIs, risk, segmentation, reorder, forecast accuracy
│   └── load_mysql.ipynb       # loads the cleaned CSV into MySQL
├── scripts/
│   └── load_mysql.py          # same load logic as load_mysql.ipynb, as a plain script
├── sql/
│   ├── schema.sql                 # original flat schema + validated covering indexes
│   ├── schema_normalized.sql      # normalized schema: entity + lookup tables + fact table
│   ├── load_normalized.sql        # ETL: raw CSV → staging → normalized schema
│   ├── analysis.sql               # all SQL analysis queries (KPIs, risk, segmentation, reorder)
│   └── reorder_point_trend.sql    # historical-trend reorder point (safety-stock formula)
├── dashboard/
│   └── app.py                 # Streamlit dashboard (4 panels, Plotly charts)
├── erd/
│   ├── inventory_schema.png             # flat-schema diagram
│   └── inventory_schema_normalized.png  # normalized multi-table diagram
├── plots/
│   └── PNGs                # curated static charts, one per key finding — see plots/README.md
├── plots_from_db/
│   ├── db_connection.py       # shared MySQL connection (mysql.connector)
│   └── 4 scripts              # same charts as plots/, but queried live from MySQL instead of the CSV
├── outputs/
│   ├── data_quality_summary.md   # cleaning decisions and their justification
│   ├── data_dictionary.md        # every column: type, meaning, valid range, cleaning notes
│   ├── recommendations.md        # 5 business recommendations (Problem/Evidence/Action/Benefit/Risk)
│   └── executive_summary.md      # summary: findings, actions, limitations
└── requirements-dev.txt          
```

---

## The Dataset

73,100 daily observations · 5 stores (`S001`–`S005`) · 20 products
(`P0001`–`P0020`) · 5 categories · 4 regions · Jan 1, 2022 – Jan 1, 2024.

Each row is one **Date + Store + Product** combination, with inventory
level, units sold/ordered, a demand forecast, pricing, weather, and
promotion/seasonality context. Full column-by-column definitions are in
[`outputs/data_dictionary.md`](outputs/data_dictionary.md).

**Note:** every one of the 20 products appears under all 5 category values
in this dataset — `Product ID` and `Category` are not a 1:1 mapping here.
All product-level analysis in this project groups by `Product ID` alone to
avoid implying otherwise.

---

## How to Run This Project

### 1. Data cleaning
Open `notebook/data_cleaning.ipynb` and run all cells. This profiles the
raw CSV, checks for missing values/duplicates/outliers, and writes the
cleaned output to `data/processed/retail_store_inventory_clean.csv`. See
[`outputs/data_quality_summary.md`](outputs/data_quality_summary.md) for
what was found and why each cleaning decision was made — most notably,
673 rows (0.92%) had a negative `Demand Forecast` value and were clipped
to 0 after investigation.

### 2. Load into MySQL

Two schema options are available — see [Schema](#schema) below for why
both exist.

**Option A — flat schema** (single fact table):
```bash
mysql -u root < sql/schema.sql
```
Then either run `notebook/load_mysql.ipynb`, or run
`python scripts/load_mysql.py` from the `scripts/` folder — same load
logic, loads in batches with a row-count check at the end.

**Option B — normalized schema** (entity + lookup tables + fact table):
```bash
mysql -u root --local-infile=1 < sql/schema_normalized.sql
mysql -u root --local-infile=1 < sql/load_normalized.sql
```
**Note:** MySQL defaults `local_infile` to OFF. If
`load_normalized.sql` fails with "Loading local data is disabled", also
run `SET GLOBAL local_infile = 1;` on the server first (or add
`local_infile=1` under `[mysqld]` in `my.cnf` to persist it across
restarts).

### 3. Run the SQL analysis
Everything's in `sql/analysis.sql` — KPIs, risk levels per store/category,
which products are fast vs. slow sellers, overstock checks, forecast
accuracy, and a reorder recommendation. `sql/reorder_point_trend.sql` is a
second reorder calculation that's more rigorous (explained below). Notes
on speeding up slow queries (with before/after timings) are now in the
comments at the top of `sql/schema.sql`, right above the indexes they
explain.

### 4. Run the Python analysis
Open `notebook/analysis.ipynb` and run all cells. This covers the same
ground as `analysis.sql` but with visualizations (KPI charts, risk
distributions, segmentation plots, forecast error breakdowns).

### 5. Look at the plots without running anything
`plots/` has 13 pre-generated PNGs — the curated set that backs the key
findings below, no need to rerun the notebook to see them.

If you want to regenerate charts by querying MySQL directly instead of the
CSV (same charts, different data source, good for practicing SQL + Python
together), `plots_from_db/` has standalone scripts for that — run e.g.
`python plots_from_db/inventory_risk_distribution.py` from inside that
folder. Each one prompts for your MySQL password, runs one query, and
plots the result. Requires Option A's flat schema to already be loaded.

### 6. Run the dashboard
```bash
pip install -r requirements.txt
cd dashboard
streamlit run app.py
```
Reads `data/processed/retail_store_inventory_clean.csv` directly (no DB
connection required to run it). Four panels: Inventory Overview, Product
Performance, Store & Regional Performance, Replenishment Actions.

---

## Key Findings

1. **There's way more overstock than understock.** Almost half of all
   observations (47.45%) have way more inventory than they need. Only
   3.57% are actually running low. And this isn't one bad store — it's
   spread evenly across every store, region, and category.
2. **A small number of items need restocking at any given time** — about
   5 out of every 100 store-product combos, at any given moment.
3. **Demand forecasts are only okay, not great** — off by about 23% on
   average. Groceries forecasts are the least accurate, Electronics the most.
4. **Promotions don't seem to boost sales here**, which is surprising —
   sales on promo days and normal days are basically identical.
5. **"Fast sellers" vs "slow sellers" isn't a strong pattern** in this
   data — all 20 products sell at roughly the same pace, so we don't
   fully trust this as a way to prioritize.

Full detail, evidence, and stated risk/limitations for each recommendation
are in [`outputs/recommendations.md`](outputs/recommendations.md). The
1-page version is in
[`outputs/executive_summary.md`](outputs/executive_summary.md).

---

## Schema

Two schema designs exist in this project, on purpose:

- **`schema.sql`** — one flat table. Simple, and what all the analysis
  actually runs on.
- **`schema_normalized.sql`** — a "properly" normalized version, with
  separate tables for stores, products, categories, etc.

Here's the thing: a normal textbook design would put "category" as a
column on the `products` table (like, "this product belongs to this
category"). **We checked, and that's actually wrong for this data** —
every product shows up under every category, so there's no fixed
"product → category" relationship to store. If you build it that way
anyway, you either get an error or (worse) your database silently keeps
only one category per product and throws away the rest. We actually found
another student's project online that made exactly this mistake — it ran
without errors, but silently corrupted the category data for every
product. So in our version, category/region/weather all live on the main
table itself, not on `products`/`stores`.

We also added 3 indexes to speed up the slow queries — but only after
testing. Turns out a "naive" index (just one column) actually made things
*slower*, not faster. The fix was building indexes that include every
column the query needs, which cut query time by 50–60%. Full before/after
notes are in the comments right above the indexes in `sql/schema.sql`.

**Two ways to calculate "when to reorder":** `sql/analysis.sql` just uses
the demand forecast the dataset already gives us. `sql/reorder_point_trend.sql`
calculates it independently from each product's actual sales history
(standard safety-stock formula). Funny story: our first attempt assumed a
7-day restock cycle (pretty standard assumption), and it said *literally
everything* needed reordering — clearly wrong. Turned out this business
restocks almost daily, not weekly, so we fixed the assumption to match
what the data actually showed.

All SQL and calculations described here were tested end-to-end against a
real MySQL 8.0 server from a clean database, with row counts and
foreign-key integrity verified at each step. The `plots_from_db/` scripts
were checked the same way — the numbers they produce from live SQL
queries match the `plots/` versions (built from the CSV) exactly.

---

## Known Limitations

This dataset has no supplier info, no lead times, no warehouse data, and
no cost data. So anything about "$ saved" is a direction, not an exact
number, since we don't have prices for storage or shipping. Full list of
what every "risk" or "reorder" number actually means:
[`outputs/data_dictionary.md`](outputs/data_dictionary.md)

---

## Tech Stack

Python (pandas, matplotlib), MySQL 8.0, Streamlit + Plotly for the
dashboard.
