"""Smoke tests for the Superstore SQL Data Cleaning pipeline.

Run with: make test  (requires PostgreSQL connection env vars)
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


def _psql_env() -> dict[str, str]:
    env = os.environ.copy()
    if not all(env.get(v) for v in ("PGHOST", "PGPORT", "PGDATABASE", "PGUSER")):
        pytest.skip("PostgreSQL env vars not set (PGHOST/PGPORT/PGDATABASE/PGUSER)")
    return env


def _psql(psql_bin: str, env: dict[str, str], sql: str) -> str:
    result = subprocess.run(
        [psql_bin, "-X", "-Atqc", sql],
        cwd=ROOT, env=env, capture_output=True, text=True, check=True,
    )
    return result.stdout.strip()


@pytest.mark.integration
def test_pipeline_produces_clean_rows() -> None:
    env = _psql_env()
    psql = os.environ.get("PSQL_BIN", "psql")
    subprocess.run(["bash", str(ROOT / "scripts/run_pipeline.sh")], cwd=ROOT, env=env, check=True)
    # 60 duplicates removed from 10254 → 10194 clean rows
    assert _psql(psql, env, "SELECT count(*) FROM analytics.clean_orders") == "10194"


@pytest.mark.integration
def test_no_data_quality_issues_remain() -> None:
    env = _psql_env()
    psql = os.environ.get("PSQL_BIN", "psql")
    # After cleaning: no negatives, no duplicates, discount in [0,1]
    assert _psql(
        psql, env,
        "SELECT count(*) FROM analytics.clean_orders "
        "WHERE sales < 0 OR quantity <= 0 OR discount NOT BETWEEN 0 AND 1"
    ) == "0"
    assert _psql(psql, env, "SELECT count(*) FROM analytics.clean_orders WHERE row_id IS NULL") == "0"
    # No duplicate row_ids
    assert int(_psql(
        psql, env,
        "SELECT count(*) - count(DISTINCT row_id) FROM analytics.clean_orders"
    )) == 0


@pytest.mark.integration
def test_dirty_and_clean_sales_differ() -> None:
    env = _psql_env()
    psql = os.environ.get("PSQL_BIN", "psql")
    dirty = float(_psql(psql, env, "SELECT round(sum(replace(replace(\"Sales\", '$', ''), ',', '')::numeric), 2) FROM raw.orders WHERE \"Sales\" IS NOT NULL"))
    clean = float(_psql(psql, env, "SELECT round(sum(sales), 2) FROM analytics.clean_orders"))
    # Dirty data should show different totals due to negatives and currency formatting
    assert dirty != clean


@pytest.mark.integration
def test_kpi_summary_has_reasonable_totals() -> None:
    env = _psql_env()
    psql = os.environ.get("PSQL_BIN", "psql")
    kpi = _psql(psql, env, "SELECT total_sales, total_profit, total_orders FROM analytics.kpi_summary")
    parts = kpi.split("|")
    total_sales = float(parts[0])
    total_profit = float(parts[1])
    assert 2_000_000 < total_sales < 3_000_000
    assert total_profit > 200_000
    assert int(parts[2]) == 10194
