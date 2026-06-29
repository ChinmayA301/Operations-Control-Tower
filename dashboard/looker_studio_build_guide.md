# Looker Studio Build Guide & Wireframe

This dashboard is built in **Looker Studio** (free) on the five CSV marts in
`data/processed/`. The marts are the contract; the SQL does the heavy lifting so
Looker only renders. Follow this to reproduce the report, then drop screenshots
into `dashboard/screenshots/` and link the live report in the README.

## Connect the data
1. Run the pipeline → `python src/run_pipeline.py` produces the marts.
2. In Looker Studio → **Create → Data source → CSV upload** (or upload the marts to
   Google Sheets and use the Sheets connector) for each of:
   `mart_exec_kpis`, `mart_monthly`, `mart_region`, `mart_product_risk`, `mart_supplier_scorecard`.
3. Set types: rates as **Percent**, revenue/freight as **Number (R$)**, `order_month` as Text
   (sortable), `risk_score` as Number.

## Design system
- **Layout:** 1280×720 pages, 12-column grid, 16px gutters.
- **Palette:** ink `#1f2933`, accent `#2b6cb0`, risk-bad `#c0392b`, good `#2e8b57`, neutral `#e2e8f0`.
- **Rule:** every page answers one business question stated in its title. No chart without a decision.

---

## Page 1 — Executive Overview  *(“How is the operation doing?”)*
Scorecards (from `mart_exec_kpis`): Total Orders · Revenue (R$) · Freight (R$) ·
**On-time Rate** · Avg Delay (late) · Bad-review Rate · Cancel Rate · **Revenue Exposed to Late Delivery**.
```
┌ Total Orders ┐┌ Revenue ┐┌ On-time % ┐┌ Bad-review % ┐
│   98,666     ││ R$13.6M ││  93.2%    ││   14.6%      │   <- scorecards w/ sparkline
└──────────────┘└─────────┘└───────────┘└──────────────┘
┌─ On-time rate by month (mart_monthly, line) ─┬─ Revenue by month (bar) ─┐
└──────────────────────────────────────────────┴──────────────────────────┘
```

## Page 2 — Fulfillment Performance  *(“Where do delays come from?”)*
- **Late rate by region** — filled map of Brazil (geo: `region_state`) **or** bar (`mart_region`).
- **Avg delay by region** — bar.
- **On-time trend** — line (`mart_monthly`), with a target reference line at 95%.
- **Handling vs transit split** — note explaining seller-controlled vs carrier-controlled time.
- Controls: date range, region filter.

## Page 3 — Supplier Scorecard  *(“Which suppliers create risk?”)*
- **Table** (`mart_supplier_scorecard`): supplier_id, orders, revenue, late_rate, bad_review_rate,
  freight_burden, **risk_score** — conditional-format risk_score red→green, sort desc.
- **Risk landscape scatter:** x=late_rate, y=bad_review_rate, size=revenue, color=risk_score.
- **Revenue by risk quintile** — bar showing how much revenue sits in quintile 5.
- Scorecard: # suppliers in quintile 5, their combined revenue.

## Page 4 — Product / SKU Risk  *(“Which products are revenue-rich but risky?”)*
- **ABC Pareto** (`mart_product_risk`): category revenue bars + cumulative line, 80% reference.
- **Category risk map scatter:** x=revenue, y=late_rate, size=bad_review_rate, color=freight_ratio.
- **Table:** A-class categories with late_rate, bad_review_rate, freight_ratio highlighted.

## Page 5 — Executive Action View  *(“What do I do Monday?”)*
- **Top 10 suppliers to review** — filtered table, risk_score desc.
- **Top regions to fix** — `mart_region` sorted by `orders × late_rate` (impact).
- **A-class categories with high freight burden** — margin-leakage shortlist.
- **Recommended interventions** text box mirroring `docs/executive_memo.md`.

---

### Screenshot checklist (commit to `dashboard/screenshots/`)
`01_overview.png` · `02_fulfillment.png` · `03_supplier_scorecard.png` ·
`04_product_risk.png` · `05_action_view.png` — then paste the report's **Share → public link**
into the README badge. The static `assets/figures/*.png` (from `make_figures.py`)
can stand in until the live screenshots are captured.
