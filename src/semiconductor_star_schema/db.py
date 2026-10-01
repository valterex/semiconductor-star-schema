"""Postgres access: connect, run SQL files, stream CSVs, and report counts."""

from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path

import psycopg
from psycopg import sql

from .config import GOLD_TABLES, Settings

CHUNK_BYTES = 64 * 1024


def connect(settings: Settings) -> psycopg.Connection:
    """Open a connection in autocommit so each statement commits immediately."""
    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
        autocommit=True,
    )


def run_sql_file(conn: psycopg.Connection, path: Path) -> None:
    """Apply a SQL file, which may contain multiple statements."""
    with conn.cursor() as cur:
        cur.execute(path.read_bytes())


def _read_chunks(path: Path, size: int) -> Iterator[bytes]:
    """Yield `size`-byte chunks of a file."""
    with path.open("rb") as f:
        while chunk := f.read(size):
            yield chunk


def copy_csv(conn: psycopg.Connection, table: str, csv_path: Path) -> None:
    """Stream a CSV into a bronze table via COPY."""
    statement = sql.SQL("COPY bronze.{} FROM STDIN WITH (FORMAT CSV, HEADER)").format(
        sql.Identifier(table)
    )

    with conn.cursor() as cur:
        with cur.copy(statement) as copy:
            for chunk in _read_chunks(csv_path, CHUNK_BYTES):
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


__all__ = ["connect", "run_sql_file", "copy_csv", "report_gold_counts"]
