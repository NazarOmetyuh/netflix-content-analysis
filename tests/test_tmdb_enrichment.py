"""Checks on the TMDB enrichment step (python/fetch_tmdb.ipynb): data/processed/ -> data/api/."""
import pandas as pd
import pytest

FILLED_COLUMNS = ["director", "cast", "country", "rating"]


@pytest.fixture(params=["movies", "tv_shows"])
def pair(request, movies, tv_shows, api_movies, api_tv_shows):
    """(processed table, enriched table) for movies and for TV shows."""
    return {"movies": (movies, api_movies), "tv_shows": (tv_shows, api_tv_shows)}[request.param]


def test_enrichment_keeps_the_same_titles(pair):
    processed, enriched = pair
    assert set(enriched["show_id"]) == set(processed["show_id"])
    assert enriched["show_id"].is_unique


@pytest.mark.parametrize("column", FILLED_COLUMNS)
def test_existing_netflix_values_are_not_overwritten(pair, column):
    processed, enriched = pair
    merged = processed[["show_id", column]].merge(
        enriched[["show_id", column]], on="show_id", suffixes=("", "_tmdb"))
    had_value = merged[column].notna()
    changed = merged.loc[had_value, column] != merged.loc[had_value, f"{column}_tmdb"]
    assert not changed.any(), f"{changed.sum()} {column} values were overwritten"


def test_tmdb_values_are_in_valid_ranges(api_movies, api_tv_shows):
    for df in (api_movies, api_tv_shows):
        assert df["tmdb_rating"].dropna().between(0, 10).all()
        assert (df["tmdb_votes"].dropna() >= 0).all()
    assert (api_movies["budget"].dropna() >= 0).all()
    assert (api_movies["revenue"].dropna() >= 0).all()


def test_imdb_ids_have_the_right_format(api_movies, api_tv_shows):
    for df in (api_movies, api_tv_shows):
        assert df["imdb_id"].dropna().str.match(r"^tt\d+$").all()


# Netflix titles that share a TMDB id and were checked by hand: the same movie or show
# listed twice by Netflix (often under a translated title), or parts and seasons that
# TMDB stores as one show. Wrong matches are fixed in fetch_tmdb.ipynb (MANUAL_TMDB_IDS).
KNOWN_DUPLICATE_LISTINGS = {
    # movies
    "s6706", "s304",    # Esperando la carroza, listed twice
    "s7091", "s52",     # InuYasha the Movie 2 (English and Italian titles)
    "s53", "s7090",     # InuYasha the Movie 3
    "s7089", "s54",     # InuYasha the Movie 4
    "s7346", "s160",    # Love in a Puff
    "s7560", "s57",     # Naruto Shippuden the Movie: Blood Prison
    "s1987", "s1983",   # Nee Enge En Anbe / Anaamika (Tamil and Telugu versions, one TMDB entry)
    "s3372", "s6530",   # Consequences
    "s5967", "s3963",   # 15 August
    "s1654", "s1653",   # Andhakaaram / Andhaghaaram
    # TV shows
    "s1271", "s8023",   # Sin senos sí hay paraíso, listed twice
    "s4390", "s5237",   # Beyblade Burst Evolution is a season of Beyblade Burst on TMDB
    "s3516", "s8133",   # Surviving R. Kelly Part II is season 2 on TMDB
    "s3029", "s7650",   # The Ollie & Moon Show / Ollie & Moon
}


def test_each_tmdb_id_matches_one_netflix_title(pair):
    # Two Netflix titles with the same TMDB id are either a wrong match
    # (e.g. TMNT 2007 matched to TMNT 1990) or a known duplicate listing.
    _, enriched = pair
    ids = enriched["tmdb_id"].dropna()
    duplicates = enriched[enriched["tmdb_id"].isin(ids[ids.duplicated()])]
    unchecked = duplicates[~duplicates["show_id"].isin(KNOWN_DUPLICATE_LISTINGS)]
    assert unchecked.empty, (
        f"{len(unchecked)} titles share a TMDB id and are not known duplicates:\n"
        + unchecked.sort_values("tmdb_id")[["show_id", "title", "release_year", "tmdb_id"]].to_string()
    )


def test_enough_movies_have_box_office_data(api_movies):
    # The box office research (sql/05-10) needs budget and revenue of at least $100K
    box_office = api_movies[(api_movies["budget"] >= 100_000) & (api_movies["revenue"] >= 100_000)]
    assert len(box_office) >= 1000


def test_countries_table_matches_the_enriched_country_columns(api_movies, api_tv_shows, api_countries):
    # The countries table (sql/02, sql/03) must hold the same countries as the
    # country column of movies and tv_shows (sql/09, Power BI), including TMDB-filled ones.
    titles = pd.concat([api_movies, api_tv_shows])[["show_id", "country"]].dropna()
    expected = {
        (show_id, country.strip())
        for show_id, cell in titles.itertuples(index=False)
        for country in cell.split(",") if country.strip()
    }
    actual = set(api_countries[["show_id", "country"]].itertuples(index=False, name=None))
    assert actual == expected


def test_enriched_countries_are_clean(api_countries, api_movies, api_tv_shows):
    known = pd.concat([api_movies, api_tv_shows])[["show_id", "type"]]
    merged = api_countries.merge(known, on="show_id", suffixes=("", "_title"))
    assert len(merged) == len(api_countries)
    assert (merged["type"] == merged["type_title"]).all()
    assert (api_countries["country"] == api_countries["country"].str.strip()).all()
    assert not api_countries.duplicated(["show_id", "country"]).any()
