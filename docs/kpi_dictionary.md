# KPI Dictionary — Supply Chain Control Tower

Every KPI on the dashboard, with its exact definition, the grain it is computed at, and why an operations manager should care. Formulas match the SQL in [`sql/03_kpi_views.sql`](../sql/03_kpi_views.sql). Currency is Brazilian Real (R$).

## Fulfillment & service
| KPI | Definition | Grain | Why it matters |
|---|---|---|---|
| **On-time delivery rate** | delivered orders with `delivered_date ≤ promised_date` ÷ delivered orders | order | Core service-level metric; directly tied to satisfaction (see below) |
| **Late rate** | `1 − on-time rate` | order | The headline risk number |
| **Avg delay (late orders)** | mean(`delivered_date − promised_date`) over late orders only | order | Severity of failures, not just frequency. Averaging over *all* orders would hide it |
| **Handling days** | `delivered_carrier − approved` | order | Isolates the seller/warehouse-controlled portion of lead time |
| **Transit days** | `delivered_customer − delivered_carrier` | order | Isolates the carrier/geography-controlled portion |

## Quality & retention
| KPI | Definition | Grain | Why it matters |
|---|---|---|---|
| **Bad-review rate** | orders rated 1–2★ ÷ orders with a review | order | Proxy for defect/dissatisfaction (no defect field in source) |
| **Cancel rate** | canceled orders ÷ all orders | order | Proxy for return/fulfillment failure |
| **Avg review score** | mean review score (1–5) | order | Continuous satisfaction signal |

## Financial
| KPI | Definition | Grain | Why it matters |
|---|---|---|---|
| **Revenue** | Σ item `price` | item→order | Top line |
| **Freight cost** | Σ item `freight_value` | item→order | Largest observable cost component |
| **Freight-to-revenue ratio** | freight ÷ revenue | order/category/supplier | **Margin-pressure proxy** — Olist has no COGS, so this is the available margin signal. High ratio = structurally expensive to fulfill (heavy/bulky/remote) |
| **Revenue exposed to late delivery** | Σ revenue of delivered-late orders | order | Revenue sitting behind a service failure. *Exposure, not a loss claim* |

## Concentration & classification
| KPI | Definition | Grain | Why it matters |
|---|---|---|---|
| **Revenue share** | entity revenue ÷ total revenue | category/supplier | Where the money is |
| **ABC class** | A: cumulative revenue ≤80%, B: ≤95%, C: rest (categories sorted desc) | category | Focuses attention on the vital few |
| **Demand volatility** | CV = `stddev(monthly orders) / mean(monthly orders)` | supplier | Unpredictable demand → planning/stockout risk |

## Supplier Risk Score (the centerpiece)

A single **0–100** ranking of operational risk per supplier (higher = worse). Each of five components is **percentile-ranked across scored suppliers** (0 = best, 1 = worst) so the score is robust to outliers and directly comparable, then combined with explicit, tunable weights:

```
Risk = 100 × ( 0.30·late_rate_pr      # service failure (weighted highest)
             + 0.20·cancel_rate_pr    # return / fulfillment-failure proxy
             + 0.20·bad_review_pr      # defect / dissatisfaction proxy
             + 0.15·freight_burden_pr  # margin-pressure proxy
             + 0.15·demand_volatility_pr )  # planning risk
```

**Design choices (and why):**
- **Percentile-rank, not raw values** → one supplier with a 300% freight ratio can't dominate the score; it measures relative standing.
- **Weights are explicit and tunable** → live in one `SELECT`; an ops lead who cares more about quality than cost can shift 0.20→0.30 in seconds. The weights encode a *business judgment*, not a statistical truth, and the doc says so.
- **Scored on ≥20 orders only** → a seller with 2 orders and 1 late delivery isn't "50% late" in any meaningful sense. `MIN_ORDERS` is the stability knob.
- **`risk_quintile`** buckets suppliers 1 (best) – 5 (worst) for fast triage.

> The score is a **prioritization tool**, not a verdict. It tells an ops team *who to review first*, not *who to fire*. That distinction is stated wherever the score appears.
