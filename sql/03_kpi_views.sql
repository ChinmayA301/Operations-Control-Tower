-- =====================================================================
-- 03_kpi_views.sql  |  Supply Chain Control Tower
-- Analysis-ready marts consumed by the Looker Studio dashboard.
-- Each mart is a flat table sized for a BI tool. Run after 02_cleaning.sql.
-- KPI definitions are documented in docs/kpi_dictionary.md.
-- =====================================================================

-- =====================================================================
-- MART: executive KPIs  (tall key/value table -> scorecards)
-- =====================================================================
CREATE OR REPLACE VIEW mart_exec_kpis AS
WITH d AS (SELECT * FROM fact_orders WHERE is_delivered)
SELECT 'total_orders'        AS kpi, CAST((SELECT COUNT(*) FROM fact_orders) AS DOUBLE) AS value UNION ALL
SELECT 'delivered_orders',     (SELECT COUNT(*) FROM d) UNION ALL
SELECT 'total_revenue_brl',    (SELECT SUM(revenue) FROM fact_orders) UNION ALL
SELECT 'total_freight_brl',    (SELECT SUM(freight) FROM fact_orders) UNION ALL
SELECT 'freight_to_revenue',   (SELECT SUM(freight)/SUM(revenue) FROM fact_orders) UNION ALL
SELECT 'on_time_rate',         (SELECT AVG(CASE WHEN NOT is_late THEN 1.0 ELSE 0 END) FROM d) UNION ALL
SELECT 'late_rate',            (SELECT AVG(CASE WHEN is_late THEN 1.0 ELSE 0 END) FROM d) UNION ALL
SELECT 'avg_delay_days_late',  (SELECT AVG(delay_days) FROM d WHERE is_late) UNION ALL
SELECT 'cancel_rate',          (SELECT AVG(CASE WHEN is_canceled THEN 1.0 ELSE 0 END) FROM fact_orders) UNION ALL
SELECT 'bad_review_rate',      (SELECT AVG(CASE WHEN is_bad_review THEN 1.0 ELSE 0 END) FROM fact_orders WHERE review_score IS NOT NULL) UNION ALL
-- Revenue exposed to late delivery = revenue of delivered-late orders (factual exposure, not a loss claim)
SELECT 'revenue_exposed_to_late_brl', (SELECT SUM(revenue) FROM d WHERE is_late);

-- Wide (one-row) version of the exec KPIs — each KPI is its own column, which
-- is what Looker Studio scorecards expect (drop a field, no filter needed).
CREATE OR REPLACE VIEW mart_exec_kpis_wide AS
SELECT
    MAX(CASE WHEN kpi = 'total_orders'                THEN value END) AS total_orders,
    MAX(CASE WHEN kpi = 'delivered_orders'            THEN value END) AS delivered_orders,
    MAX(CASE WHEN kpi = 'total_revenue_brl'           THEN value END) AS total_revenue_brl,
    MAX(CASE WHEN kpi = 'total_freight_brl'           THEN value END) AS total_freight_brl,
    MAX(CASE WHEN kpi = 'freight_to_revenue'          THEN value END) AS freight_to_revenue,
    MAX(CASE WHEN kpi = 'on_time_rate'                THEN value END) AS on_time_rate,
    MAX(CASE WHEN kpi = 'late_rate'                   THEN value END) AS late_rate,
    MAX(CASE WHEN kpi = 'avg_delay_days_late'         THEN value END) AS avg_delay_days_late,
    MAX(CASE WHEN kpi = 'cancel_rate'                 THEN value END) AS cancel_rate,
    MAX(CASE WHEN kpi = 'bad_review_rate'             THEN value END) AS bad_review_rate,
    MAX(CASE WHEN kpi = 'revenue_exposed_to_late_brl' THEN value END) AS revenue_exposed_to_late_brl
FROM mart_exec_kpis;

-- =====================================================================
-- MART: monthly trend
-- =====================================================================
CREATE OR REPLACE VIEW mart_monthly AS
SELECT
    order_month,
    COUNT(*)                                              AS orders,
    SUM(revenue)                                          AS revenue,
    AVG(CASE WHEN is_delivered AND NOT is_late THEN 1.0
             WHEN is_delivered AND is_late     THEN 0 END) AS on_time_rate,
    AVG(CASE WHEN is_delivered AND is_late THEN delay_days END) AS avg_delay_days_late,
    AVG(CASE WHEN review_score IS NOT NULL THEN
             CASE WHEN is_bad_review THEN 1.0 ELSE 0 END END)  AS bad_review_rate
FROM fact_orders
GROUP BY order_month
ORDER BY order_month;

-- =====================================================================
-- MART: region (customer state) fulfillment
-- =====================================================================
CREATE OR REPLACE VIEW mart_region AS
SELECT
    region_state,
    COUNT(*)                                              AS orders,
    SUM(revenue)                                          AS revenue,
    AVG(CASE WHEN is_delivered AND is_late THEN 1.0
             WHEN is_delivered            THEN 0 END)     AS late_rate,
    AVG(CASE WHEN is_delivered AND is_late THEN delay_days END) AS avg_delay_days_late,
    AVG(freight_ratio)                                    AS avg_freight_ratio,
    AVG(CASE WHEN review_score IS NOT NULL THEN
             CASE WHEN is_bad_review THEN 1.0 ELSE 0 END END)  AS bad_review_rate
FROM fact_orders
WHERE region_state IS NOT NULL
GROUP BY region_state
ORDER BY orders DESC;

-- =====================================================================
-- MART: product-category risk  (+ ABC classification by revenue)
-- =====================================================================
CREATE OR REPLACE VIEW mart_product_risk AS
WITH cat AS (
    SELECT
        primary_category                                  AS product_category,
        COUNT(*)                                          AS orders,
        SUM(revenue)                                      AS revenue,
        AVG(freight_ratio)                                AS avg_freight_ratio,
        AVG(CASE WHEN is_delivered AND is_late THEN 1.0
                 WHEN is_delivered            THEN 0 END) AS late_rate,
        AVG(CASE WHEN review_score IS NOT NULL THEN
                 CASE WHEN is_bad_review THEN 1.0 ELSE 0 END END) AS bad_review_rate
    FROM fact_orders
    WHERE primary_category IS NOT NULL
    GROUP BY primary_category
),
ranked AS (
    SELECT *,
        revenue / SUM(revenue) OVER ()                    AS revenue_share,
        SUM(revenue) OVER (ORDER BY revenue DESC)
            / SUM(revenue) OVER ()                        AS cum_revenue_share
    FROM cat
)
SELECT *,
    CASE WHEN cum_revenue_share <= 0.80 THEN 'A'
         WHEN cum_revenue_share <= 0.95 THEN 'B'
         ELSE 'C' END                                     AS abc_class
FROM ranked
ORDER BY revenue DESC;

-- =====================================================================
-- MART: supplier scorecard + tunable risk score
-- Risk = 0.30*late + 0.20*cancel + 0.20*bad_review + 0.15*freight + 0.15*volatility
-- Each component is percentile-ranked across scored suppliers (0=best,1=worst),
-- so the score is a relative risk ranking that is robust to outliers.
-- Only suppliers with >= 20 orders are scored (stable rates); MIN_ORDERS is the knob.
-- =====================================================================
CREATE OR REPLACE VIEW mart_supplier_scorecard AS
WITH supplier_orders AS (          -- distinct orders per supplier with order-level flags
    SELECT DISTINCT i.supplier_id, o.order_id, o.order_month,
           o.is_delivered, o.is_late, o.is_canceled, o.is_bad_review, o.review_score
    FROM fact_order_items i
    JOIN fact_orders o ON i.order_id = o.order_id
),
supplier_rev AS (                  -- revenue attributed to the supplier (item grain)
    SELECT supplier_id,
           SUM(item_revenue) AS revenue,
           SUM(item_freight) AS freight
    FROM fact_order_items
    GROUP BY supplier_id
),
monthly AS (                       -- monthly order counts -> demand volatility (CV)
    SELECT supplier_id, order_month, COUNT(DISTINCT order_id) AS n_orders
    FROM supplier_orders GROUP BY supplier_id, order_month
),
volatility AS (
    SELECT supplier_id,
           CASE WHEN AVG(n_orders) > 0 THEN STDDEV_SAMP(n_orders)/AVG(n_orders) END AS demand_volatility
    FROM monthly GROUP BY supplier_id
),
base AS (
    SELECT
        so.supplier_id,
        COUNT(DISTINCT so.order_id)                                       AS orders,
        sr.revenue,
        sr.freight,
        CASE WHEN sr.revenue > 0 THEN sr.freight/sr.revenue END           AS freight_burden,
        AVG(CASE WHEN so.is_delivered AND so.is_late THEN 1.0
                 WHEN so.is_delivered                THEN 0 END)          AS late_rate,
        AVG(CASE WHEN so.is_canceled THEN 1.0 ELSE 0 END)                 AS cancel_rate,
        AVG(CASE WHEN so.review_score IS NOT NULL THEN
                 CASE WHEN so.is_bad_review THEN 1.0 ELSE 0 END END)      AS bad_review_rate,
        MAX(v.demand_volatility)                                          AS demand_volatility
    FROM supplier_orders so
    JOIN supplier_rev sr ON so.supplier_id = sr.supplier_id
    LEFT JOIN volatility v ON so.supplier_id = v.supplier_id
    GROUP BY so.supplier_id, sr.revenue, sr.freight
),
scored AS (
    SELECT *,
        PERCENT_RANK() OVER (ORDER BY late_rate)         AS late_pr,
        PERCENT_RANK() OVER (ORDER BY cancel_rate)       AS cancel_pr,
        PERCENT_RANK() OVER (ORDER BY bad_review_rate)   AS badrev_pr,
        PERCENT_RANK() OVER (ORDER BY freight_burden)    AS freight_pr,
        PERCENT_RANK() OVER (ORDER BY COALESCE(demand_volatility, 0)) AS vol_pr
    FROM base
    WHERE orders >= 20                              -- MIN_ORDERS knob
)
SELECT
    supplier_id, orders, revenue, freight,
    late_rate, cancel_rate, bad_review_rate, freight_burden, demand_volatility,
    revenue / SUM(revenue) OVER ()                       AS revenue_share,
    ROUND(100 * (0.30*late_pr + 0.20*cancel_pr + 0.20*badrev_pr
               + 0.15*freight_pr + 0.15*vol_pr), 1)      AS risk_score,
    NTILE(5) OVER (ORDER BY (0.30*late_pr + 0.20*cancel_pr + 0.20*badrev_pr
               + 0.15*freight_pr + 0.15*vol_pr)) AS risk_quintile
FROM scored
ORDER BY risk_score DESC;
