# Netflix Content Analysis

Data analytics project: Python ETL, PostgreSQL star schema, API enrichment, and a hit-vs-flop movie classifier.

## Questions
- How much content is added each year, movies vs TV shows?
- Which countries, genres, actors, and directors perform best?
- Is there a correlation between box office and IMDb rating?
- Can we predict whether a movie will be a hit or a flop?
- What is the budget elasticity of revenue? Do bigger budgets have diminishing returns?

## Tech Stack
- Python: pandas, requests, scikit-learn, pytest
- PostgreSQL: CTEs, window functions
- APIs: TMDB, Google Search
- Git/GitHub

## How It Works
```
Netflix CSV + APIs  →  Python (pandas)  →  PostgreSQL (star schema)  →  ML classifier
```

1. Clean: parse dates, split duration, fix ratings, split list columns (cast, genres, countries).
2. Enrich: fill missing directors, cast, and countries, and add budget, revenue, and IMDb rating from the APIs.
3. Load: store everything in PostgreSQL as a star schema.
4. Analyze: SQL queries and statistical tests.
5. Predict: classify movies as hit or flop (hit = revenue ≥ 2 × budget).

## Project Structure
```
data/       raw, processed, API cache
python/     cleaning, API fetch, DB load, model training
sql/        schema and queries
tests/      data quality checks
docs/       diagrams and model report
```

## Data Quality
- Missing values filled from the APIs are tracked with a source column (netflix_csv / tmdb / google_search / unknown)
- Missing box office values are collected using the Google Search API
- Tests check for duplicates, nulls, and broken keys
- Row counts and totals are reconciled between Python and SQL

## Data Sources
- [Netflix Movies and TV Shows](https://www.kaggle.com/datasets/shivamb/netflix-shows) (Kaggle)
- [TMDB API](https://www.themoviedb.org/documentation/api)
- Google Search API

## Limitations
- Box office data exists only for theatrical movies, so TV shows and most Netflix Originals are excluded from revenue analysis

## Author
Nazarii Ometiukh · [LinkedIn](https://www.linkedin.com/in/nazarii-ometiukh-81a7b2377/)
