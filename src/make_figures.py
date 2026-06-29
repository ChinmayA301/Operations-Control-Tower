"""
make_figures.py | Supply Chain Control Tower
Generates the static analysis figures used in the README / case study.
These are real outputs of the pipeline (not mockups); the Looker Studio
dashboard presents the same marts interactively.

Usage (from repo root, venv active, after run_pipeline.py):
    python src/make_figures.py   ->  assets/figures/*.png
"""
from __future__ import annotations
import pathlib
import duckdb
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

ROOT = pathlib.Path(__file__).resolve().parents[1]
FIG = ROOT / "assets" / "figures"
FIG.mkdir(parents=True, exist_ok=True)
con = duckdb.connect(str(ROOT / "data" / "processed" / "control_tower.duckdb"))

INK, ACCENT, BAD, GOOD, GRID = "#1f2933", "#2b6cb0", "#c0392b", "#2e8b57", "#e2e8f0"
plt.rcParams.update({
    "figure.dpi": 130, "savefig.dpi": 130, "font.size": 11,
    "axes.edgecolor": INK, "axes.labelcolor": INK, "text.color": INK,
    "xtick.color": INK, "ytick.color": INK, "axes.titleweight": "bold",
    "axes.grid": True, "grid.color": GRID, "axes.axisbelow": True,
})


def save(fig, name):
    fig.tight_layout()
    fig.savefig(FIG / name, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("wrote", name)


# 1. The money insight: late delivery vs satisfaction --------------------
d = con.execute("""
    SELECT CASE WHEN is_late THEN 'Late' ELSE 'On-time' END AS bucket,
           AVG(CASE WHEN is_bad_review THEN 1.0 ELSE 0 END) AS bad_rate,
           AVG(review_score) AS avg_score
    FROM fact_orders WHERE is_delivered AND review_score IS NOT NULL
    GROUP BY 1 ORDER BY 1 DESC""").df()
fig, ax = plt.subplots(figsize=(6, 4))
bars = ax.bar(d.bucket, d.bad_rate, color=[GOOD, BAD], width=0.6)
ax.yaxis.set_major_formatter(mticker.PercentFormatter(1.0))
ax.set_title("Late delivery is the #1 driver of bad reviews")
ax.set_ylabel("Share of orders rated 1–2 stars")
for b, s in zip(bars, d.avg_score):
    ax.text(b.get_x()+b.get_width()/2, b.get_height()+0.01,
            f"{b.get_height():.0%}\n(avg {s:.2f}★)", ha="center", va="bottom", fontsize=10)
ax.set_ylim(0, 0.75)
save(fig, "01_late_vs_satisfaction.png")

# 2. On-time rate trend over time ----------------------------------------
m = con.execute("""SELECT order_month, on_time_rate, orders FROM mart_monthly
                   WHERE order_month BETWEEN '2017-01' AND '2018-08' ORDER BY 1""").df()
fig, ax = plt.subplots(figsize=(8, 4))
ax.plot(m.order_month, m.on_time_rate, marker="o", color=ACCENT, lw=2)
ax.yaxis.set_major_formatter(mticker.PercentFormatter(1.0))
ax.set_title("On-time delivery rate by month")
ax.set_ylabel("On-time rate"); ax.set_ylim(0.85, 1.0)
ax.tick_params(axis="x", rotation=60)
save(fig, "02_ontime_trend.png")

# 3. Late rate by region -------------------------------------------------
r = con.execute("""SELECT region_state, late_rate FROM mart_region
                   WHERE orders>=500 ORDER BY late_rate DESC LIMIT 12""").df()
fig, ax = plt.subplots(figsize=(7, 4.5))
colors = [BAD if v >= 0.10 else ACCENT for v in r.late_rate]
ax.barh(r.region_state[::-1], r.late_rate[::-1], color=colors[::-1])
ax.xaxis.set_major_formatter(mticker.PercentFormatter(1.0))
ax.set_title("Late-delivery rate by customer state (≥500 orders)")
ax.set_xlabel("Late rate")
save(fig, "03_late_by_region.png")

# 4. Category risk bubble: revenue vs late, size = bad-review -------------
c = con.execute("""SELECT product_category, revenue, late_rate, bad_review_rate,
                   avg_freight_ratio FROM mart_product_risk
                   WHERE abc_class IN ('A','B') ORDER BY revenue DESC""").df()
fig, ax = plt.subplots(figsize=(8, 5))
sc = ax.scatter(c.revenue/1e6, c.late_rate, s=c.bad_review_rate*1200,
                c=c.avg_freight_ratio, cmap="OrRd", alpha=0.8, edgecolor=INK, linewidth=0.5)
ax.yaxis.set_major_formatter(mticker.PercentFormatter(1.0))
ax.set_xlabel("Category revenue (R$ millions)"); ax.set_ylabel("Late rate")
ax.set_title("Category risk map (bubble = bad-review rate, color = freight burden)")
for _, row in c.head(6).iterrows():
    ax.annotate(row.product_category, (row.revenue/1e6, row.late_rate),
                fontsize=8, xytext=(4, 4), textcoords="offset points")
fig.colorbar(sc, label="Freight / revenue")
save(fig, "04_category_risk_map.png")

# 5. Supplier risk scatter -----------------------------------------------
s = con.execute("""SELECT late_rate, bad_review_rate, revenue, risk_score
                   FROM mart_supplier_scorecard""").df()
fig, ax = plt.subplots(figsize=(7.5, 5))
sc = ax.scatter(s.late_rate, s.bad_review_rate, s=s.revenue/200,
                c=s.risk_score, cmap="RdYlGn_r", alpha=0.7, edgecolor=INK, linewidth=0.3)
ax.xaxis.set_major_formatter(mticker.PercentFormatter(1.0))
ax.yaxis.set_major_formatter(mticker.PercentFormatter(1.0))
ax.set_xlabel("Late rate"); ax.set_ylabel("Bad-review rate")
ax.set_title("Supplier risk landscape (size = revenue, color = risk score)")
fig.colorbar(sc, label="Risk score (0–100)")
save(fig, "05_supplier_risk_scatter.png")

# 6. ABC Pareto ----------------------------------------------------------
a = con.execute("""SELECT product_category, revenue_share, cum_revenue_share, abc_class
                   FROM mart_product_risk ORDER BY revenue DESC""").df()
fig, ax = plt.subplots(figsize=(9, 4.5))
cmap = {"A": "#2b6cb0", "B": "#e1a948", "C": "#cbd5e0"}
ax.bar(range(len(a)), a.revenue_share, color=[cmap[x] for x in a.abc_class])
ax2 = ax.twinx()
ax2.plot(range(len(a)), a.cum_revenue_share, color=INK, lw=1.8)
ax2.axhline(0.8, ls="--", color=BAD, lw=1)
ax2.yaxis.set_major_formatter(mticker.PercentFormatter(1.0))
ax.yaxis.set_major_formatter(mticker.PercentFormatter(1.0))
ax.set_title("ABC revenue concentration across product categories")
ax.set_ylabel("Category revenue share"); ax2.set_ylabel("Cumulative share")
ax.set_xticks([]); ax.set_xlabel("Categories (sorted by revenue)")
save(fig, "06_abc_pareto.png")

con.close()
print("done")
