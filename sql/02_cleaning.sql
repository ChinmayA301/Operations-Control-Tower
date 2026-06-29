-- =====================================================================
-- 02_cleaning.sql  |  Supply Chain Control Tower
-- Cleans staging data and builds the cleaned fact tables:
--   fact_order_items  (item grain, enriched with supplier + category)
--   fact_orders       (order grain, enriched with timing flags + value)
-- Run after 01_schema.sql.
-- =====================================================================

-- ---------- ITEM GRAIN ----------------------------------------------
-- One row per (order_id, order_item_id). price = item revenue,
-- freight_value = shipping cost charged. Joined to supplier + category.
CREATE OR REPLACE TABLE fact_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id                            AS supplier_id,
    CAST(i.price        AS DOUBLE)         AS item_revenue,
    CAST(i.freight_value AS DOUBLE)        AS item_freight,
    c.product_category
FROM stg_order_items i
LEFT JOIN dim_product_category c ON i.product_id = c.product_id;

-- ---------- ORDER VALUE ROLL-UP (item -> order) ---------------------
CREATE OR REPLACE TABLE _order_value AS
SELECT
    order_id,
    SUM(item_revenue)                      AS revenue,
    SUM(item_freight)                      AS freight,
    COUNT(*)                               AS n_items,
    COUNT(DISTINCT supplier_id)            AS n_suppliers
FROM fact_order_items
GROUP BY order_id;

-- Primary supplier / category = the most expensive line on the order
-- (a single representative attribution for order-level slicing).
CREATE OR REPLACE TABLE _order_primary AS
SELECT order_id, supplier_id AS primary_supplier_id, product_category AS primary_category
FROM (
    SELECT order_id, supplier_id, product_category,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY item_revenue DESC, order_item_id) AS rn
    FROM fact_order_items
) WHERE rn = 1;

-- ---------- ORDER REVIEWS (one score per order) ---------------------
-- Some orders have multiple reviews; take the worst (most conservative).
CREATE OR REPLACE TABLE _order_review AS
SELECT order_id, MIN(CAST(review_score AS INTEGER)) AS review_score
FROM stg_reviews
WHERE review_score IS NOT NULL
GROUP BY order_id;

-- ---------- ORDER GRAIN FACT ----------------------------------------
CREATE OR REPLACE TABLE fact_orders AS
SELECT
    o.order_id,
    o.order_status,
    UPPER(TRIM(cu.customer_state))                          AS region_state,
    op.primary_supplier_id,
    op.primary_category,
    CAST(o.order_purchase_timestamp AS TIMESTAMP)           AS order_ts,
    STRFTIME(CAST(o.order_purchase_timestamp AS DATE), '%Y-%m') AS order_month,
    CAST(o.order_estimated_delivery_date AS DATE)           AS promised_date,
    CAST(o.order_delivered_customer_date AS DATE)           AS delivered_date,
    ov.revenue,
    ov.freight,
    ov.n_items,
    ov.n_suppliers,
    CASE WHEN ov.revenue > 0 THEN ov.freight / ov.revenue END AS freight_ratio,
    rv.review_score,
    -- ----- delivery timing (only meaningful for delivered orders) -----
    DATE_DIFF('day', CAST(o.order_estimated_delivery_date AS DATE),
                     CAST(o.order_delivered_customer_date AS DATE)) AS delay_days,
    DATE_DIFF('day', CAST(o.order_approved_at AS DATE),
                     CAST(o.order_delivered_carrier_date AS DATE))  AS handling_days,
    DATE_DIFF('day', CAST(o.order_delivered_carrier_date AS DATE),
                     CAST(o.order_delivered_customer_date AS DATE)) AS transit_days,
    -- ----- flags -----
    (o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL)            AS is_delivered,
    (o.order_status = 'canceled')                                  AS is_canceled,
    (CAST(o.order_delivered_customer_date AS DATE)
        > CAST(o.order_estimated_delivery_date AS DATE))           AS is_late,
    (rv.review_score <= 2)                                         AS is_bad_review
FROM stg_orders o
LEFT JOIN stg_customers cu ON o.customer_id     = cu.customer_id
LEFT JOIN _order_value  ov ON o.order_id        = ov.order_id
LEFT JOIN _order_primary op ON o.order_id       = op.order_id
LEFT JOIN _order_review  rv ON o.order_id        = rv.order_id;

-- Data-quality guardrail: drop the handful of orders with no line items
-- (they carry no revenue and cannot be attributed to a supplier).
DELETE FROM fact_orders WHERE revenue IS NULL;
