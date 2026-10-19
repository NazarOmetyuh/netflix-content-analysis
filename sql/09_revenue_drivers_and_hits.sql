-- Q: What influences revenue, and which characteristics most often come with a hit?
-- Scope: movies with budget and revenue of at least $100K and at least 10 TMDB votes.
-- Hit = revenue of at least 2x budget.
-- Lift = hit rate of a group / overall hit rate. Lift 1.3 means 30% more likely to be a hit.
-- These are correlations, not causes. Votes in particular grow because a movie
-- was seen by many people, so they partly measure success instead of driving it.


-- 1. Box office movies, saved as a temporary view for queries 2-4
-- (dropped automatically when the session ends).
CREATE OR REPLACE TEMP VIEW box_office AS
SELECT show_id,
       title,
       release_year,
       duration_value                               AS runtime_min,
       rating                                       AS age_rating,
       genres,
       TRIM(SPLIT_PART(country, ',', 1))            AS lead_country,
       tmdb_rating,
       tmdb_votes,
       budget::float8                               AS budget,
       revenue::float8                              AS revenue,
       revenue::float8 / budget::float8             AS revenue_multiple,
       CASE WHEN revenue >= 2 * budget THEN 1 ELSE 0 END AS is_hit
FROM movies
WHERE budget  >= 100000
  AND revenue >= 100000
  AND tmdb_votes >= 10;


-- 2. Hits vs flops: typical values of each statistic
SELECT CASE is_hit WHEN 1 THEN 'Hit' ELSE 'Flop' END                                  AS outcome,
       COUNT(*)                                                                        AS movies,
       ROUND(AVG(tmdb_rating)::numeric, 2)                                             AS avg_rating,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY tmdb_votes)::numeric)         AS median_votes,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY budget)::numeric)             AS median_budget,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue)::numeric)            AS median_revenue,
       ROUND(AVG(runtime_min)::numeric, 1)                                             AS avg_runtime_min,
       ROUND(AVG(release_year)::numeric, 1)                                            AS avg_release_year
FROM box_office
GROUP BY is_hit
ORDER BY is_hit DESC;


-- 3. Which numeric statistics move with revenue and with being a hit?
-- r with log revenue: how strongly the statistic moves with how much a movie earns.
-- r with hit (0/1):   how strongly it moves with earning at least 2x its budget.
WITH correlations AS (
    SELECT 'Votes (log)'   AS statistic, CORR(LN(tmdb_votes), LN(revenue)) AS r_log_revenue, CORR(LN(tmdb_votes), is_hit) AS r_hit FROM box_office
    UNION ALL
    SELECT 'Budget (log)',               CORR(LN(budget),      LN(revenue)),                 CORR(LN(budget),      is_hit)         FROM box_office
    UNION ALL
    SELECT 'Rating',                     CORR(tmdb_rating,     LN(revenue)),                 CORR(tmdb_rating,     is_hit)         FROM box_office
    UNION ALL
    SELECT 'Runtime',                    CORR(runtime_min,     LN(revenue)),                 CORR(runtime_min,     is_hit)         FROM box_office
    UNION ALL
    SELECT 'Release year',               CORR(release_year,    LN(revenue)),                 CORR(release_year,    is_hit)         FROM box_office
)
-- pct_explained = r² x 100: share of the differences the statistic explains on its own.
-- The two ranks show that what explains revenue is not the same as what explains hits.
SELECT statistic,
       ROUND(r_log_revenue::numeric, 3)                                AS r_log_revenue,
       ROUND((100 * r_log_revenue * r_log_revenue)::numeric, 1)        AS revenue_pct_explained,
       RANK() OVER (ORDER BY ABS(r_log_revenue) DESC)                  AS revenue_rank,
       ROUND(r_hit::numeric, 3)                                        AS r_hit,
       ROUND((100 * r_hit * r_hit)::numeric, 1)                        AS hit_pct_explained,
       ROUND((r_hit * SQRT((n - 2) / (1 - r_hit * r_hit)))::numeric, 1) AS hit_t_stat,
       RANK() OVER (ORDER BY ABS(r_hit) DESC)                          AS hit_rank
FROM correlations,
     (SELECT COUNT(*) AS n FROM box_office) AS movies
ORDER BY hit_rank;


-- 4. Which characteristics come with hits most often?
-- Each movie is put into groups (genre, age rating, rating band, votes quartile,
-- budget quintile, runtime band, decade, lead country), and each group's hit rate
-- is compared with the overall hit rate. Only groups with at least 30 movies.
WITH overall AS (
    SELECT AVG(is_hit) AS hit_rate FROM box_office
),
with_bands AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY tmdb_votes, show_id) AS votes_quartile,
           NTILE(5) OVER (ORDER BY budget, show_id)     AS budget_quintile
    FROM box_office
),
groups AS (
    SELECT 'Genre' AS characteristic, TRIM(g) AS value, is_hit
    FROM with_bands, unnest(string_to_array(genres, ',')) AS g
    WHERE genres IS NOT NULL
    UNION ALL
    SELECT 'Age rating', age_rating, is_hit FROM with_bands WHERE age_rating IS NOT NULL
    UNION ALL
    SELECT 'Rating band',
           CASE WHEN tmdb_rating < 6.0 THEN 'under 6.0'
                WHEN tmdb_rating < 7.0 THEN '6.0-6.9'
                WHEN tmdb_rating < 7.5 THEN '7.0-7.4'
                ELSE '7.5 and above' END,
           is_hit
    FROM with_bands
    UNION ALL
    SELECT 'Votes quartile', 'Q' || votes_quartile || CASE votes_quartile WHEN 1 THEN ' (fewest)' WHEN 4 THEN ' (most)' ELSE '' END, is_hit FROM with_bands
    UNION ALL
    SELECT 'Budget quintile', 'Q' || budget_quintile || CASE budget_quintile WHEN 1 THEN ' (smallest)' WHEN 5 THEN ' (biggest)' ELSE '' END, is_hit FROM with_bands
    UNION ALL
    SELECT 'Runtime',
           CASE WHEN runtime_min < 95  THEN 'under 95 min'
                WHEN runtime_min < 120 THEN '95-119 min'
                ELSE '120+ min' END,
           is_hit
    FROM with_bands
    UNION ALL
    SELECT 'Decade', (release_year / 10 * 10)::text || 's', is_hit FROM with_bands
    UNION ALL
    SELECT 'Lead country', lead_country, is_hit FROM with_bands WHERE lead_country IS NOT NULL
)
SELECT characteristic,
       value,
       COUNT(*)                                          AS movies,
       ROUND(100.0 * AVG(is_hit), 1)                     AS hit_rate_pct,
       ROUND((AVG(is_hit) / (SELECT hit_rate FROM overall))::numeric, 2) AS lift,
       RANK() OVER (ORDER BY AVG(is_hit) DESC)           AS hit_rank
FROM groups
GROUP BY characteristic, value
HAVING COUNT(*) >= 30
ORDER BY lift DESC;
