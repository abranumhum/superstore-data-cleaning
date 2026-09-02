PSQL_BIN ?= $(shell pg_config --bindir 2>/dev/null || echo psql)

db:
	"$(PSQL_BIN)" -U postgres -c "CREATE DATABASE superstore;" 2>/dev/null || true
	"$(PSQL_BIN)" -U postgres -c "CREATE USER superstore WITH SUPERUSER PASSWORD 'superstore';" 2>/dev/null || true

dirty:
	uv run python scripts/make_dirty.py

sql:
	./scripts/run_pipeline.sh

test:
	uv run pytest

.PHONY: db dirty sql test
