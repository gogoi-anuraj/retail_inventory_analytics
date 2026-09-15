# Business Recommendations

**Business question:** Where are the biggest inventory inefficiencies, which
products/stores are at risk, and what inventory actions should the business
take?

Each recommendation below is traceable to a specific finding produced by the
SQL analysis, the Python notebooks, or the dashboard. Where the dataset
cannot support a stronger or more quantified claim, that limitation is
stated explicitly rather than implied away.

---

## 1. Reduce network-wide inventory buffers — overstock is systemic, not localized

**Problem**
Across the full two-year dataset, **47.45%** of valid observations fall into
the *Excess Inventory* tier (inventory > 2.0× demand forecast), and under
the more lenient Phase 7 overstock definition (> 1.5× forecast), **64.08%**
of all observations qualify as overstocked. By contrast, only **3.57%** of
observations are *Understocked*. This is not a localized problem: the
excess-inventory rate varies by less than 1 percentage point across every
store (46.8–47.8%), every region (47.1–47.8%), and every category
(47.2–47.7%).

**Evidence**
- `sql/analysis.sql` §3.8 (canonical risk distribution) and §3.9–3.11
  (risk by store/category — now reporting all 4 tiers)
- Notebook overstock analysis (Phase 7, >1.5× threshold): 64.08% overall
- Network totals: 9,975,582 units sold vs. 8,041,327 units ordered over the
  period — sales are being drawn from a large standing buffer rather than
  tightly matched to ordering

**Action**
Because overstock is uniform across the network rather than concentrated,
this is a policy-level issue, not a store- or category-specific fix. Pilot a
modest, monitored reduction in baseline inventory targets (e.g. store-product
combinations currently in the Excess Inventory tier) in a small subset of
stores first, and track the Understocked rate weekly during the pilot. The
current 3.57% baseline understocked rate gives meaningful headroom before a
reduction would be expected to create new stockout risk.

**Expected Benefit**
Intended to reduce excess carrying inventory and free up capital tied up in
slow-depleting stock, without materially increasing stockout risk — because
the current gap between excess (47%) and understocked (3.6%) observations is
large.

**Risk / Limitation**
No holding cost, COGS, or warehouse capacity data exists in this dataset, so
the financial size of the benefit cannot be quantified here. No supplier
lead-time data exists either, so there's no way to confirm a "safe" minimum
buffer — this is why the recommendation is a *monitored pilot*, not a
network-wide cut.

---

## 2. Operationalize the reorder trigger as a recurring check, not a one-time report

**Problem**
On the most recent date in the dataset (2024-01-01), 5 of 100 active
store-product combinations were understocked and required replenishment
(98 total units, with a 10% buffer applied). This is consistent with the
3.57% long-run understocked rate — a small but persistent tail of at-risk
items exists at any given time.

**Evidence**
- `sql/analysis.sql` §5 (Reorder Recommendation query)
- Dashboard "Replenishment Actions" panel, same snapshot logic

**Action**
Run the reorder-trigger query as a daily/recurring check (e.g. each morning)
rather than treating it as a static report, since the set of at-risk
store-product combinations changes day to day. Feed the output directly into
whatever ordering workflow the business already uses.

**Expected Benefit**
Intended to reduce potential stockout risk for the specific ~3–5% of
inventory positions that are actually at risk at any given time, without
requiring broad changes to ordering for the other ~96%.

**Risk / Limitation**
This is a same-day reactive trigger, not a true lead-time-based reorder
point — no supplier lead-time data exists to confirm whether "order today"
is fast enough to prevent an actual stockout before restock arrives. The
10% buffer is a documented assumption (see #3 below), not a calculated
safety-stock value.

---

## 3. Investigate forecast reliability, especially for Groceries, before trusting forecast-driven decisions further

**Problem**
Demand Forecast accuracy is moderate at best: overall MAPE is **23.29%**
(MAE 8.31, RMSE 10.00 units). Accuracy is fairly consistent across
categories, but Groceries is measurably the worst (**24.26% MAPE**) and
Electronics the best (**22.22% MAPE**).

**Evidence**
- `sql/analysis.sql` §3.12–3.15 (forecast accuracy overall, by store, by
  category)
- Notebook Phase 9 forecast error analysis

**Action**
Because this project's scope explicitly excludes building ML forecasting
models, the recommendation is a **process investigation**, not a modeling
project: audit how the Groceries forecast is generated (e.g. is it using a
shorter demand history, more volatile categories, or a different method than
other categories) and confirm the ~23% error is understood before any
inventory policy leans harder on `Demand Forecast` values. This finding is
also the practical justification for applying a buffer (not zero) on top of
the forecast in the Phase 8 reorder logic, rather than trusting the forecast
value directly.

**Expected Benefit**
Intended to reduce the number of inventory decisions made on an
under-examined ~23% average forecast error, and to make the existing 10%
reorder buffer a documented, evidence-linked choice rather than an arbitrary
one.

**Risk / Limitation**
The dataset does not indicate *why* forecasts miss (no external demand
signals, no forecasting methodology metadata), so this can only point at
where the error is concentrated, not its root cause.

---

## 4. Don't over-provision inventory ahead of promotions — no measurable demand lift is observed in this data

**Problem**
Promotional/holiday periods show essentially **no difference** in average
units sold compared to non-promotional periods: 136.42 units/day on
promotion vs. 136.51 on non-promotion days — a gap smaller than normal
day-to-day noise. Average inventory levels are actually very slightly
*higher* on promotion days (274.92 vs. 274.03), suggesting the business may
already be building extra buffer in anticipation of promotional lift that
isn't showing up in the sales data.

**Evidence**
- `sql/analysis.sql` §3.20 (Holiday/Promotion Impact)
- Notebook promotion_analysis cell

**Action**
Before allocating additional inventory ahead of future promotions, confirm
whether promotions in this dataset are being tracked/tagged correctly and
whether they're tied to any specific marketing push. If the flat sales
pattern holds up under further investigation, stop treating
`Holiday/Promotion = 1` as an automatic trigger for extra inventory buildup.

**Expected Benefit**
Intended to reduce unnecessary contribution to the excess-inventory problem
identified in Recommendation 1, specifically the portion driven by
promotion-anticipation buffering — without a demonstrated sales cost, since
no lift is currently observed.

**Risk / Limitation**
This is a correlation, not a causal test: it's possible promotions are
applied *because* a period was otherwise forecast to be weaker, and the
promotion is offsetting a dip that would otherwise be visible — the flat
result could reflect the promotion working exactly as intended, or it could
reflect promotions having no effect. This dataset cannot distinguish between
those two explanations, and this finding should not be read as a definitive
claim that promotions don't work.

---

## 5. Treat fast/slow-moving product segmentation as directional only, not a strong prioritization driver

**Problem**
The Phase 5 movement segmentation (Fast/Medium/Slow-moving, by inventory
turnover proxy tercile) is mathematically valid but shows very weak
differentiation: turnover proxy ranges only **0.490–0.505** across all 20
products at the aggregate level (a ~3% spread), and even at the finest
grain available (store-product, 100 combinations) the range is only
0.469–0.537.

**Evidence**
- `sql/analysis.sql` §4 (Product Movement Segmentation)
- Dashboard "Fast vs Slow-Moving Products" bubble chart — visibly shows all
  products clustered tightly rather than spread out

**Action**
Continue producing the segmentation (it's cheap and may become more useful
with more data), but do not use it as a primary weight in replenishment
prioritization decisions today — the Phase 8 reorder table's use of
`movement_segment` as a tie-breaker should stay a secondary factor, not a
driver, until the underlying signal is stronger.

**Expected Benefit**
Intended to prevent the business from over-trusting a statistically weak
segmentation as if it reflected large real differences between products,
which could otherwise misallocate replenishment attention.

**Risk / Limitation**
It's possible the weak differentiation reflects genuine near-uniform demand
across this product catalog, or it could reflect limitations in how the
source data was generated. Without additional data (e.g. a longer history,
more product diversity, or external demand drivers), this can't be resolved
further from within this project's scope.