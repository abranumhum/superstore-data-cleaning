#!/usr/bin/env bash
set -euo pipefail

# Superstore SQL Data Cleaning Pipeline
# Loads a dirty CSV into PostgreSQL, runs SQL quality checks + cleaning + analysis.
#
# Requires: PostgreSQL with psql, libpq env vars set (PGHOST, PGPORT, PGDATABASE, PGUSER)

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PSQL_BIN=${PSQL_BIN:-psql}
DIRTY_CSV="$ROOT_DIR/data/dirty/superstore_dirty.csv"

for variable in PGHOST PGPORT PGDATABASE PGUSER; do
    [[ -n ${!variable:-} ]] || { printf 'Set %s for the PostgreSQL connection.\n' "$variable" >&2; exit 2; }
done

# 1. Schema (create tables)
"$PSQL_BIN" -X -v ON_ERROR_STOP=1 -f "$ROOT_DIR/sql/01_load.sql"

# 2. Load dirty CSV
"$PSQL_BIN" -X -v ON_ERROR_STOP=1 -c "\copy raw.orders FROM '$DIRTY_CSV' WITH (FORMAT csv, HEADER true)"

# 3. SQL: quality checks → cleaning → analysis
for sql_file in 02_quality_checks.sql 03_cleaning.sql 04_analysis.sql; do
    "$PSQL_BIN" -X -v ON_ERROR_STOP=1 -f "$ROOT_DIR/sql/$sql_file"
    echo "OK: $sql_file"
done

# 4. Export reports
"$PSQL_BIN" -X -t -c "\copy (SELECT * FROM analytics.clean_orders ORDER BY row_id) TO '$ROOT_DIR/data/clean/superstore_clean.csv' WITH (FORMAT csv, HEADER true)"
"$PSQL_BIN" -X -t -c "\copy (SELECT * FROM analytics.dq_summary ORDER BY defect_type) TO '$ROOT_DIR/reports/dq_summary.csv' WITH (FORMAT csv, HEADER true)"
"$PSQL_BIN" -X -t -c "\copy (SELECT * FROM analytics.business_summary ORDER BY metric_name) TO '$ROOT_DIR/reports/business_summary.csv' WITH (FORMAT csv, HEADER true)"
"$PSQL_BIN" -X -t -c "\copy (SELECT * FROM analytics.kpi_summary) TO '$ROOT_DIR/reports/kpi_summary.csv' WITH (FORMAT csv, HEADER true)"
"$PSQL_BIN" -X -t -c "\copy (SELECT * FROM analytics.sales_by_region ORDER BY total_sales DESC) TO '$ROOT_DIR/reports/sales_by_region.csv' WITH (FORMAT csv, HEADER true)"
"$PSQL_BIN" -X -t -c "\copy (SELECT * FROM analytics.profitability_by_category ORDER BY total_profit ASC) TO '$ROOT_DIR/reports/profitability_by_category.csv' WITH (FORMAT csv, HEADER true)"

# 5. Print summary
echo ""
echo "=== Pipeline complete ==="
echo "Clean rows:    $( "$PSQL_BIN" -X -t -c "SELECT count(*) FROM analytics.clean_orders" | tr -d ' ' )"
echo "DQ found:      $( "$PSQL_BIN" -X -t -c "SELECT sum(issue_count) FROM analytics.dq_summary" | tr -d ' ' )"
echo "Dirty sales:   $( "$PSQL_BIN" -X -t -c "SELECT round(sum(replace(replace(\"Sales\", '\$', ''), ',', '')::numeric), 2) FROM raw.orders WHERE \"Sales\" IS NOT NULL" | tr -d ' ' )"
echo "Clean sales:   $( "$PSQL_BIN" -X -t -c "SELECT round(sum(sales), 2) FROM analytics.clean_orders" | tr -d ' ' )"
