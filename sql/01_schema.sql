-- =====================================================================
-- 01_schema.sql  |  Supply Chain Control Tower
-- Staging views over the raw Olist CSVs + dimensional model (star schema)
-- Engine: DuckDB. Run from the repo root (paths are relative to ./data/raw).
--   duckdb control_tower.duckdb
--   .read sql/01_schema.sql
-- =====================================================================

-- ---------- STAGING VIEWS (read raw CSVs as-is) ----------------------
CREATE OR REPLACE VIEW stg_orders AS
    SELECT * FROM read_csv_auto('data/raw/olist_orders_dataset.csv', header=true);

CREATE OR REPLACE VIEW stg_order_items AS
    SELECT * FROM read_csv_auto('data/raw/olist_order_items_dataset.csv', header=true);

CREATE OR REPLACE VIEW stg_payments AS
    SELECT * FROM read_csv_auto('data/raw/olist_order_payments_dataset.csv', header=true);

CREATE OR REPLACE VIEW stg_reviews AS
    SELECT * FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv', header=true);

CREATE OR REPLACE VIEW stg_customers AS
    SELECT * FROM read_csv_auto('data/raw/olist_customers_dataset.csv', header=true);

CREATE OR REPLACE VIEW stg_products AS
    SELECT * FROM read_csv_auto('data/raw/olist_products_dataset.csv', header=true);

CREATE OR REPLACE VIEW stg_sellers AS
    SELECT * FROM read_csv_auto('data/raw/olist_sellers_dataset.csv', header=true);

CREATE OR REPLACE VIEW stg_category_translation AS
    SELECT * FROM read_csv_auto('data/raw/product_category_name_translation.csv', header=true);

-- ---------- DIMENSIONS ----------------------------------------------
-- dim_supplier  (Olist "seller" == our "supplier")
CREATE OR REPLACE TABLE dim_supplier AS
SELECT
    seller_id                              AS supplier_id,
    UPPER(TRIM(seller_state))              AS supplier_state,
    LOWER(TRIM(seller_city))               AS supplier_city
FROM stg_sellers;

-- dim_customer_region  (region = Brazilian state of the customer)
CREATE OR REPLACE TABLE dim_customer_region AS
SELECT DISTINCT
    UPPER(TRIM(customer_state))            AS region_state
FROM stg_customers
WHERE customer_state IS NOT NULL;

-- dim_product_category  (English-translated category names)
CREATE OR REPLACE TABLE dim_product_category AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')
                                           AS product_category,
    p.product_weight_g,
    (p.product_length_cm * p.product_height_cm * p.product_width_cm) AS product_volume_cm3
FROM stg_products p
LEFT JOIN stg_category_translation t
       ON p.product_category_name = t.product_category_name;

-- dim_date  (one row per calendar date spanned by orders)
CREATE OR REPLACE TABLE dim_date AS
WITH bounds AS (
    SELECT MIN(CAST(order_purchase_timestamp AS DATE)) AS d0,
           MAX(CAST(order_purchase_timestamp AS DATE)) AS d1
    FROM stg_orders
)
SELECT
    d                                      AS date_key,
    EXTRACT(year    FROM d)                AS year,
    EXTRACT(quarter FROM d)                AS quarter,
    EXTRACT(month   FROM d)                AS month,
    STRFTIME(d, '%Y-%m')                   AS year_month,
    DAYNAME(d)                             AS day_name
FROM bounds, UNNEST(GENERATE_SERIES(d0, d1, INTERVAL 1 DAY)) AS g(d);
