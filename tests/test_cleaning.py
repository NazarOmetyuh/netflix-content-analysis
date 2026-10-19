"""Checks on the cleaning step (python/clean.ipynb): raw CSV -> data/processed/."""
import pandas as pd


def test_raw_file_is_complete(raw):
    assert len(raw) == 8807
    assert raw["show_id"].is_unique


def test_no_titles_lost_or_added_in_cleaning(raw, full):
    assert set(full["show_id"]) == set(raw["show_id"])


def test_show_id_is_unique(full, movies, tv_shows):
    for df in (full, movies, tv_shows):
        assert df["show_id"].is_unique


def test_movies_and_tv_shows_split_the_full_table(full, movies, tv_shows):
    assert len(movies) + len(tv_shows) == len(full)
    assert not set(movies["show_id"]) & set(tv_shows["show_id"])
    assert (movies["type"] == "Movie").all()
    assert (tv_shows["type"] == "TV Show").all()


def test_no_duration_left_in_rating_column(full):
    # 3 raw rows had "74 min" etc. in the rating column
    assert not full["rating"].astype(str).str.contains("min").any()


def test_duration_is_split_correctly(movies, tv_shows):
    assert (movies["duration_unit"] == "min").all()
    assert (tv_shows["duration_unit"] == "season").all()
    for df in (movies, tv_shows):
        assert df["duration_value"].notna().all()
        assert (df["duration_value"] > 0).all()


def test_date_added_has_no_extra_spaces(full):
    dates = full["date_added"].dropna()
    assert (dates == dates.str.strip()).all(), (
        f"{(dates != dates.str.strip()).sum()} date_added values have leading or trailing spaces"
    )


def test_date_added_parses_as_a_date(full):
    dates = pd.to_datetime(full["date_added"].dropna().str.strip(), format="%B %d, %Y", errors="coerce")
    assert dates.notna().all()


def test_release_year_is_realistic(full):
    assert full["release_year"].between(1900, 2021).all()


def test_countries_belong_to_known_titles(full, countries):
    assert countries["show_id"].isin(full["show_id"]).all()
    merged = countries.merge(full[["show_id", "type"]], on="show_id", suffixes=("", "_full"))
    assert (merged["type"] == merged["type_full"]).all()


def test_countries_are_clean(countries):
    assert countries["country"].notna().all()
    assert (countries["country"] == countries["country"].str.strip()).all()
    assert (countries["country"] != "").all()
    assert not countries.duplicated(["show_id", "country"]).any()
