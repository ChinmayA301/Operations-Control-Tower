# Data Dictionary — Supply Chain Control Tower

**Source:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/olistbr/brazilian-ecommerce) — ~100k real orders placed on the Olist marketplace, Sept 2016 – Oct 2018. License: CC BY-NC-SA 4.0. This is **real transactional data**, not synthetic.

The pipeline reshapes nine raw tables into a star schema (`fact_orders`, `fact_order_items`, four dimensions) and five analysis marts. This page documents (1) how the project's business concepts map onto real Olist fields, (2) every column in the marts.

---

## 1. Concept → real-signal mapping (read this first)

Olist is a genuine marketplace export, so several fields a "designed" supply-chain dataset would contain **do not exist**. Rather than fabricate them, each business concept is mapped to a real, defensible signal. Proxies are labeled as proxies everywhere they are used.

| Business concept | Implemented as | Real / proxy | Notes |
|---|---|---|---|
| Supplier | Olist **seller** (`seller_id`) | real | 3,095 sellers; 818 have ≥20 orders and are risk-scored |
| Customer region | Customer **state** (`customer_state`) | real | 27 Brazilian states |
| Order / ship / delivery dates | `order_purchase` / `delivered_carrier` / `delivered_customer` | real | timestamps present on delivered orders |
| Promised delivery date | `order_estimated_delivery_date` | real | set at purchase time |
| `delay_days` | `delivered_customer − estimated` (days) | real | positive = late |
| Revenue | Σ item `price` | real | in Brazilian Real (R$) |
| Shipping cost | Σ item `freight_value` | real | charged freight |
| Margin pressure | **freight-to-revenue ratio** | real proxy | Olist has **no COGS**, so true gross margin is not computable; freight burden is the available margin-drag signal |
| `return_flag` | order **cancellation** (`order_status='canceled'`) | proxy | no returns table in Olist |
| `defect_flag` / quality | **review score ≤ 2** | proxy | 1–2★ review = dissatisfaction/quality proxy |
| Demand volatility | CV of a supplier's monthly order counts | real (derived) | std/mean of monthly volume |
| `shipping_mode` | — | **not available** | Olist records no carrier/mode |
| `warehouse` | — | **not available** | no fulfillment-center field |
| `inventory_level`, stockout, forecast | — | **not available** | no inventory snapshots; ABC-by-revenue is provided instead |

> Anything not in the data is **omitted and disclosed** (see `README` → Limitations), never invented.

---

## 2. Star schema

**Dimensions:** `dim_supplier` (seller_id, state, city) · `dim_customer_region` (state) · `dim_product_category` (product_id → English category, weight, volume) · `dim_date` (calendar with year/quarter/month).

**Facts:** `fact_order_items` (item grain: revenue, freight, supplier, category) · `fact_orders` (order grain, below).

`assets/schema_diagram.md` shows the relationships.

### `fact_orders` (order grain — one row per order)
| Column | Type | Definition |
|---|---|---|
| order_id | text | natural key |
| order_status | text | delivered / shipped / canceled / … |
| region_state | text | customer state (region) |
| primary_supplier_id | text | seller of the highest-priced line (representative attribution) |
| primary_category | text | category of the highest-priced line |
| order_ts | timestamp | purchase timestamp |
| order_month | text | `YYYY-MM` of purchase |
| promised_date / delivered_date | date | estimated vs actual customer delivery |
| revenue / freight | double | Σ price / Σ freight over the order's items (R$) |
| n_items / n_suppliers | int | line count / distinct sellers on the order |
| freight_ratio | double | freight / revenue |
| review_score | int | worst review on the order (1–5), null if none |
| delay_days | int | delivered − promised (positive = late) |
| handling_days / transit_days | int | approve→carrier / carrier→customer |
| is_delivered / is_canceled / is_late / is_bad_review | bool | status & KPI flags (`is_late` = delivered after promised; `is_bad_review` = score ≤ 2) |

---

## 3. Marts (Looker Studio data sources)

- **`mart_exec_kpis`** — tall key/value table of headline KPIs → scorecards.
- **`mart_monthly`** — order_month × {orders, revenue, on_time_rate, avg_delay_days_late, bad_review_rate}.
- **`mart_region`** — state × {orders, revenue, late_rate, avg_delay_days_late, avg_freight_ratio, bad_review_rate}.
- **`mart_product_risk`** — category × {orders, revenue, revenue_share, cum_revenue_share, abc_class, late_rate, bad_review_rate, avg_freight_ratio}.
- **`mart_supplier_scorecard`** — supplier × {orders, revenue, revenue_share, late_rate, cancel_rate, bad_review_rate, freight_burden, demand_volatility, **risk_score (0–100)**, risk_quintile}. Scored suppliers only (≥20 orders).

KPI formulas live in [`kpi_dictionary.md`](kpi_dictionary.md).
