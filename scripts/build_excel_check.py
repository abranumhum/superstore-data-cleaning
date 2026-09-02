"""Create a small Excel reconciliation workbook.

Generates an Excel file with KPI summary and regional sales for a quick
spot-check. Requires openpyxl.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "excel" / "superstore_check.xlsx"


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    kpi = pd.read_csv(ROOT / "reports/kpi_summary.csv")
    region = pd.read_csv(ROOT / "reports/sales_by_region.csv")

    with pd.ExcelWriter(OUTPUT, engine="openpyxl") as writer:
        kpi.to_excel(writer, sheet_name="KPI Summary", index=False)
        region.to_excel(writer, sheet_name="Regional Sales", index=False)

    print(f"Saved: {OUTPUT}")


if __name__ == "__main__":
    main()
