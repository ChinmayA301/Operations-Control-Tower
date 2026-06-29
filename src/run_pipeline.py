"""
run_pipeline.py | Supply Chain Control Tower

Reproducible end-to-end build:
  raw Olist CSVs  ->  DuckDB star schema + cleaning  ->  KPI marts  ->  CSV exports

Usage (from repo root, venv active):
    python src/run_pipeline.py

Outputs:
    data/processed/control_tower.duckdb   persisted database
    data/processed/mart_*.csv             Looker Studio data sources
    docs/_headline_kpis.json              numbers cited in the README / memo
"""
from __future__ import annotations
import json
import pathlib
import duckdb

ROOT = pathlib.Path(__file__).resolve().parents[1]
SQL = ROOT / "sql"
PROC = ROOT / "data" / "processed"
DOCS = ROOT / "docs"
MARTS = [
    "mart_exec_kpis",
    "mart_monthly",
    "mart_region",
    "mart_product_risk",
    "mart_supplier_scorecard",
]


def main() -> None:
    PROC.mkdir(parents=True, exist_ok=True)
    db_path = PROC / "control_tower.duckdb"
    if db_path.exists():
        db_path.unlink()
    con = duckdb.connect(str(db_path))

    for step in ["01_schema.sql", "02_cleaning.sql", "03_kpi_views.sql"]:
        print(f"-> executing {step}")
        con.execute((SQL / step).read_text())

    # Export each mart to CSV for the BI layer
    for mart in MARTS:
        out = PROC / f"{mart}.csv"
        con.execute(f"COPY (SELECT * FROM {mart}) TO '{out}' (HEADER, DELIMITER ',')")
        n = con.execute(f"SELECT COUNT(*) FROM {mart}").fetchone()[0]
        print(f"   wrote {out.name:32s} ({n:,} rows)")

    # Also export the order-grain fact for ad-hoc analysis / EDA notebook
    con.execute(
        f"COPY (SELECT * FROM fact_orders) TO '{PROC/'fact_orders.csv'}' (HEADER, DELIMITER ',')"
    )

    # Headline KPIs -> JSON (single source of truth for narrative docs)
    kpis = dict(con.execute("SELECT kpi, value FROM mart_exec_kpis").fetchall())
    DOCS.mkdir(exist_ok=True)
    (DOCS / "_headline_kpis.json").write_text(json.dumps(kpis, indent=2))

    print("\n=== HEADLINE KPIs ===")
    fmt = {
        "total_orders": "{:,.0f}",
        "delivered_orders": "{:,.0f}",
        "total_revenue_brl": "R$ {:,.0f}",
        "total_freight_brl": "R$ {:,.0f}",
        "freight_to_revenue": "{:.1%}",
        "on_time_rate": "{:.1%}",
        "late_rate": "{:.1%}",
        "avg_delay_days_late": "{:.1f} days",
        "cancel_rate": "{:.2%}",
        "bad_review_rate": "{:.1%}",
        "revenue_exposed_to_late_brl": "R$ {:,.0f}",
    }
    for k, v in kpis.items():
        print(f"  {k:30s} {fmt.get(k, '{}').format(v)}")
    con.close()


if __name__ == "__main__":
    main()
