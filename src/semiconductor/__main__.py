"""Package entrypoint: run the full ingest pipeline.

Usage: python -m semiconductor
"""

from __future__ import annotations

from .config import Settings
from .pipeline import run


def main() -> None:
    run(Settings.from_env())


if __name__ == "__main__":
    main()
