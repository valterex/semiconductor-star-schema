"""Tests for config: env parsing and the Python<->SQL mapping invariants."""

from __future__ import annotations

import re

import pytest

from semiconductor_star_schema.config import (
    BASE_DIR,
    BRONZE_SOURCES,
    GOLD_TABLES,
    SQL_DIR,
    Settings,
)

ENV = {
    "POSTGRES_HOST": "db",
    "POSTGRES_PORT": "5432",
    "POSTGRES_DB": "analytics",
    "POSTGRES_USER": "alice",
    "POSTGRES_PASSWORD": "secret",
}


def _tables_in(sql_file: str, schema: str) -> set[str]:
    """Return the table names `CREATE TABLE <schema>.<name>` in a SQL file."""
    text = (SQL_DIR / sql_file).read_text()
    return set(re.findall(rf"^CREATE TABLE {schema}\.(\w+)", text, re.MULTILINE))


def test_from_env_reads_all_vars(monkeypatch):
    monkeypatch.setenv("POSTGRES_HOST", ENV["POSTGRES_HOST"])
    monkeypatch.setenv("POSTGRES_PORT", ENV["POSTGRES_PORT"])
    monkeypatch.setenv("POSTGRES_DB", ENV["POSTGRES_DB"])
    monkeypatch.setenv("POSTGRES_USER", ENV["POSTGRES_USER"])
    monkeypatch.setenv("POSTGRES_PASSWORD", ENV["POSTGRES_PASSWORD"])

    settings = Settings.from_env()

    assert settings.db_host == "db"
    assert settings.db_port == "5432"
    assert settings.db_name == "analytics"
    assert settings.db_user == "alice"
    assert settings.db_password == "secret"


def test_from_env_applies_defaults(monkeypatch):
    monkeypatch.delenv("POSTGRES_HOST", raising=False)
    monkeypatch.delenv("POSTGRES_PORT", raising=False)
    monkeypatch.delenv("POSTGRES_DB", raising=False)
    monkeypatch.delenv("POSTGRES_USER", raising=False)
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")

    settings = Settings.from_env()

    assert settings.db_host == "127.0.0.1"
    assert settings.db_port == "5433"
    assert settings.db_name == "semicond"
    assert settings.db_user == "de"


def test_from_env_requires_password(monkeypatch):
    monkeypatch.delenv("POSTGRES_PASSWORD", raising=False)

    with pytest.raises(SystemExit):
        Settings.from_env()


def test_gold_tables_match_sql():
    assert set(GOLD_TABLES) == _tables_in("03_gold.sql", "gold")


def test_bronze_sources_match_sql():
    assert set(BRONZE_SOURCES) == _tables_in("01_bronze.sql", "bronze")


def test_sql_dir_is_rooted_at_repo_base():
    assert SQL_DIR == BASE_DIR / "sql"
