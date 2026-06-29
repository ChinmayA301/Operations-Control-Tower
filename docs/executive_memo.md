# Executive Insight Memo — Olist Fulfillment & Supplier Risk

**To:** VP Operations · **From:** Data Analytics · **Re:** Where to intervene to protect revenue and retention
**Scope:** 98,666 marketplace orders, R$13.6M revenue, Sept 2016 – Oct 2018. All figures from the project pipeline.

---

## Bottom line
Overall on-time delivery looks healthy at **93.2%**, but that average hides where the business is actually bleeding. **Late delivery is the single largest driver of customer dissatisfaction**, and the failures are concentrated in a predictable set of regions and suppliers. The headline number is fine; the distribution is the problem. Three interventions below target the ~7% of orders and ~20% of suppliers that cause most of the damage.

## Three findings that should drive action

**1. Lateness, not price, destroys satisfaction.**
Late orders carry a **62.9% bad-review rate vs 9.6%** for on-time orders — a **6.5× jump** (avg rating 2.25★ vs 4.28★). **R$986K** of revenue sits behind delivered-late orders. On a marketplace where repeat purchase depends on reputation, every avoidable late delivery is a retention event, not just a logistics miss. *On-time delivery should be treated as a revenue KPI, not an ops hygiene metric.*

**2. The risk is geographic and concentrated.**
Late rate ranges from **4.0% in the South (PR)** to **17.4% in the Northeast (MA)** — a 4× spread. The priority is **Rio de Janeiro: the 2nd-largest market (12,762 orders) running at 12.1% late** with a 20.9% bad-review rate. Fixing RJ moves more absolute orders than fixing any small-volume state. Northeast states (MA, CE, BA, PA) form a clear secondary cluster driven by longer transit, not seller handling.

**3. A minority of suppliers carry most of the operational risk.**
Of 818 risk-scored suppliers, the **worst quintile (163 suppliers) carries R$2.7M in revenue at a 12.2% late rate and 23.8% bad-review rate** — roughly double the platform average on both. These are high-revenue *and* high-risk: the kind you manage, not drop. The top 10 by risk score run 14–32% late rates and warrant immediate review.

## Recommended interventions (in priority order)
| # | Action | Target | Rationale |
|---|---|---|---|
| 1 | Renegotiate delivery promises & carrier SLAs for **RJ + Northeast** | RJ, MA, CE, BA, PA | Highest absolute count of at-risk orders; mostly transit-time, addressable via promise dates and carrier mix |
| 2 | Launch a **supplier improvement program** for quintile-5 sellers | 163 suppliers, R$2.7M | Concentrated, high-revenue risk — coaching beats churn here |
| 3 | Audit **A-class categories with 28–37% freight burden** (furniture, housewares, bed/bath) | ~6 categories | Structural margin drag; revisit packaging, freight pricing, or regional sourcing |
| 4 | Add a **late-delivery early-warning flag** | platform-wide | Lateness is predictable from region+supplier; intervene before the bad review lands |

## What this memo does *not* claim
- These are **associations, not causal estimates** — late delivery correlates with bad reviews; a controlled test would be needed to quantify the causal retention effect.
- "Margin pressure" uses **freight-to-revenue** because the dataset has **no cost-of-goods**; true gross margin is out of scope.
- Returns/defects are **proxied** by cancellations and 1–2★ reviews. The data has no returns or defect tables.
- Findings describe **one marketplace, 2016–2018**, and should be re-validated on current data before acting at scale.
