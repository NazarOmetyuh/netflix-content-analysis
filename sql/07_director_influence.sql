-- Q: How much do directors influence box office?
-- Scope: movies with budget and revenue of at least $100K (same rule as the dashboard).
-- Method (the same as 06_actor_influence.sql, so the results can be compared):
--   1. Take each movie's directors (most movies have one).
--   2. Give each director a track record: the average LN(revenue) of their OTHER box
--      office movies. The movie itself is left out, otherwise it would explain its own revenue.
--   3. The movie's director score = average track record of its directors who have one.
--   4. Measure how well the director score explains the movie's revenue: r, r_squared
--      (share of differences explained), t_stat and slope (elasticity).
-- Track records only use movies in this dataset, so they are a rough measure.


-- 1. Director score of each movie, saved as a temporary view for queries 2-4
-- (dropped automatically when the session ends).
CREATE OR REPLACE TEMP VIEW movie_director_score AS
WITH box_office AS (
    SELECT show_id,
           title,
           director,
           LN(budget::float8)  AS ln_budget,
           LN(revenue::float8) AS ln_revenue
    FROM movies
    WHERE budget  >= 100000
      AND revenue >= 100000
),
movie_directors AS (
    SELECT b.show_id,
           b.ln_revenue,
           TRIM(d) AS director
    FROM box_office b,
         unnest(string_to_array(b.director, ',')) AS d
    WHERE TRIM(d) <> ''
),
track_records AS (
    -- Leave-one-out average: (sum over all the director's movies - this movie) / (count - 1)
    SELECT show_id,
           director,
           COUNT(*) OVER (PARTITION BY director) - 1                    AS other_movies,
           (SUM(ln_revenue) OVER (PARTITION BY director) - ln_revenue)
             / NULLIF(COUNT(*) OVER (PARTITION BY director) - 1, 0)     AS other_avg_ln_revenue
    FROM movie_directors
)
SELECT b.show_id,
       b.title,
       b.ln_budget,
       b.ln_revenue,
       COUNT(t.director)            AS directors_with_track_record,
       AVG(t.other_avg_ln_revenue)  AS director_score
FROM box_office b
JOIN track_records t ON t.show_id = b.show_id
WHERE t.other_movies >= 1
GROUP BY b.show_id, b.title, b.ln_budget, b.ln_revenue;


-- 2. How much of the differences in revenue do directors explain?
-- Budget is measured on the same movies, so the two numbers can be compared.
-- r_director_vs_budget: how much the director score and the budget overlap.
WITH stats AS (
    SELECT COUNT(*)                                  AS movies,
           CORR(director_score, ln_revenue)          AS r,
           REGR_R2(ln_revenue, director_score)       AS r_squared,
           REGR_SLOPE(ln_revenue, director_score)    AS slope,
           REGR_R2(ln_revenue, ln_budget)            AS budget_r_squared,
           CORR(director_score, ln_budget)           AS r_director_vs_budget
    FROM movie_director_score
)
SELECT movies,
       ROUND(r::numeric, 3)                                       AS r,
       ROUND((100 * r_squared)::numeric, 1)                       AS pct_explained_by_directors,
       ROUND((r * SQRT((movies - 2) / (1 - r * r)))::numeric, 1)  AS t_stat,
       ROUND(slope::numeric, 3)                                   AS elasticity,
       ROUND((100 * budget_r_squared)::numeric, 1)                AS pct_explained_by_budget,
       ROUND(r_director_vs_budget::numeric, 3)                    AS r_director_vs_budget
FROM stats;


-- 3. Revenue by director score quintile (five equal-sized groups)
WITH quintiles AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY director_score, show_id) AS quintile
    FROM movie_director_score
)
SELECT quintile,
       COUNT(*)                                                                       AS movies,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXP(director_score))::numeric) AS median_director_track_record,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXP(ln_revenue))::numeric)     AS median_revenue,
       ROUND(100.0 * AVG(CASE WHEN ln_revenue - ln_budget >= LN(2) THEN 1 ELSE 0 END), 1) AS hit_rate_pct
FROM quintiles
GROUP BY quintile
ORDER BY quintile;


-- 4. Directors with the strongest box office track record (at least 3 box office movies)
WITH movie_directors AS (
    SELECT TRIM(d)            AS director,
           m.revenue::float8  AS revenue
    FROM movies m,
         unnest(string_to_array(m.director, ',')) AS d
    WHERE m.budget  >= 100000
      AND m.revenue >= 100000
)
SELECT director,
       COUNT(*)                                                            AS movies,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue)::numeric) AS median_revenue,
       RANK() OVER (ORDER BY PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) DESC) AS rank
FROM movie_directors
GROUP BY director
HAVING COUNT(*) >= 3
ORDER BY rank
LIMIT 10;


-- 5. Hit or flop: do directors with a strong track record come with hits?
-- Same formulas, but against is_hit (1 = hit = revenue of at least 2x budget, 0 = flop).
-- pct_explained: share of the hit / flop differences the director score explains (r²).
-- hit_chance_change_pp: change in the chance of being a hit, in percentage points,
-- when the director's track record doubles (REGR_SLOPE on the log score x LN(2)).
WITH scored AS (
    SELECT director_score,
           CASE WHEN ln_revenue - ln_budget >= LN(2) THEN 1.0 ELSE 0.0 END AS is_hit
    FROM movie_director_score
),
stats AS (
    SELECT COUNT(*)                                     AS movies,
           CORR(director_score, is_hit)                 AS r,
           REGR_SLOPE(is_hit, director_score) * LN(2)   AS slope_per_doubling
    FROM scored
)
SELECT movies,
       ROUND(r::numeric, 3)                                       AS r_hit,
       ROUND((100 * r * r)::numeric, 1)                           AS pct_explained,
       ROUND((r * SQRT((movies - 2) / (1 - r * r)))::numeric, 1)  AS t_stat,
       ROUND((100 * slope_per_doubling)::numeric, 1)              AS hit_chance_change_pp
FROM stats;
