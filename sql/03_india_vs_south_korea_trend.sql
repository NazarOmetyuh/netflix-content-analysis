-- Q: Was India always movie-heavy and South Korea always TV-heavy on Netflix,
--    or did the mix change over time?
-- Two timelines:
--   1. year_added:   when Netflix added the title (Netflix's buying decisions)
--   2. release_year: when the title came out (what the country produces)
-- movie_share_pct is used per year instead of the movies / TV ratio,
-- because some years have 0 TV shows and the ratio would divide by zero.


-- 1. By year added to Netflix, with running totals
WITH titles AS (
    SELECT show_id, date_added FROM movies
    UNION ALL
    SELECT show_id, date_added FROM tv_shows
),
country_titles AS (
    SELECT c.country,
           c.type,
           EXTRACT(YEAR FROM TRIM(t.date_added)::date)::int AS year_added
    FROM countries c
    JOIN titles t ON t.show_id = c.show_id
    WHERE c.country IN ('India', 'South Korea')
      AND t.date_added IS NOT NULL
),
yearly AS (
    SELECT country,
           year_added,
           SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END) AS movie_count,
           SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_show_count
    FROM country_titles
    GROUP BY country, year_added
)
SELECT country,
       year_added,
       movie_count,
       tv_show_count,
       ROUND(100.0 * movie_count / (movie_count + tv_show_count), 1) AS movie_share_pct,
       SUM(movie_count)   OVER w AS movies_to_date,
       SUM(tv_show_count) OVER w AS tv_shows_to_date,
       ROUND(1.0 * SUM(movie_count) OVER w
                 / NULLIF(SUM(tv_show_count) OVER w, 0), 2) AS ratio_to_date
FROM yearly
WINDOW w AS (PARTITION BY country ORDER BY year_added)
ORDER BY country, year_added;


-- 2. By release period (when the titles were made)
WITH periods AS (
    SELECT country,
           type,
           release_year,
           CASE
               WHEN release_year < 2000 THEN 'before 2000'
               WHEN release_year < 2010 THEN '2000-2009'
               WHEN release_year < 2015 THEN '2010-2014'
               WHEN release_year < 2018 THEN '2015-2017'
               ELSE '2018-2021'
           END AS release_period
    FROM countries c
    JOIN (
        SELECT show_id, release_year FROM movies
        UNION ALL
        SELECT show_id, release_year FROM tv_shows
    ) t USING (show_id)
    WHERE country IN ('India', 'South Korea')
),
counts AS (
    SELECT country,
           release_period,
           MIN(release_year) AS first_year,
           SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END) AS movie_count,
           SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_show_count
    FROM periods
    GROUP BY country, release_period
)
SELECT country,
       release_period,
       movie_count,
       tv_show_count,
       ROUND(100.0 * movie_count / (movie_count + tv_show_count), 1) AS movie_share_pct
FROM counts
ORDER BY country, first_year;
