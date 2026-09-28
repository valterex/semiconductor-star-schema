#!/usr/bin/env python3
"""Download the semiconductor dataset via kagglehub and load it into Postgres.

Pipeline: bronze (raw TEXT) -> silver (typed/conformed) -> gold (star schema).
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import LiteralString, cast

import kagglehub
import psycopg
from psycopg import sql

BASE_DIR = Path(__file__).resolve().parent.parent
SQL_DIR = BASE_DIR / "sql"

DB_HOST = os.environ.get("POSTGRES_HOST", "127.0.0.1")
DB_PORT = os.environ.get("POSTGRES_PORT", "5433")
DB_NAME = os.environ.get("POSTGRES_DB", "semicond")
DB_USER = os.environ.get("POSTGRES_USER", "de")
DB_PASSWORD = os.environ["POSTGRES_PASSWORD"]

# bronze table -> source CSV filename (columns match the CSV header order)
SOURCES = {
    "ai_chip_market": "ai_chip_market.csv",
    "chip_companies_financials": "chip_companies_financials.csv",
    "chip_prices": "chip_prices.csv",
    "fab_capacity": "fab_capacity.csv",
    "export_controls": "export_controls.csv",
}

DDL = ["01_bronze.sql", "02_silver.sql", "03_gold.sql"]
TRANSFORM = "04_transform.sql"

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


def connect() -> psycopg.Connection:
    return psycopg.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        autocommit=True,
    )


def execute_sql_file(conn: psycopg.Connection, path: Path) -> None:
    statement = cast(LiteralString, path.read_text())
    with conn.cursor() as cur:
        cur.execute(statement)


def load_csv(conn: psycopg.Connection, table: str, csv_path: Path) -> None:
    stmt = sql.SQL("COPY bronze.{} FROM STDIN WITH (FORMAT CSV, HEADER)").format(
        sql.Identifier(table)
    )
    with conn.cursor() as cur:
        with cur.copy(stmt) as copy:
            with csv_path.open("rb") as f:
                while chunk := f.read(65536):
                    copy.write(chunk)
    print(f"  bronze.{table} <- {csv_path.name}")


def print_counts(conn: psycopg.Connection) -> None:
    print("\nGold row counts:")
    with conn.cursor() as cur:
        for table in GOLD_TABLES:
            cur.execute(
                sql.SQL("SELECT count(*) FROM gold.{}").format(sql.Identifier(table))
            )
            count = cur.fetchone()
            print(f"  {table:28} {count[0] if count else 0}")


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
        for name in DDL:
            execute_sql_file(conn, SQL_DIR / name)

        print("Loading bronze (raw)...")
        for table, filename in SOURCES.items():
            load_csv(conn, table, path / filename)

        print("Transforming bronze -> silver -> gold...")
        execute_sql_file(conn, SQL_DIR / TRANSFORM)

        print_counts(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
