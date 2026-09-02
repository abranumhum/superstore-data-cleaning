# Superstore SQL Data Cleaning

A PostgreSQL-first project that cleans a deliberately corrupted version of Tableau's
**Sample Superstore** data using SQL, then produces business analysis.

## What it does

1. **Python** (`make dirty`) — reads the original workbook and creates a dirty CSV with 7
   types of defects: negative values, currency formatting, null markers, mixed date formats,
   inconsistent case/whitespace, malformed IDs, and duplicate rows.
2. **PostgreSQL** (`make sql`) — detects quality issues, cleans the data (TRIM, UPPER,
   REPLACE, CASE, ROW_NUMBER), adds constraints, and computes KPIs.
3. **Reports** — exports a DQ summary and business metrics to CSV.

## Quick start

```bash
# 1. Install Python deps (for data generation)
uv sync

# 2. Get PostgreSQL running and set env vars
export PGHOST=localhost PGPORT=5432 PGDATABASE=superstore PGUSER=postgres

# 3. Generate dirty data → run SQL pipeline → export reports
make dirty
make sql

# 4. Run tests
make test
```

## Data defects

The `make_dirty.py` script applies a fixed seed (42) and creates:

| Defect type | Instances |
|---|---|
| Negative Sales, Quantity, Discount | 135 |
| Currency-formatted Sales ($37.68, $1,349.85…) | 50 |
| Null markers in Customer Name, Postal Code, State/Province | ~90 |
| Mixed date formats (MM/DD/YYYY, YYYY/MM/DD) | 100 |
| Whitespace + lowercase on Ship Mode, Category, Region, Segment | 150+ |
| Malformed IDs (lowercase, extra spaces) | 120 |
| Duplicate rows | 60 |

Each defect type count is saved to `reports/corruption_summary.json`.

## SQL pipeline

| File | Purpose |
|---|---|
| `sql/01_load.sql` | Create raw table matching CSV columns |
| `sql/02_quality_checks.sql` | Detect and count each defect type |
| `sql/03_cleaning.sql` | Standardize, deduplicate, quarantine, add constraints |
| `sql/04_analysis.sql` | KPIs, regional/category performance, discount impact, monthly trend |

Cleaning uses only standard SQL: `TRIM`, `UPPER`, `INITCAP`, `REPLACE`, `CASE`, `COALESCE`,
`ROW_NUMBER()`, `REGEXP_REPLACE`. No PL/pgSQL functions.

## Key results

- **10,194 clean rows** out of 10,254 dirty rows (60 duplicates removed).
- **0** data quality issues remain after cleaning (no negative sales, no negative
  quantities, no out-of-range discounts, no duplicates).
- Dirty data shows different totals: 481 quality issues detected in `reports/dq_summary.csv`.
- High discounts (>20%) correlate with lower profit margins.
- West region has the highest sales; Central has the lowest margin.

## Project structure

```text
data/       raw/  dirty/  clean/
sql/        01_load  02_quality_checks  03_cleaning  04_analysis
scripts/    make_dirty.py  run_pipeline.sh
reports/    dq_summary.csv  business_summary.csv  corruption_summary.json
tests/      test_pipeline.py
Makefile    pyproject.toml  README.md
```

## License

Code: MIT. Source dataset: Tableau Sample Superstore (Tableau's terms).
