# Datasheet — Olist Brazilian E-Commerce

Following *Datasheets for Datasets* (Gebru et al., 2021), to make data provenance and limitations explicit.

## Motivation
- **Purpose here:** operational analytics on real marketplace fulfillment — delays, supplier risk, margin pressure.
- **Original creation:** released by Olist (a Brazilian marketplace integrator) as a public dataset of real orders.

## Composition
- **Instances:** ~100K orders (2016-09 → 2018-10) across 9 relational tables (orders, items, payments, reviews, customers, products, sellers, geolocation, category translation).
- **Grain used:** order level (`fact_orders`) and item level (`fact_order_items`).
- **Fields:** purchase/ship/delivery/estimated-delivery timestamps, prices, freight, review scores, seller & customer states, product categories.
- **Sensitive data:** none direct — identifiers are anonymized hashes; customer names/text are not used.

## Collection
- Transactional logs from the Olist platform; reviews collected post-purchase via satisfaction surveys. Real, not synthetic or simulated.

## Preprocessing (this project)
- `'?'`/blank → null; one encounter... (n/a). Orders with no line items dropped. Timing fields derived (delay, handling, transit). See [`sql/02_cleaning.sql`](../sql/02_cleaning.sql). Validated with Great Expectations — see [`data_quality_report.md`](data_quality_report.md).

## Uses & limitations
- **Appropriate:** BI/operations analytics, KPI design, methodology demonstration.
- **Not appropriate:** claims about current operations (data is 2016–2018), causal inference, or any market outside Brazil.
- **Known gaps:** no carrier/shipping mode, no COGS (so margin is proxied by freight ratio), no inventory. Documented in [`data_dictionary.md`](data_dictionary.md) and the README.

## Distribution & license
- Public on Kaggle (`olistbr/brazilian-ecommerce`), **CC BY-NC-SA 4.0**. Non-commercial; attribute Olist.
