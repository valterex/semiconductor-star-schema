"""Run configuration: environment-derived settings and schema/source mappings."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent
SQL_DIR = BASE_DIR / "sql"

# Schema-layer SQL files, applied in order.
# TRANSFORM_SQL runs after the CSVs are loaded so it can read from bronze.
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


@dataclass(frozen=True)
class Settings:
    db_host: str
    db_port: str
    db_name: str
    db_user: str
    db_password: str

    @classmethod
    def from_env(cls) -> Settings:
        password = os.environ.get("POSTGRES_PASSWORD")
        if password is None:
            raise SystemExit(
                "POSTGRES_PASSWORD is not set. Source .env or set it.")

        return cls(
            db_host=os.environ.get("POSTGRES_HOST", "127.0.0.1"),
            db_port=os.environ.get("POSTGRES_PORT", "5433"),
            db_name=os.environ.get("POSTGRES_DB", "semicond"),
            db_user=os.environ.get("POSTGRES_USER", "de"),
            db_password=password,
        )


__all__ = [
    "BASE_DIR",
    "SQL_DIR",
    "SCHEMA_SQL",
    "TRANSFORM_SQL",
    "BRONZE_SOURCES",
    "GOLD_TABLES",
    "Settings",
]
