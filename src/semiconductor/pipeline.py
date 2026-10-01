"""ELT orchestration: extract (download), load (COPY), transform (in-DB SQL)."""

from __future__ import annotations

from pathlib import Path

import kagglehub

from .config import BRONZE_SOURCES, SCHEMA_SQL, SQL_DIR, TRANSFORM_SQL, Settings
from .db import connect, copy_csv, report_gold_counts, run_sql_file

DATASET = "sergionefedov/global-semiconductor-industry-2010-2026"


def run(settings: Settings) -> None:
    """Extract -> load -> transform, then print gold row counts."""
    csv_dir = Path(kagglehub.dataset_download(DATASET))
    print(f"Dataset downloaded to: {csv_dir}")

    conn = connect(settings)

    try:
        print("Creating bronze/silver/gold schemas...")
        for name in SCHEMA_SQL:
            run_sql_file(conn, SQL_DIR / name)

        print("Loading...")
        for table, filename in BRONZE_SOURCES.items():
            copy_csv(conn, table, csv_dir / filename)

        print("Transforming...")
        run_sql_file(conn, SQL_DIR / TRANSFORM_SQL)

        report_gold_counts(conn)
    finally:
        conn.close()


__all__ = ["run"]
