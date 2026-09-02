"""Independent validation of the cleaned Superstore output.

Uses pandas to check the exported CSVs against basic business rules.
Not part of the SQL pipeline — this is a separate verification step.
"""

from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_COLUMNS = [
    "row_id", "order_id", "order_date", "ship_date", "ship_mode",
    "customer_id", "customer_name", "segment", "country_region", "city",
    "state_province", "postal_code", "region", "product_id", "category",
    "sub_category", "product_name", "sales", "quantity", "discount", "profit",
]


def validate() -> dict[str, object]:
    clean = pd.read_csv(ROOT / "data/clean/superstore_clean.csv", dtype={"postal_code": "string"})
    dq = pd.read_csv(ROOT / "reports/dq_summary.csv")

    checks = {
        "clean_columns": list(clean.columns) == EXPECTED_COLUMNS,
        "row_id_unique": clean["row_id"].is_unique,
        "sales_non_negative": (clean["sales"] >= 0).all(),
        "quantity_positive": (clean["quantity"] > 0).all(),
        "discount_valid": clean["discount"].between(0, 1).all(),
        "ship_after_order": (pd.to_datetime(clean["ship_date"], errors="coerce")
                             >= pd.to_datetime(clean["order_date"], errors="coerce")).all(),
        "dq_report_has_findings": len(dq) > 0 and dq["issue_count"].sum() > 0,
    }

    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise AssertionError(f"Validation failed: {', '.join(failed)}")

    result = {
        "status": "passed",
        "checks_passed": len(checks),
        "clean_rows": len(clean),
        "dq_findings": int(dq["issue_count"].sum()),
    }
    print(json.dumps(result, indent=2))
    return result


if __name__ == "__main__":
    validate()
