CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.dim_type (
    type_id   SERIAL PRIMARY KEY,
    type_name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS analytics.fact_titles (
    show_id        TEXT PRIMARY KEY,
    title          TEXT NOT NULL,
    type_id        INT REFERENCES analytics.dim_type(type_id),
    release_year   INT,
    date_added     DATE,
    rating         TEXT,
    duration_value INT,
    duration_unit  TEXT,
    description    TEXT,
    budget         BIGINT,
    revenue        BIGINT,
    imdb_rating    NUMERIC(3,1),
    imdb_votes     INT
);

CREATE TABLE IF NOT EXISTS analytics.dim_genre (
    genre_id   SERIAL PRIMARY KEY,
    genre_name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS analytics.bridge_title_genre (
    show_id  TEXT REFERENCES analytics.fact_titles(show_id),
    genre_id INT  REFERENCES analytics.dim_genre(genre_id),
    PRIMARY KEY (show_id, genre_id)
);