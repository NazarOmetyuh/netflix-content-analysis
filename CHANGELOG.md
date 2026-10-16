# Changelog

Versions start at 0. Big changes bump the minor version (0.1 → 0.2); small fixes bump the patch (0.1.0 → 0.1.1).

## [0.5.0] - 2026-10-16
SQL analysis: the first three queries that answer the README questions, with the insights written down in a findings file.

### Added
- `sql/02_movies_vs_tv_by_country.sql`: movies vs TV shows per country, for countries with more than 100 titles.
- `sql/03_india_vs_south_korea_trend.sql`: how the movie / TV mix of India and South Korea changed, by year added to Netflix (running totals with window functions) and by release period.
- `sql/04_actor_career_paths.sql`: whether actors with more than 10 titles stay in the type they started in (movies or TV shows). Uses a temporary view, `DENSE_RANK()` for each actor's first year, and a summary by start type.
- `sql/docs/findings.md`: one section per query, with result tables and insights:
  1. India is the most movie-heavy large catalogue (about 11 movies per TV show); South Korea is the most TV-heavy (0.36).
  2. India has been focused on movies for a long time; South Korea's TV-show boom on Netflix started after 2009.
  3. Actors who start in movies seem to stay in movies more often (86.4% vs 54.5%), but with movies and TV shows weighted equally both groups stay about 73% of the time. The gap comes from the catalogue having more than twice as many movies.

### Removed
- `sql/02.sql` placeholder; its number is now used by the first analysis query.

### Notes
- The findings assume the data is correct and large enough to draw conclusions.
- A title made by several countries counts once for each of them.
- Netflix's `release_year` for TV shows is often the latest season, which can shift an actor's start type.

## [0.4.0] - 2026-10-15
Power BI dashboard built on the enriched movies table in PostgreSQL.

### Added
- `powerbi/Dashboard_final.pbix` with 4 pages. Genre, country and release year slicers are synced across pages:
  1. Overview: counts of movies, countries, genres, directors and actors, average rating and revenue coverage; movies by release year, genre, country (top 10) and age rating. Every movie is counted, even when revenue or other values are missing.
  2. Actors: top 10 by revenue, average rating, number of movies and TMDB votes; a ranking table with all metrics; the best actor per release year.
  3. Directors: the same layout as Actors.
  4. Revenue: budget vs revenue scatter, median revenue multiple and hit rate by budget band, hit vs flop share, revenue by year and genre, and the top movies by revenue.
- Model tables split from list columns: `movie_cast`, `movie_directors`, `movie_genres`, `movie_countries` (missing genres and countries become `Unknown`), plus a `Min Movies` slicer table.
- Processed CSVs (`data/processed/`) and the TMDB-enriched data and caches (`data/api/`).
- `sql/02.sql` as a placeholder for the load step.

### Notes
- Box office analysis only uses movies with budget and revenue of at least $100K, because TMDB has junk values such as a $5 budget. Hit = revenue of at least 2x budget.
- Average rating only uses movies with at least 10 TMDB votes.
- Rating rankings for actors and directors need at least the number of movies picked in `Min Movies` (3 by default).

## [0.3.0] - 2026-10-14
Enrichment step: gaps in the processed `movies` and `tv_shows` tables are filled from the TMDB API.

### Added
- `python/fetch_tmdb.ipynb`, in 9 steps:
  1. Settings: API key from `.env`, `SAMPLE` for test runs, `ONLY_ROWS_WITH_GAPS`, number of parallel requests.
  2. Load `movies.csv` and `tv_shows.csv` and show the missing values (director, cast, country, rating).
  3. Request helper with retries for rate limits (`429`) and server errors; works with a v3 API key or a v4 token.
  4. Match each title to a TMDB ID with `/search`: same title (ignoring case and punctuation) and the closest year. Movies are searched with the year first; TV shows without it, because Netflix's `release_year` is often the latest season.
  5. One details request per title (credits, external IDs, US age ratings), converted to our columns.
  6. Cache in `data/api/tmdb_cache.json`, so titles already looked up are skipped on later runs.
  7. Fill only empty cells (`director`, `cast`, `country`, `rating`, ...); existing Netflix values are never overwritten. For TV shows, the show creators fill `director`.
  8. Show how many cells were filled and what is still missing.
  9. Save the CSVs and replace the `movies` and `tv_shows` tables in PostgreSQL.
- New columns: `tmdb_id`, `imdb_id`, `genres`, `tmdb_rating`, `tmdb_votes`, plus `budget` and `revenue` for movies.

### Notes
- `/find` and `/discover` are not used: Netflix rows have no external IDs, and `/discover` would add titles that are not on Netflix.
- A full run takes about 7 minutes (32 parallel requests, close to TMDB's rate limit of about 50 per second).
- `date_added` cannot be filled from TMDB.

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
