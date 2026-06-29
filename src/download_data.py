"""
download_data.py | Supply Chain Control Tower
Fetches the raw Olist Brazilian E-Commerce CSVs into data/raw/.

The dataset originates on Kaggle (olistbr/brazilian-ecommerce, CC BY-NC-SA 4.0).
To keep the repo reproducible without Kaggle credentials, we pull the same files
from a public GitHub mirror. Swap MIRROR for your own source if it disappears.

Usage:  python src/download_data.py
"""
from __future__ import annotations
import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
MIRROR = ("https://raw.githubusercontent.com/spdrio/"
          "Brazilian-E-Commerce-Public-Dataset-by-Olist/master/files")
FILES = [
    "olist_orders_dataset.csv", "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv", "olist_order_reviews_dataset.csv",
    "olist_customers_dataset.csv", "olist_products_dataset.csv",
    "olist_sellers_dataset.csv", "product_category_name_translation.csv",
]


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    for f in FILES:
        dest = RAW / f
        if dest.exists():
            print(f"skip  {f} (exists)")
            continue
        print(f"fetch {f}")
        urllib.request.urlretrieve(f"{MIRROR}/{f}", dest)
    print("done ->", RAW)


if __name__ == "__main__":
    main()
