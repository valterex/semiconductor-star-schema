"""Tests for config: environment parsing."""

from __future__ import annotations

from semiconductor_star_schema.config import Settings


def test_from_env_reads_all_vars(monkeypatch):
    monkeypatch.setenv("POSTGRES_HOST", "db")
    monkeypatch.setenv("POSTGRES_PORT", "5432")
    monkeypatch.setenv("POSTGRES_DB", "analytics")
    monkeypatch.setenv("POSTGRES_USER", "alice")
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")

    settings = Settings.from_env()

    assert settings.db_host == "db"
    assert settings.db_port == "5432"
    assert settings.db_name == "analytics"
    assert settings.db_user == "alice"
    assert settings.db_password == "secret"
