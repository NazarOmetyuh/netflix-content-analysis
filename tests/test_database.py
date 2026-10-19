"""Reconciles the PostgreSQL tables with the CSV files.

Skipped when there is no .env file or the database can't be reached.
"""
import os
from pathlib import Path

import pandas as pd
import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def db():
    sqlalchemy = pytest.importorskip("sqlalchemy")
    dotenv = pytest.importorskip("dotenv")
    if not (ROOT / ".env").exists():
        pytest.skip("no .env file with database settings")
    dotenv.load_dotenv(ROOT / ".env")
    url = (f"postgresql+psycopg2://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}"
           f"@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}")
    try:
        engine = sqlalchemy.create_engine(url)
        with engine.connect() as conn:
            conn.execute(sqlalchemy.text("SELECT 1"))
    except Exception as error:
        pytest.skip(f"database not reachable: {error}")
    return engine


@pytest.mark.parametrize("table, csv", [
    ("movies",    "api/movies.csv"),
    ("tv_shows",  "api/tv_shows.csv"),
    ("countries", "api/countries.csv"),
])
def test_tables_match_the_csv_files(db, table, csv):
    expected = pd.read_csv(ROOT / "data" / csv)
    loaded = pd.read_sql(f"SELECT show_id FROM {table}", db)
    assert len(loaded) == len(expected)
    assert set(loaded["show_id"]) == set(expected["show_id"])


def test_box_office_totals_match(db, api_movies):
    loaded = pd.read_sql("SELECT SUM(budget) AS budget, SUM(revenue) AS revenue FROM movies", db)
    assert loaded.loc[0, "budget"] == api_movies["budget"].sum()
    assert loaded.loc[0, "revenue"] == api_movies["revenue"].sum()
