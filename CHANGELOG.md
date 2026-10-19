# Changelog

Versions start at 0. Big changes bump the minor version (0.1 → 0.2); small fixes bump the patch (0.1.0 → 0.1.1).

## [0.7.0] - 2026-10-19
Data quality tests, fixes for the issues they found, one consistent set of tables, and a rewritten README.

### Added
- `tests/` with 32 pytest checks (`pytest.ini` points pytest to it):
  - `test_cleaning.py`: no titles lost, unique IDs, movies and TV shows split correctly, duration and rating fixed, `date_added` trimmed and parseable, countries clean.
  - `test_tmdb_enrichment.py`: same titles before and after enrichment, Netflix values never overwritten, valid TMDB values, each TMDB id matched to one title (except hand-checked duplicate listings), and the countries table matching the enriched country columns.
  - `test_database.py`: PostgreSQL tables match the CSV files, including box office totals. Skipped without a database connection.
- `data/api/countries.csv`: countries table built from the enriched data.

### Fixed
- `python/clean.ipynb` trims `date_added` (88 TV shows had a leading space).
- `python/fetch_tmdb.ipynb` has a `MANUAL_TMDB_IDS` list for 8 titles that were matched to the wrong TMDB entry, for example TMNT (2007) matched to the 1990 film, which gave it the wrong budget and revenue.
- The `countries` table was built before TMDB filled in about 550 missing countries, so SQL 02-03 and the dashboard counted different countries. `fetch_tmdb.ipynb` now rebuilds it from the enriched data.
- The markdown of step 9 in `fetch_tmdb.ipynb` said the enriched files replace `data/processed/`; they are saved to `data/api/`.

### Changed
- Moved `sql/docs/` to `docs/`. Query names in the docs link to the SQL files.
- README rewritten to match the project: questions and where they are answered, key findings, the experiment (results in about March 2027), dashboard section with space for screenshots, tech stack, structure, data quality, how to run, next steps.
- Research numbers updated after the data fixes. Most moved by 0.1 or less. Finding 1 changed more: with the TMDB-filled countries, Taiwan (0.27 movies per TV show) has the lowest ratio, just below South Korea (0.34), and Italy and Brazil pass the 100-title cut.
- `.vscode/` is no longer tracked (local database connection settings).

### Removed
- `sql/01_schema.sql`: the star schema was never loaded, and the dashboard builds its own model.
- Google Search API enrichment and the source tracking column from the README plan.
- Unused database tables: `public.titles` and the `analytics` schema.

### Notes
- The Power BI dashboard reads the `movies` table and needs a Refresh to pick up the fixed data.

## [0.6.0] - 2026-10-19
Box office research: what drives revenue and what makes a hit, plus an experiment that predicts 5 upcoming movies.

### Added
- `sql/05_box_office_vs_rating.sql`: rating vs revenue with Pearson, log and Spearman correlation, t-statistic, rating bands, revenue change per rating point (`REGR_SLOPE`), and rating vs hit or flop.
- `sql/06_actor_influence.sql`: how much lead actors explain revenue and hits, using a leave-one-out track record (average revenue of the leads' other movies, with window functions).
- `sql/07_director_influence.sql`: the same method for directors.
- `sql/08_budget_elasticity.sql`: budget elasticity of revenue (log-log `REGR_SLOPE`), elasticity by budget tier, return and hit rate by budget quintile, and budget vs hit or flop.
- `sql/09_revenue_drivers_and_hits.sql`: hits vs flops, correlation of each statistic with revenue and with hits side by side, and hit rate and lift by genre, age rating, rating band, votes, budget, runtime, decade and country.
- `sql/10_experiment_upcoming_films.sql`: predicts whether 5 movies releasing Oct-Dec 2026 (Avengers: Doomsday, Violent Night 2, Wife & Dog, I Play Rocky, The Angry Birds Movie 3) will be hits. It gives a pre-release prediction (director, lead actors, genres, budget), after-release scenarios for 6 ratings x 6 vote counts (two-variable regression on rating and votes), and a query to check the results.
- `sql/docs/box_office_research.md`: explains the measures (Pearson r, r², t, logs, Spearman, slope, elasticity, track record, hit rate, lift), the results of queries 05-09, and a comparison of what drives revenue vs what drives hits.
- `sql/docs/experiment_upcoming_films.md`: the experiment's inputs, predictions, scenario tables and a results table to fill in around March 2027.

### Changed
- `sql/docs/findings.md` keeps findings 1-3 and links to the box office research.

### Key results
- Revenue: budget explains 43%, votes 39%, the director's track record 24%, lead actors 11% and rating 4%.
- Hits: votes (5.5%) and rating (5.0%) matter most. Budget slightly lowers the hit chance, and actors show no real link.
- +1 rating point comes with about +55% revenue and +14 percentage points of hit chance.
- Budget elasticity is 0.84 overall, but above about $9M there are no diminishing returns.
- All 5 upcoming movies are predicted as hits before release, with 54-63% chance.

### Notes
- Box office data exists for about 20% of Netflix movies (mostly theatrical releases), so the research describes those movies only.
- Four of the five experiment budgets are estimates from comparable films.

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
