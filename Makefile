.DEFAULT_GOAL := help

.PHONY: up down down-vol ingest query diagram psql wait format lint typecheck test check help

-include .env
export

POSTGRES_USER ?= de
POSTGRES_DB ?= semicond

PSQL := docker compose exec -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(firstword $(MAKEFILE_LIST)) | sed -E 's/:.*## /: /'

up: ## Start the Postgres container
	docker compose up -d

down: ## Stop the Postgres container
	docker compose down

down-vol: ## Stop the container and delete its data volume
	docker compose down -v

wait: ## Block until Postgres accepts connections
	@until docker compose exec -T postgres pg_isready -U $(POSTGRES_USER) -d $(POSTGRES_DB) >/dev/null 2>&1; do sleep 1; done

ingest: up wait ## Download the dataset and load bronze -> silver -> gold
	uv run python -m semiconductor

query: up wait ## Run the sample analytical queries
	$(PSQL) < sql/05_queries.sql

diagram: up wait ## Regenerate diagrams/schema.mmd from the live schema
	tbls out -t mermaid -o diagrams/schema.mmd

psql: ## Open an interactive psql shell
	docker compose exec -it postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

format: ## Auto-format Python and SQL
	uv run ruff format .
	uv run ruff check --fix .
	uv run sqlfluff fix sql/

lint: ## Lint Python and SQL (read-only)
	uv run ruff check .
	uv run ruff format --check .
	uv run sqlfluff lint sql/

typecheck: ## Run basedpyright
	uv run basedpyright

test: ## Run pytest
	uv run pytest

check: lint typecheck test ## Run the full quality gate
