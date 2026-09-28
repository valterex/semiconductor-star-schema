.PHONY: up down down-vol ingest query diagram psql wait format lint typecheck check

-include .env
export

POSTGRES_USER ?= de
POSTGRES_DB ?= semicond

PSQL := docker compose exec -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

up:
	docker compose up -d

down:
	docker compose down

down-vol:
	docker compose down -v

wait:
	@until docker compose exec -T postgres pg_isready -U $(POSTGRES_USER) -d $(POSTGRES_DB) >/dev/null 2>&1; do sleep 1; done

ingest: up wait
	uv run scripts/ingest.py

query: up wait
	$(PSQL) < sql/05_queries.sql

diagram: up wait
	tbls out -t mermaid -o diagrams/schema.mmd

psql:
	docker compose exec -it postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

format:
	uv run ruff format .
	uv run ruff check --fix .
	uv run sqlfluff fix sql/

lint:
	uv run ruff check .
	uv run ruff format --check .
	uv run sqlfluff lint sql/

typecheck:
	uv run basedpyright

check: lint typecheck
