-- Q: If an actor starts in movies, do they keep playing only in movies,
--    or do they move to TV shows (and the other way around)?
-- Scope: actors with more than 10 titles (movies + TV shows) on Netflix.
-- Start type = the type of the actor's titles in their earliest release year.
-- Actors with both a movie and a TV show in that first year are 'Mixed start'.
-- Career path, based on all titles after the first year:
--   'Stayed only'   - every later title has the same type as the start
--   'Mostly stayed' - at least half of later titles have the same type
--   'Switched'      - most later titles have the other type
-- Note: Netflix's release_year for TV shows is often the latest season.


-- 1. Career path of each actor, saved as a temporary view
-- (dropped automatically when the session ends) so query 2 and 3 can reuse it.
CREATE OR REPLACE TEMP VIEW actor_career_paths AS
WITH titles AS (
    SELECT show_id, type, release_year, "cast" FROM movies
    UNION ALL
    SELECT show_id, type, release_year, "cast" FROM tv_shows
),
actor_titles AS (
    SELECT DISTINCT
           TRIM(actor) AS actor,
           show_id,
           type,
           release_year
    FROM titles,
         unnest(string_to_array("cast", ',')) AS actor
    WHERE "cast" IS NOT NULL
      AND TRIM(actor) <> ''
),
ranked AS (
    SELECT *,
           COUNT(*)          OVER (PARTITION BY actor)              AS total_titles,
           DENSE_RANK()      OVER (PARTITION BY actor
                                   ORDER BY release_year)           AS year_rank
    FROM actor_titles
),
start_type AS (
    SELECT actor,
           CASE
               WHEN BOOL_AND(type = 'Movie')   THEN 'Movie'
               WHEN BOOL_AND(type = 'TV Show') THEN 'TV Show'
               ELSE 'Mixed start'
           END AS start_type
    FROM ranked
    WHERE total_titles > 10
      AND year_rank = 1
    GROUP BY actor
),
later AS (
    SELECT actor,
           MAX(total_titles)                                  AS total_titles,
           SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END)  AS later_movies,
           SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END)  AS later_tv_shows
    FROM ranked
    WHERE total_titles > 10
      AND year_rank > 1
    GROUP BY actor
),
paths AS (
    SELECT s.actor,
           s.start_type,
           l.total_titles,
           l.later_movies,
           l.later_tv_shows,
           CASE WHEN s.start_type = 'Movie' THEN l.later_movies
                ELSE l.later_tv_shows END                     AS later_same_type,
           l.later_movies + l.later_tv_shows                  AS later_titles
    FROM start_type s
    JOIN later l ON l.actor = s.actor
)
SELECT actor,
       start_type,
       total_titles,
       later_movies,
       later_tv_shows,
       later_same_type,
       later_titles,
       CASE
           WHEN start_type = 'Mixed start'          THEN 'Mixed start'
           WHEN later_same_type = later_titles      THEN 'Stayed only'
           WHEN 2 * later_same_type >= later_titles THEN 'Mostly stayed'
           ELSE 'Switched'
       END AS career_path
FROM paths;


-- 2. Each actor's path
SELECT actor, start_type, total_titles, later_movies, later_tv_shows, career_path
FROM actor_career_paths
ORDER BY start_type, total_titles DESC;


-- 3. Summary by start type
SELECT start_type,
       COUNT(*)                                                    AS actors,
       COUNT(*) FILTER (WHERE career_path = 'Stayed only')         AS stayed_only,
       COUNT(*) FILTER (WHERE career_path = 'Mostly stayed')       AS mostly_stayed,
       COUNT(*) FILTER (WHERE career_path = 'Switched')            AS switched,
       SUM(later_movies)                                           AS later_movies,
       SUM(later_tv_shows)                                         AS later_tv_shows,
       ROUND(100.0 * SUM(later_same_type) / SUM(later_titles), 1)  AS pct_later_same_type
FROM actor_career_paths
GROUP BY start_type
ORDER BY actors DESC;
