#!/usr/bin/env python3
"""Download the semiconductor dataset via kagglehub and load it into Postgres.

Pipeline: bronze (raw TEXT) -> silver (typed/conformed) -> gold (star schema).
"""

from __future__ import annotations

import os
from pathlib import Path

import kagglehub
import psycopg
from psycopg import sql

BASE_DIR = Path(__file__).resolve().parent.parent
SQL_DIR = BASE_DIR / "sql"

DB_HOST = os.environ.get("POSTGRES_HOST", "127.0.0.1")
DB_PORT = os.environ.get("POSTGRES_PORT", "5433")
DB_NAME = os.environ.get("POSTGRES_DB", "semicond")
DB_USER = os.environ.get("POSTGRES_USER", "de")
DB_PASSWORD = os.environ.get("POSTGRES_PASSWORD")

if DB_PASSWORD is None:
    raise SystemExit("POSTGRES_PASSWORD is not set. Source .env or set it.")

# Schema-layer SQL files, applied in order. TRANSFORM_SQL runs after the CSVs
# are loaded so it can read from bronze.
SCHEMA_SQL = ["01_bronze.sql", "02_silver.sql", "03_gold.sql"]
TRANSFORM_SQL = "04_transform.sql"

# bronze table -> source CSV filename (columns match the CSV header order)
BRONZE_SOURCES = {
    "ai_chip_market": "ai_chip_market.csv",
    "chip_companies_financials": "chip_companies_financials.csv",
    "chip_prices": "chip_prices.csv",
    "fab_capacity": "fab_capacity.csv",
    "export_controls": "export_controls.csv",
}

# Must match the tables created in sql/03_gold.sql.
GOLD_TABLES = [
    "dim_chip",
    "dim_company",
    "dim_date",
    "dim_fab",
    "dim_product",
    "export_control_event",
    "fact_chip_year",
    "fact_fab_capacity_year",
    "fact_financials_year",
    "fact_product_price_month",
]

CHUNK_BYTES = 64 * 1024


def connect() -> psycopg.Connection:
    """Open a connection in autocommit so each statement commits immediately."""
    return psycopg.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        autocommit=True,
    )


def run_sql_file(conn: psycopg.Connection, path: Path) -> None:
    """Apply a SQL file, which may contain multiple statements."""
    with conn.cursor() as cur:
        cur.execute(path.read_bytes())


def copy_csv(conn: psycopg.Connection, table: str, csv_path: Path) -> None:
    """Stream a CSV into a bronze table via COPY."""
    stmt = sql.SQL("COPY bronze.{} FROM STDIN WITH (FORMAT CSV, HEADER)").format(
        sql.Identifier(table)
    )
    with conn.cursor() as cur:
        with cur.copy(stmt) as copy:
            with csv_path.open("rb") as f:
                while chunk := f.read(CHUNK_BYTES):
                    copy.write(chunk)
    print(f"  bronze.{table} <- {csv_path.name}")


def report_gold_counts(conn: psycopg.Connection) -> None:
    """Print the row count of each gold table."""
    print("\nGold row counts:")
    with conn.cursor() as cur:
        for table in GOLD_TABLES:
            cur.execute(
                sql.SQL("SELECT count(*) FROM gold.{}").format(sql.Identifier(table))
            )
            row = cur.fetchone()
            assert row is not None  # count(*) always returns one row
            print(f"  {table:28} {row[0]}")


def main() -> None:
    path = Path(
        kagglehub.dataset_download(
            "sergionefedov/global-semiconductor-industry-2010-2026"
        )
    )
    print(f"Dataset downloaded to: {path}")

    conn = connect()
    try:
        print("Creating bronze/silver/gold schemas...")
        for name in SCHEMA_SQL:
            run_sql_file(conn, SQL_DIR / name)

        print("Loading bronze (raw)...")
        for table, filename in BRONZE_SOURCES.items():
            copy_csv(conn, table, path / filename)

        print("Transforming bronze -> silver -> gold...")
        run_sql_file(conn, SQL_DIR / TRANSFORM_SQL)

        report_gold_counts(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
