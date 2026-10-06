"""Tests for pipeline: ELT orchestration with the network/db layers mocked."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from semiconductor_star_schema import pipeline
from semiconductor_star_schema.config import (
    BRONZE_SOURCES,
    SCHEMA_SQL,
    SQL_DIR,
    TRANSFORM_SQL,
    Settings,
)

SETTINGS = Settings("db", "5432", "analytics", "alice", "secret")


@pytest.fixture
def mocks(tmp_path, monkeypatch):
    dataset_dir = tmp_path / "dataset"
    dataset_dir.mkdir()
    conn = MagicMock()

    monkeypatch.setattr(
        pipeline.kagglehub, "dataset_download", lambda *a, **k: str(dataset_dir)
    )
    monkeypatch.setattr(pipeline, "connect", lambda _: conn)

    run_sql_file = MagicMock()
    copy_csv = MagicMock()
    report_gold_counts = MagicMock()

    monkeypatch.setattr(pipeline, "run_sql_file", run_sql_file)
    monkeypatch.setattr(pipeline, "copy_csv", copy_csv)
    monkeypatch.setattr(pipeline, "report_gold_counts", report_gold_counts)

    return SimpleNamespace(
        conn=conn,
        dataset_dir=dataset_dir,
        run_sql_file=run_sql_file,
        copy_csv=copy_csv,
        report_gold_counts=report_gold_counts,
    )


def test_run_orchestrates_elt(mocks):
    pipeline.run(SETTINGS)

    for name in SCHEMA_SQL:
        mocks.run_sql_file.assert_any_call(mocks.conn, SQL_DIR / name)
    mocks.run_sql_file.assert_any_call(mocks.conn, SQL_DIR / TRANSFORM_SQL)

    for table, filename in BRONZE_SOURCES.items():
        mocks.copy_csv.assert_any_call(mocks.conn, table, mocks.dataset_dir / filename)

    mocks.report_gold_counts.assert_called_once_with(mocks.conn)
    mocks.conn.close.assert_called_once()


def test_run_closes_connection_on_failure(mocks):
    mocks.run_sql_file.side_effect = RuntimeError("err")

    with pytest.raises(RuntimeError, match="err"):
        pipeline.run(SETTINGS)

    mocks.conn.close.assert_called_once()
