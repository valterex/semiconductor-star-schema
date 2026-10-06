"""Shared fakes and fixtures for exercising the psycopg helpers.

The ``db`` helpers take a ``psycopg.Connection``; these lightweight stand-ins
avoid the need for a live Postgres instance.
"""

from __future__ import annotations

import pytest
from psycopg.sql import Composed


class FakeCopy:
    def __init__(self) -> None:
        self.writes: list[bytes] = []

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def write(self, data: bytes) -> None:
        self.writes.append(data)


class FakeCursor:
    def __init__(self) -> None:
        self.executed: list[object] = []
        self.copy_statement: Composed | None = None
        self.copy_ = FakeCopy()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def execute(self, data) -> None:
        self.executed.append(data)

    def fetchone(self):
        return (42,)

    def copy(self, statement: Composed) -> FakeCopy:
        self.copy_statement = statement
        return self.copy_


class FakeConn:
    def __init__(self) -> None:
        self.cursor_ = FakeCursor()

    def cursor(self):
        return self.cursor_


@pytest.fixture
def conn() -> FakeConn:
    return FakeConn()
