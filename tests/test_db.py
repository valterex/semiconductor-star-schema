"""Tests for the pure byte-chunking helper in db."""

from __future__ import annotations

from semiconductor_star_schema.db import _read_chunks


def test_read_chunks_splits_evenly(tmp_path):
    path = tmp_path / "data.csv"
    path.write_bytes(b"abcdef")

    chunks = list(_read_chunks(path, size=2))

    assert chunks == [b"ab", b"cd", b"ef"]


def test_read_chunks_last_chunk_is_partial(tmp_path):
    path = tmp_path / "data.csv"
    path.write_bytes(b"abcde")

    chunks = list(_read_chunks(path, size=2))

    assert chunks == [b"ab", b"cd", b"e"]


def test_read_chunks_empty_file_yields_nothing(tmp_path):
    path = tmp_path / "empty.csv"
    path.write_bytes(b"")

    assert list(_read_chunks(path, size=2)) == []
