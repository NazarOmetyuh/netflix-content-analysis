-- Q: Is there a correlation between box office (revenue) and rating?
-- Scope: movies with budget and revenue of at least $100K (TMDB has junk values
-- such as a $5 budget) and at least 10 TMDB votes, the same rules as the dashboard.
-- Pearson measures a straight-line relationship and is pulled by a few huge hits,
-- so it is also computed on log revenue and as Spearman (correlation of ranks).
-- t_stat: |t| above about 2 means the correlation is unlikely to be chance (5% level).


-- 1. Correlation between rating and revenue
WITH box_office AS (
    SELECT title,
           tmdb_rating,
           tmdb_votes,
           revenue::float8                   AS revenue,
           revenue::float8 / budget::float8  AS revenue_multiple
    FROM movies
    WHERE budget  >= 100000
      AND revenue >= 100000
      AND tmdb_votes >= 10
),
ranked AS (
    -- Average rank, so tied values share the same rank (as in Spearman's formula)
    SELECT *,
           (RANK() OVER (ORDER BY tmdb_rating)
            + COUNT(*) OVER () + 1 - RANK() OVER (ORDER BY tmdb_rating DESC)) / 2.0 AS rating_rank,
           (RANK() OVER (ORDER BY revenue)
            + COUNT(*) OVER () + 1 - RANK() OVER (ORDER BY revenue DESC)) / 2.0     AS revenue_rank
    FROM box_office
),
correlations AS (
    SELECT 'Rating vs revenue (Pearson)'          AS measure, COUNT(*) AS movies, CORR(tmdb_rating, revenue)               AS r FROM ranked
    UNION ALL
    SELECT 'Rating vs log revenue (Pearson)',                  COUNT(*),          CORR(tmdb_rating, LN(revenue))                 FROM ranked
    UNION ALL
    SELECT 'Rating vs revenue (Spearman)',                     COUNT(*),          CORR(rating_rank, revenue_rank)                FROM ranked
    UNION ALL
    SELECT 'Rating vs log revenue multiple (Pearson)',         COUNT(*),          CORR(tmdb_rating, LN(revenue_multiple))        FROM ranked
    UNION ALL
    SELECT 'Log votes vs log revenue (Pearson)',               COUNT(*),          CORR(LN(tmdb_votes), LN(revenue))              FROM ranked
)
SELECT measure,
       movies,
       ROUND(r::numeric, 3)                                    AS r,
       ROUND((r * SQRT((movies - 2) / (1 - r * r)))::numeric, 1) AS t_stat
FROM correlations;


-- 2. Revenue and hit rate by rating band
-- Hit = revenue of at least 2x budget.
WITH box_office AS (
    SELECT tmdb_rating,
           revenue,
           revenue::float8 / budget::float8 AS revenue_multiple
    FROM movies
    WHERE budget  >= 100000
      AND revenue >= 100000
      AND tmdb_votes >= 10
),
banded AS (
    SELECT *,
           CASE
               WHEN tmdb_rating < 5.5 THEN 'under 5.5'
               WHEN tmdb_rating < 6.0 THEN '5.5-5.9'
               WHEN tmdb_rating < 6.5 THEN '6.0-6.4'
               WHEN tmdb_rating < 7.0 THEN '6.5-6.9'
               WHEN tmdb_rating < 7.5 THEN '7.0-7.4'
               ELSE '7.5 and above'
           END AS rating_band
    FROM box_office
)
SELECT rating_band,
       COUNT(*)                                                             AS movies,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue)::numeric) AS median_revenue,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue_multiple)::numeric, 2) AS median_multiple,
       ROUND(100.0 * AVG(CASE WHEN revenue_multiple >= 2 THEN 1 ELSE 0 END), 1) AS hit_rate_pct
FROM banded
GROUP BY rating_band
ORDER BY MIN(tmdb_rating);


-- 3. How much does one extra rating point change revenue?
-- r and r_squared say how well rating explains the differences between movies.
-- The slope says how big the effect is: REGR_SLOPE(LN(revenue), rating) is the change
-- in log revenue per rating point, and EXP(slope) - 1 turns it into a percentage.
-- Example: 55% means a 7.5 movie earns on average 55% more than a 6.5 movie.
WITH box_office AS (
    SELECT tmdb_rating,
           revenue::float8                  AS revenue,
           revenue::float8 / budget::float8 AS revenue_multiple
    FROM movies
    WHERE budget  >= 100000
      AND revenue >= 100000
      AND tmdb_votes >= 10
)
SELECT 'Revenue'                                                              AS outcome,
       COUNT(*)                                                               AS movies,
       ROUND(REGR_R2(LN(revenue), tmdb_rating)::numeric, 3)                   AS r_squared,
       ROUND((100 * (EXP(REGR_SLOPE(LN(revenue), tmdb_rating)) - 1))::numeric, 1) AS pct_change_per_point
FROM box_office
UNION ALL
SELECT 'Revenue / budget',
       COUNT(*),
       ROUND(REGR_R2(LN(revenue_multiple), tmdb_rating)::numeric, 3),
       ROUND((100 * (EXP(REGR_SLOPE(LN(revenue_multiple), tmdb_rating)) - 1))::numeric, 1)
FROM box_office;


-- 4. Hit or flop: does rating (and audience size) come with hits?
-- Same formulas, but against is_hit (1 = hit, 0 = flop) instead of revenue.
-- pct_explained: share of the hit / flop differences the factor explains on its own (r²).
-- hit_chance_change_pp: REGR_SLOPE(is_hit, x) x 100 = change in the chance of being
-- a hit, in percentage points, per unit of x. For votes the unit is a doubling
-- (slope on LN(votes) x LN(2)).
WITH box_office AS (
    SELECT tmdb_rating,
           tmdb_votes,
           CASE WHEN revenue >= 2 * budget THEN 1.0 ELSE 0.0 END AS is_hit
    FROM movies
    WHERE budget  >= 100000
      AND revenue >= 100000
      AND tmdb_votes >= 10
),
stats AS (
    SELECT 'Rating'                          AS factor,
           '+1 rating point'                 AS unit,
           COUNT(*)                          AS movies,
           CORR(tmdb_rating, is_hit)         AS r,
           REGR_SLOPE(is_hit, tmdb_rating)   AS slope_per_unit
    FROM box_office
    UNION ALL
    SELECT 'Votes',
           'votes doubled',
           COUNT(*),
           CORR(LN(tmdb_votes), is_hit),
           REGR_SLOPE(is_hit, LN(tmdb_votes)) * LN(2)
    FROM box_office
)
SELECT factor,
       unit,
       movies,
       ROUND(r::numeric, 3)                                       AS r_hit,
       ROUND((100 * r * r)::numeric, 1)                           AS pct_explained,
       ROUND((r * SQRT((movies - 2) / (1 - r * r)))::numeric, 1)  AS t_stat,
       ROUND((100 * slope_per_unit)::numeric, 1)                  AS hit_chance_change_pp
FROM stats;
