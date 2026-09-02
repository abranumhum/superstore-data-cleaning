from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_required_project_files_exist() -> None:
    required = [
        "sql/01_load.sql",
        "sql/02_quality_checks.sql",
        "sql/03_cleaning.sql",
        "sql/04_analysis.sql",
        "scripts/make_dirty.py",
        "scripts/run_pipeline.sh",
        "Makefile",
        "README.md",
        "pyproject.toml",
    ]
    missing = [p for p in required if not (ROOT / p).is_file()]
    assert not missing, f"Missing project artifacts: {missing}"


def test_no_custom_sql_functions() -> None:
    """Junior-style project uses only built-in SQL functions."""
    sql = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((ROOT / "sql").glob("*.sql"))
    ).lower()
    assert "create function" not in sql
    assert "create procedure" not in sql


def test_readme_is_concise() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    assert len(readme) < 3500
    assert "Superstore" in readme
    assert "PostgreSQL" in readme
