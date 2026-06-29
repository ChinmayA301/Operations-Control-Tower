# Star Schema

```mermaid
erDiagram
    dim_date              ||--o{ fact_orders : order_ts
    dim_customer_region   ||--o{ fact_orders : region_state
    dim_supplier          ||--o{ fact_orders : primary_supplier_id
    dim_product_category  ||--o{ fact_orders : primary_category
    fact_orders           ||--|{ fact_order_items : order_id
    dim_supplier          ||--o{ fact_order_items : supplier_id
    dim_product_category  ||--o{ fact_order_items : product_id

    fact_orders {
        text  order_id PK
        text  region_state FK
        text  primary_supplier_id FK
        text  primary_category FK
        double revenue
        double freight
        int    delay_days
        bool   is_late
        bool   is_bad_review
    }
    fact_order_items {
        text   order_id FK
        int    order_item_id
        text   supplier_id FK
        text   product_id FK
        double item_revenue
        double item_freight
    }
    dim_supplier { text supplier_id PK
        text supplier_state }
    dim_customer_region { text region_state PK }
    dim_product_category { text product_id PK
        text product_category }
    dim_date { date date_key PK
        text year_month }
```

`fact_orders` is the order-grain fact (one row per order, denormalized for BI).
`fact_order_items` is the line-grain fact used to attribute revenue and risk to
individual suppliers. The five marts are aggregations over these two tables.
