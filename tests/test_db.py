"""Tests for db: byte-chunking and the copy/report helpers."""

from __future__ import annotations

from typing import cast

import psycopg
import pytest

from semiconductor_star_schema.config import GOLD_TABLES
from semiconductor_star_schema.db import (
    CHUNK_BYTES,
    _read_chunks,
    copy_csv,
    report_gold_counts,
    run_sql_file,
)


@pytest.mark.parametrize(
    ("payload", "expected"),
    [
        (b"abcdef", [b"ab", b"cd", b"ef"]),
        (b"", []),
    ],
)
def test_read_chunks(tmp_path, payload, expected):
    path = tmp_path / "data.csv"
    path.write_bytes(payload)

    assert list(_read_chunks(path, size=2)) == expected


def test_run_sql_file_executes_file_bytes(tmp_path, conn):
    path = tmp_path / "schema.sql"
    path.write_bytes(b"SELECT 1;")

    run_sql_file(cast(psycopg.Connection, conn), path)

    assert conn.cursor_.executed == [b"SELECT 1;"]


def test_copy_csv_streams_chunks(tmp_path, conn):
    path = tmp_path / "ai_chip_market.csv"
    payload = b"a" * (CHUNK_BYTES + 10)
    path.write_bytes(payload)

    copy_csv(cast(psycopg.Connection, conn), "ai_chip_market", path)

    assert conn.cursor_.copy_statement is not None
    assert b"".join(conn.cursor_.copy_.writes) == payload


def test_report_gold_counts_queries_every_table(capsys, conn):
    report_gold_counts(cast(psycopg.Connection, conn))

    assert len(conn.cursor_.executed) == len(GOLD_TABLES)
    assert "dim_chip" in capsys.readouterr().out
