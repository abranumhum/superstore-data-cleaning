"""Create a reproducibly corrupted Superstore Orders CSV.

Reads the original Tableau Sample Superstore workbook and applies 6 types of
data-quality defects with a fixed seed. Python is used only to generate the
dirty test data; all cleaning is done in SQL.

Defect types:
  1. Negative values in Sales, Quantity, Discount
  2. Currency-formatted Sales ($ prefix, commas)
  3. Null markers in Customer Name, Postal Code, State/Province
  4. Mixed date formats (Order Date in MM/DD/YYYY, Ship Date in YYYY/MM/DD)
  5. Inconsistent case/whitespace in Ship Mode, Category, Region
  6. Malformed IDs (Order ID, Customer ID, Product ID with wrong case/padding)
  7. Duplicate rows
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 42


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a corrupted Superstore CSV.")
    parser.add_argument("--input", default="data/raw/sample_superstore.xls")
    parser.add_argument("--output", default="data/dirty/superstore_dirty.csv")
    parser.add_argument("--report", default="reports/corruption_summary.json")
    args = parser.parse_args()

    rng = np.random.default_rng(SEED)
    source = pd.read_excel(args.input, sheet_name="Orders")
    dirty = source.copy()

    # Standardize: write dates as YYYY-MM-DD so mixed formats are the only corruption
    dirty["Order Date"] = pd.to_datetime(dirty["Order Date"]).dt.strftime("%Y-%m-%d")
    dirty["Ship Date"] = pd.to_datetime(dirty["Ship Date"]).dt.strftime("%Y-%m-%d")

    defects: dict[str, int] = {}

    # 1. Negative values
    for col, n in [("Sales", 60), ("Quantity", 45), ("Discount", 30)]:
        idx = rng.choice(dirty.index[dirty[col] > 0].to_numpy(), size=n, replace=False)
        dirty.loc[idx, col] = -pd.to_numeric(dirty.loc[idx, col]).abs()
        defects[f"negative_{col.lower()}"] = n

    # 2. Currency-formatted sales
    idx = rng.choice(dirty.index[dirty["Sales"] > 0].to_numpy(), size=50, replace=False)
    dirty.loc[idx, "Sales"] = dirty.loc[idx, "Sales"].astype(float).map(lambda v: f"${v:,.2f}")
    defects["currency_formatted_sales"] = 50

    # 3. Null markers in important fields
    null_vals = ["NULL", "N/A", ""]
    for col, n in [("Customer Name", 30), ("Postal Code", 30), ("State/Province", 25)]:
        idx = rng.choice(dirty.index.to_numpy(), size=n, replace=False)
        dirty.loc[idx, col] = rng.choice(null_vals, size=n)
        defects[f"null_markers_{col.lower().replace(' ', '_')}"] = n

    # 4. Mixed date formats
    order_idx = rng.choice(dirty.index.to_numpy(), size=50, replace=False)
    dirty.loc[order_idx, "Order Date"] = (
        pd.to_datetime(dirty.loc[order_idx, "Order Date"]).dt.strftime("%m/%d/%Y")
    )
    defects["mixed_order_date_formats"] = 50

    ship_idx = rng.choice(dirty.index.to_numpy(), size=50, replace=False)
    dirty.loc[ship_idx, "Ship Date"] = (
        pd.to_datetime(dirty.loc[ship_idx, "Ship Date"]).dt.strftime("%Y/%m/%d")
    )
    defects["mixed_ship_date_formats"] = 50

    # 5. Inconsistent case/whitespace
    for col, n in [("Ship Mode", 50), ("Category", 50), ("Region", 50)]:
        idx = rng.choice(dirty.index.to_numpy(), size=n, replace=False)
        dirty.loc[idx, col] = dirty.loc[idx, col].map(lambda v: f"  {str(v).lower()}  ")
        defects[f"whitespace_and_case_{col.lower()}"] = n

    # 6. Malformed IDs (lowercase + surrounding spaces)
    for col, n in [("Order ID", 40), ("Customer ID", 40), ("Product ID", 40)]:
        idx = rng.choice(dirty.index.to_numpy(), size=n, replace=False)
        dirty.loc[idx, col] = dirty.loc[idx, col].map(lambda v: f" {str(v).lower()} ")
        defects[f"malformed_{col.lower().replace(' ', '_')}"] = n

    # 7. Duplicate rows
    dup_idx = rng.choice(dirty.index.to_numpy(), size=60, replace=False)
    dirty = pd.concat([dirty, dirty.loc[dup_idx]], ignore_index=True)
    defects["duplicate_rows"] = 60

    # Write outputs
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    dirty.to_csv(output, index=False)

    report = {
        "seed": SEED,
        "source_rows": int(len(source)),
        "dirty_rows": int(len(dirty)),
        "defect_types": len(defects),
        "defect_instances": int(sum(defects.values())),
        "defects_by_type": defects,
    }
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
