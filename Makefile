PSQL_BIN ?= $(shell pg_config --bindir 2>/dev/null || echo psql)

db:
	"$(PSQL_BIN)" -U postgres -c "CREATE DATABASE superstore;" 2>/dev/null || true
	"$(PSQL_BIN)" -U postgres -c "CREATE USER superstore WITH SUPERUSER PASSWORD 'superstore';" 2>/dev/null || true

dirty:
	uv run python scripts/make_dirty.py

sql:
	./scripts/run_pipeline.sh

validate:
	uv run python scripts/validate_outputs.py

excel:
	uv run python scripts/build_excel_check.py

test:
	uv run pytest

.PHONY: db dirty sql validate excel test
