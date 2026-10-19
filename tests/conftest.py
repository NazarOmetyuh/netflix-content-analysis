"""Shared fixtures: every data file is loaded once per test run."""
from pathlib import Path

import pandas as pd
import pytest

DATA = Path(__file__).resolve().parents[1] / "data"


@pytest.fixture(scope="session")
def raw():
    return pd.read_csv(DATA / "raw" / "netflix_titles.csv")


@pytest.fixture(scope="session")
def full():
    return pd.read_csv(DATA / "processed" / "netflix_titles_full.csv")


@pytest.fixture(scope="session")
def movies():
    return pd.read_csv(DATA / "processed" / "movies.csv")


@pytest.fixture(scope="session")
def tv_shows():
    return pd.read_csv(DATA / "processed" / "tv_shows.csv")


@pytest.fixture(scope="session")
def countries():
    return pd.read_csv(DATA / "processed" / "countries.csv")


@pytest.fixture(scope="session")
def api_movies():
    return pd.read_csv(DATA / "api" / "movies.csv")


@pytest.fixture(scope="session")
def api_tv_shows():
    return pd.read_csv(DATA / "api" / "tv_shows.csv")


@pytest.fixture(scope="session")
def api_countries():
    return pd.read_csv(DATA / "api" / "countries.csv")
