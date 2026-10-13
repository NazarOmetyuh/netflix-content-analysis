# Changelog

Versions start at 0. Big changes bump the minor version (0.1 → 0.2); small fixes bump the patch (0.1.0 → 0.1.1).

## [0.2.0] - 2026-10-13
Cleaning step: the raw data is cleaned, saved as CSV files and loaded into PostgreSQL.

### Added
- `python/clean.ipynb`, in 5 steps:
  1. Load the raw CSV, with movies and TV shows kept in one table.
  2. Fix the 3 rows where the duration was in the `rating` column.
  3. Split `duration` into `duration_value` and `duration_unit` (`min` for movies, `season` for TV shows).
  4. Build a countries table: one row per title and country, with spaces trimmed and empty values dropped.
  5. Save `netflix_titles_full.csv`, `movies.csv`, `tv_shows.csv` and `countries.csv` to `data/processed/`, and load `movies`, `tv_shows` and `countries` into PostgreSQL.
- `sql/01_schema.sql`: first star schema (`fact_titles`, `dim_type`, `dim_genre`, `bridge_title_genre`).
- `.env.example`: template for the TMDB API key and PostgreSQL settings.

### Changed
- README: added a question about budget elasticity of revenue, removed the setup section.

## [0.1.0] - 2026-10-12
First working step: the raw data has been explored and the project can be set up from scratch.

### Added
- `notebooks/01_exploration.ipynb`: first look at the Netflix CSV (8,807 titles, 12 columns). Covers missing values (director 30%, country and cast 9%), movies vs TV shows, titles added per year, ratings, durations, and top countries and genres. Ends with a list of what to clean.
- `requirements.txt`: pandas, numpy, matplotlib, requests, python-dotenv, SQLAlchemy, psycopg2, scikit-learn, pytest and jupyter.
- `python/clean.ipynb` and `sql/01_schema.sql` as placeholders for the cleaning and star-schema steps.
- `.vscode/settings.json` with the local PostgreSQL connection for SQLTools.
- README: setup instructions and the `notebooks/` folder.

### Changed
- Moved the raw dataset from `data/netflix_titles.csv` to `data/raw/netflix_titles.csv`.

### Found during exploration
- `date_added` has leading spaces and 10 missing values.
- 3 rows have the duration (`74 min`, `84 min`, `66 min`) in the `rating` column.
- `duration` mixes minutes (movies) and seasons (TV shows).

## [0.0.1] - initial
- README, license and the project folder structure.
