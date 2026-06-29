# Case Study — Supply Chain Control Tower
*Portfolio / blog-ready writeup. Pairs with the [README](../README.md) and [executive memo](executive_memo.md).*

## Problem
Marketplace operations teams drown in order data but starve for direction. With thousands of daily orders across hundreds of suppliers and 27 regions, the real question isn't "what happened" — it's "given limited attention this week, **what do we fix first?**" I built a control tower that turns 99k raw orders into a ranked action list.

## Why it matters
On a marketplace, fulfillment reliability *is* the product. A late delivery isn't a logistics footnote — it's a retention event. The project quantifies that link and routes attention to the suppliers, regions, and categories where intervention protects the most revenue.

## Dataset
[Olist Brazilian E-Commerce](https://www.kaggle.com/olistbr/brazilian-ecommerce): **~100k real orders** (Sept 2016–Oct 2018), nine relational tables — orders, items, payments, reviews, customers, products, sellers. Real timestamps for purchase/ship/delivery/estimated-delivery enable genuine on-time analysis. **Deliberately honest scoping:** Olist has no carrier mode, COGS, or inventory, so those analyses are *omitted and disclosed* rather than faked. Business concepts (supplier, return, defect, margin) are mapped to real signals via a documented [field-mapping table](data_dictionary.md#1-concept--real-signal-mapping-read-this-first).

## Methods / workflow
1. **Ingest** real CSVs (reproducible download script).
2. **Model** a star schema in DuckDB SQL — `fact_orders`, `fact_order_items`, four dimensions (`01_schema.sql`).
3. **Clean & derive** timing fields and KPI flags at order grain (`02_cleaning.sql`): delay days, handling vs transit split, late/cancel/bad-review flags, worst-review-per-order, primary-supplier attribution.
4. **Engineer KPIs & a tunable supplier risk score** (`03_kpi_views.sql`): five percentile-ranked, weighted components → a 0–100 ranking; ABC revenue classification; region and category marts.
5. **Visualize** — five-page Looker Studio decision dashboard on the exported marts; reproducible matplotlib figures for the writeup.
6. **Communicate** — executive memo with prioritized, costed interventions.

## Architecture
```
raw Olist CSVs ─▶ DuckDB star schema (SQL) ─▶ KPI marts (SQL) ─▶ CSV ─▶ Looker Studio (5 pages)
                                              └─▶ matplotlib figures (README / case study)
```
SQL does the modeling; Python orchestrates and visualizes; Looker only renders. Each layer is independently runnable and the whole thing rebuilds from one command.

## Key metrics
On-time rate **93.2%** · late-order bad-review rate **62.9%** (vs 9.6%) · revenue exposed to late delivery **R$986K** · late-rate spread **4.0%→17.4%** by region · worst supplier quintile **R$2.7M @ 12.2% late** · revenue concentration **79.6% in 17 categories**.

## Key findings
1. **Lateness, not price, drives dissatisfaction** — 6.5× higher bad-review rate; on-time delivery is really a revenue KPI.
2. **Risk is geographic** — Northeast + RJ dominate; RJ is the priority because it's high-volume *and* high-late-rate.
3. **Risk is supplier-concentrated** — a manageable 163-supplier cohort carries the bulk of it.
4. **Revenue is concentrated** — A-class categories, several with 28–37% freight burden, are where margin work pays off.

## Outputs
5-page dashboard · supplier scorecard with risk score · ABC product classification · executive memo · 6 analysis figures · full SQL data model + data/KPI dictionaries.

## Limitations
Correlational (not causal); freight-to-revenue proxies margin (no COGS); cancellations/low-reviews proxy returns/defects; no carrier/warehouse/inventory data; single marketplace, 2016–2018. (Detailed in README.)

## What I'd improve next
Causal estimate of the late→churn effect · geospatial transit-time model · live BigQuery refresh · per-supplier risk-score alerting.

---

## Résumé bullets
> **Supply Chain Control Tower** — *SQL (DuckDB), Looker Studio, Python*
> - Built an operations-analytics product on **98,666 real marketplace orders**, modeling a SQL **star schema** (fact + 4 dimensions) and KPI marts to surface fulfillment delay, supplier risk, and margin leakage for decision support.
> - Designed a **tunable 0–100 supplier risk score** (percentile-ranked late/cancel/defect/freight/volatility components), isolating a **163-supplier cohort carrying R$2.7M of revenue at 2× the platform late- and bad-review rates**.
> - Quantified that **late deliveries are 6.5× more likely to draw 1–2★ reviews** (62.9% vs 9.6%), reframing on-time delivery as a revenue KPI and driving a prioritized regional + supplier intervention plan.
> - Shipped a **5-page Looker Studio dashboard** with documented data/KPI dictionaries and an executive memo; fully reproducible from one command.

## Interview talking points
- **"Why Olist and not a clean synthetic set?"** Real data forces honest modeling decisions. The credibility comes from mapping business concepts to imperfect real signals and *disclosing the gaps* — that's the actual analyst job, not generating a tidy CSV that proves nothing.
- **"Walk me through the risk score."** Five components, each percentile-ranked so no single outlier dominates, weighted by business priority (lateness highest), scored only on suppliers with ≥20 orders for stability. The weights are a business judgment exposed in one SQL block — an ops lead can retune in seconds. It ranks *who to review first*, it doesn't pass a verdict.
- **"What's the most important finding and what would you do about it?"** The 6.5× late→bad-review link. It moves delivery from an ops-hygiene metric to a revenue lever. Action: fix RJ + Northeast first (most absolute at-risk orders), then a supplier-improvement program for quintile 5 — coach the high-revenue risky suppliers rather than churn them.
- **"What's wrong with this project?"** It's correlational; freight is a margin *proxy* because there's no COGS; it's one marketplace from 2016–2018. I'd want a quasi-experiment for the churn effect and live data before acting at scale. (Naming the limits unprompted is the point.)
- **"Why SQL for the modeling instead of pandas?"** The star schema, joins, window functions (percentile ranks, ABC cumulative shares), and KPI views are exactly what SQL is for, and it's the language an analytics team would maintain. Python orchestrates and visualizes; it doesn't do the modeling that belongs in the warehouse.
