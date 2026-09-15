# Executive Summary — Retail Inventory Analytics

**Dataset:** 73,100 daily store-product observations · 5 stores · 20 products
· 5 categories · 4 regions · Jan 1, 2022 – Jan 1, 2024

---

## 1. Business Problem

The company needs to know where inventory is being managed inefficiently,
which products or stores carry the most risk, and what concrete actions
would improve the situation — using only the data actually available (daily
inventory, sales, orders, and demand forecasts). No supplier, cost, or
warehouse data exists, so this analysis relies on clearly labeled **risk
indicators and proxies** rather than confirmed financial or operational
metrics.

---

## 2. Key Findings

**1. Overstock is the dominant problem, and it is systemic, not localized.**
47.45% of all observations fall into the *Excess Inventory* tier
(inventory > 2.0× demand forecast); under a more lenient 1.5× threshold,
64.08% of observations qualify as overstocked. This pattern is essentially
uniform across every store, region, and category (variance under 1
percentage point in each case) — there is no single "problem store" or
"problem region" driving it.

**2. Understocking is comparatively rare but persistent.** Only 3.57% of
observations are *Understocked*. On the most recent date in the dataset, 5
of 100 active store-product combinations needed replenishment (98 units
total, with a 10% buffer applied) — consistent with that long-run rate. This
is a small, recurring tail that needs a repeatable process, not a one-time
fix.

**3. Demand forecasts are moderately reliable, with Groceries the weakest
category.** Overall forecast error (MAPE) is 23.29%. Groceries has the
highest error (24.26%), Electronics the lowest (22.22%) — a modest but
consistent gap.

**4. Promotions show no measurable sales lift in this dataset.** Average
units sold on promotional/holiday days (136.42) is statistically
indistinguishable from non-promotional days (136.51), while average
inventory is slightly *higher* on promotional days — suggesting inventory
may be over-provisioned in anticipation of a lift that isn't showing up in
the sales data. This is a correlation, not a confirmed causal effect.

**5. Products show only weak differentiation in sales velocity.** The
Fast/Medium/Slow-moving segmentation (built on a unit-based inventory
turnover proxy) is valid but weak: turnover proxy ranges only 0.490–0.505
across all 20 products at the aggregate level. Segmentation should currently
be treated as directional, not a strong prioritization signal.

---

## 3. Recommended Actions

1. **Pilot a monitored reduction in baseline inventory targets**, starting
   with store-product combinations currently in the Excess Inventory tier,
   while tracking the understocked rate weekly to confirm stockout risk
   doesn't rise materially.
2. **Run the reorder-trigger query as a recurring daily check** and feed it
   directly into the ordering workflow, since the small at-risk tail changes
   day to day.
3. **Audit the Groceries forecasting process** before leaning further on
   `Demand Forecast` values for that category, and keep applying a buffer
   (not the raw forecast) in reorder logic given the ~23% average error.
4. **Stop automatically over-provisioning inventory ahead of promotions**
   until a genuine sales lift can be confirmed — the current data doesn't
   support the assumption that promotions drive extra demand.
5. **Use movement segmentation as a secondary, not primary, prioritization
   factor** in replenishment decisions until the underlying signal shows
   stronger differentiation.

*(Full detail, evidence, and stated risks for each recommendation are in
`outputs/recommendations.md`.)*

---

## 4. Limitations

This analysis is based solely on the provided dataset. The following are
explicitly **not** available and were not fabricated or assumed:

- No supplier information
- No supplier lead times
- No warehouse or location-capacity data
- No purchase cost / COGS data
- No true stockout flag — all "risk" metrics are indicators, not confirmed
  stockouts
- No historical stock receipt dates — true inventory age cannot be measured
- Reorder recommendations are simplified, same-day replenishment triggers,
  not full supply-chain or lead-time-based reorder point calculations
- All financial impact statements (e.g. "reduced carrying cost") are
  directional, not quantified, since no cost data exists to size them