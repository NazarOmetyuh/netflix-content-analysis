-- Experiment: can our research predict whether 5 upcoming movies will be a hit or a flop?
-- Made on 2026-10-19, before any of the films were released. Results get checked once
-- their box office is final (about 2-3 months after release).
--
-- Only information known BEFORE release is used. Rating and votes were the strongest
-- hit factors in 05 and 09, but they only exist after release, so they can't be used here.
-- Four factors are used instead, each turned into a hit rate from our data:
--   1. Director:     hit rate of the director's movies in our data
--   2. Lead actors:  hit rate of movies where any of the 3 leads was a lead
--   3. Genres:       average hit rate of the movie's genres
--   4. Budget:       hit rate of the budget quintile the movie falls into
-- Small groups are adjusted toward the overall hit rate, so 1 movie can't give 0% or 100%:
--   adjusted hit rate = (hits + 5 x overall hit rate) / (movies + 5)
-- Predicted hit chance = average of the factors that have data.
-- Prediction: Hit if the chance is at least 50%, otherwise Flop.
-- Hit = worldwide revenue of at least 2x the production budget (same as 05-09).
--
-- Budgets: only Avengers: Doomsday has a reported figure (about $400M, unofficial).
-- The others are estimates from comparable films and must be replaced by the
-- reported budget when the results are checked.


-- 1. The 5 upcoming movies and the box office data, saved as temporary views
-- (dropped automatically when the session ends).
CREATE OR REPLACE TEMP VIEW upcoming AS
SELECT *
FROM (VALUES
    ('Avengers: Doomsday',          DATE '2026-12-18', 'Anthony Russo, Joe Russo',
     'Robert Downey Jr., Chris Hemsworth, Chris Evans',  'Action, Adventure, Science Fiction',
     400000000, 'reported estimate (unofficial)'),
    ('Violent Night 2',             DATE '2026-12-04', 'Tommy Wirkola',
     'David Harbour, Kristen Bell, Jared Harris',        'Action, Comedy, Crime, Thriller',
      30000000, 'estimate: Violent Night (2022) cost $20M'),
    ('Wife & Dog',                  DATE '2026-10-23', 'Guy Ritchie',
     'Benedict Cumberbatch, Rosamund Pike, Anthony Hopkins', 'Comedy, Crime, Thriller',
      30000000, 'estimate: The Gentlemen (2019) cost $22M'),
    ('I Play Rocky',                DATE '2026-11-06', 'Peter Farrelly',
     'Anthony Ippolito, AnnaSophia Robb, Toby Kebbell',  'Drama, History',
      25000000, 'estimate: Green Book (2018) cost $23M'),
    ('The Angry Birds Movie 3',     DATE '2026-12-23', 'John Rice',
     'Jason Sudeikis, Josh Gad, Danny McBride',          'Animation, Adventure, Comedy, Family',
      65000000, 'estimate: The Angry Birds Movie 2 (2019) cost $65M')
) AS t(film, release_date, directors, lead_cast, genres, budget, budget_source);

CREATE OR REPLACE TEMP VIEW box_office_hits AS
SELECT show_id,
       director,
       "cast",
       genres,
       budget,
       CASE WHEN revenue >= 2 * budget THEN 1 ELSE 0 END AS is_hit
FROM movies
WHERE budget  >= 100000
  AND revenue >= 100000;


-- 2. Each factor for each movie (to see where the prediction comes from)
CREATE OR REPLACE TEMP VIEW experiment_factors AS
WITH overall AS (
    SELECT AVG(is_hit::float8) AS hit_rate FROM box_office_hits
),
-- 2.1 Director
upcoming_directors AS (
    SELECT u.film, TRIM(d) AS director
    FROM upcoming u, unnest(string_to_array(u.directors, ',')) AS d
),
data_directors AS (
    SELECT DISTINCT b.show_id, TRIM(d) AS director, b.is_hit
    FROM box_office_hits b, unnest(string_to_array(b.director, ',')) AS d
),
director_factor AS (
    SELECT u.film,
           'Director'                                 AS factor,
           COUNT(DISTINCT dd.show_id)                 AS movies,
           COUNT(DISTINCT dd.show_id) FILTER (WHERE dd.is_hit = 1) AS hits
    FROM upcoming_directors u
    LEFT JOIN data_directors dd ON dd.director = u.director
    GROUP BY u.film
),
-- 2.2 Lead actors (first 3 names in the cast list)
upcoming_leads AS (
    SELECT u.film, TRIM(a) AS actor
    FROM upcoming u, unnest(string_to_array(u.lead_cast, ',')) AS a
),
data_leads AS (
    SELECT b.show_id, TRIM(a.actor) AS actor, b.is_hit
    FROM box_office_hits b,
         unnest(string_to_array(b."cast", ',')) WITH ORDINALITY AS a(actor, position)
    WHERE a.position <= 3
),
actor_factor AS (
    SELECT u.film,
           'Lead actors'                              AS factor,
           COUNT(DISTINCT dl.show_id)                 AS movies,
           COUNT(DISTINCT dl.show_id) FILTER (WHERE dl.is_hit = 1) AS hits
    FROM upcoming_leads u
    LEFT JOIN data_leads dl ON dl.actor = u.actor
    GROUP BY u.film
),
-- 2.3 Genres: hit rate per genre, then averaged over the movie's genres
genre_rates AS (
    SELECT TRIM(g) AS genre, COUNT(*) AS movies, SUM(is_hit) AS hits
    FROM box_office_hits, unnest(string_to_array(genres, ',')) AS g
    GROUP BY TRIM(g)
),
genre_factor AS (
    SELECT u.film,
           'Genres'                                   AS factor,
           SUM(gr.movies)                             AS movies,
           SUM(gr.hits)                               AS hits,
           AVG((gr.hits + 5 * o.hit_rate) / (gr.movies + 5)) AS adjusted_rate
    FROM upcoming u
    CROSS JOIN overall o
    CROSS JOIN LATERAL unnest(string_to_array(u.genres, ',')) AS g
    JOIN genre_rates gr ON gr.genre = TRIM(g)
    GROUP BY u.film
),
-- 2.4 Budget quintile: same five groups as 08_budget_elasticity.sql
quintiles AS (
    SELECT budget, is_hit, NTILE(5) OVER (ORDER BY budget, show_id) AS quintile
    FROM box_office_hits
),
quintile_rates AS (
    SELECT quintile, MIN(budget) AS min_budget, MAX(budget) AS max_budget,
           COUNT(*) AS movies, SUM(is_hit) AS hits
    FROM quintiles
    GROUP BY quintile
),
budget_factor AS (
    SELECT u.film,
           'Budget quintile Q' || q.quintile          AS factor,
           q.movies,
           q.hits
    FROM upcoming u
    -- the first quintile whose biggest budget is at least the movie's budget
    -- (a budget above every quintile goes to Q5)
    CROSS JOIN LATERAL (
        SELECT *
        FROM quintile_rates qr
        WHERE u.budget <= qr.max_budget OR qr.quintile = 5
        ORDER BY qr.quintile
        LIMIT 1
    ) q
),
all_factors AS (
    SELECT film, factor, movies, hits, NULL::float8 AS adjusted_rate FROM director_factor
    UNION ALL
    SELECT film, factor, movies, hits, NULL FROM actor_factor
    UNION ALL
    SELECT film, factor, movies, hits, adjusted_rate FROM genre_factor
    UNION ALL
    SELECT film, factor, movies, hits, NULL FROM budget_factor
)
SELECT f.film,
       f.factor,
       f.movies,
       f.hits,
       CASE WHEN f.movies > 0 THEN ROUND(100.0 * f.hits / f.movies, 1) END AS raw_hit_rate_pct,
       CASE
           WHEN f.adjusted_rate IS NOT NULL THEN f.adjusted_rate
           WHEN f.movies > 0 THEN (f.hits + 5 * o.hit_rate) / (f.movies + 5)
       END AS adjusted_rate
FROM all_factors f
CROSS JOIN overall o;

SELECT film,
       factor,
       movies,
       hits,
       raw_hit_rate_pct,
       ROUND((100 * adjusted_rate)::numeric, 1) AS adjusted_hit_rate_pct
FROM experiment_factors
ORDER BY film, factor;


-- 3. Prediction for each movie
SELECT u.film,
       u.release_date,
       u.budget                                                   AS budget_used,
       u.budget_source,
       2 * u.budget                                               AS revenue_needed_for_hit,
       COUNT(f.adjusted_rate)                                     AS factors_with_data,
       ROUND((100 * AVG(f.adjusted_rate))::numeric, 1)            AS predicted_hit_chance_pct,
       CASE WHEN AVG(f.adjusted_rate) >= 0.5 THEN 'Hit' ELSE 'Flop' END AS prediction,
       CASE
           WHEN ABS(AVG(f.adjusted_rate) - 0.5) >= 0.15 THEN 'High'
           WHEN ABS(AVG(f.adjusted_rate) - 0.5) >= 0.05 THEN 'Medium'
           ELSE 'Low'
       END                                                        AS confidence
FROM upcoming u
LEFT JOIN experiment_factors f ON f.film = u.film
GROUP BY u.film, u.release_date, u.budget, u.budget_source
ORDER BY predicted_hit_chance_pct DESC;


-- 4. After-release scenarios: what if the movie gets rating R with V votes?
-- Rating and votes are only known after release, but they were the strongest hit factors
-- (05, 09). This query gives, for each movie, a prediction for 6 ratings x 6 vote counts.
-- After release, find the row closest to the movie's real TMDB rating and votes, and
-- compare it with the real result.
--
-- Method: the slope formula from 05, fitted on rating and LN(votes) TOGETHER (two-variable
-- regression), because rating and votes are related and would otherwise be counted twice.
-- With two variables x1, x2 and outcome y, using variances and covariances:
--   b1 = (cov(x1,y) var(x2) - cov(x2,y) cov(x1,x2)) / (var(x1) var(x2) - cov(x1,x2)²)
--   b2 = (cov(x2,y) var(x1) - cov(x1,y) cov(x1,x2)) / (var(x1) var(x2) - cov(x1,x2)²)
-- Hit chance:       pre-release chance (query 3)
--                   + b1 x (rating - average rating) + b2 x (LN(votes) - average LN(votes)),
--                   kept between 2% and 98%. y = is_hit.
-- Expected revenue: budget x typical multiple, where
--                   LN(multiple) = average LN(multiple) + b1 x (...) + b2 x (...). y = LN(revenue / budget).
-- r_squared shows how much of the differences the two variables explain together.
-- Votes keep growing for years: movies from 2020 in our data have a median of about 650 votes,
-- movies from 2005 about 2,000. A new movie's votes a few months after release will look low.
CREATE OR REPLACE TEMP VIEW scenario_model AS
WITH past AS (
    SELECT tmdb_rating                                              AS x1,
           LN(tmdb_votes)                                           AS x2,
           CASE WHEN revenue >= 2 * budget THEN 1.0 ELSE 0.0 END    AS hit,
           LN(revenue::float8 / budget::float8)                     AS ln_multiple
    FROM movies
    WHERE budget  >= 100000
      AND revenue >= 100000
      AND tmdb_votes >= 10
),
s AS (
    SELECT VAR_POP(x1)                 AS v1,
           VAR_POP(x2)                 AS v2,
           COVAR_POP(x1, x2)           AS c12,
           COVAR_POP(x1, hit)          AS c1h,
           COVAR_POP(x2, hit)          AS c2h,
           VAR_POP(hit)                AS vh,
           COVAR_POP(x1, ln_multiple)  AS c1m,
           COVAR_POP(x2, ln_multiple)  AS c2m,
           VAR_POP(ln_multiple)        AS vm,
           AVG(x1)                     AS avg_rating,
           AVG(x2)                     AS avg_ln_votes,
           AVG(ln_multiple)            AS avg_ln_multiple,
           COUNT(*)                    AS movies
    FROM past
),
coefficients AS (
    SELECT *,
           (c1h * v2 - c2h * c12) / (v1 * v2 - c12 * c12) AS b1_hit,
           (c2h * v1 - c1h * c12) / (v1 * v2 - c12 * c12) AS b2_hit,
           (c1m * v2 - c2m * c12) / (v1 * v2 - c12 * c12) AS b1_multiple,
           (c2m * v1 - c1m * c12) / (v1 * v2 - c12 * c12) AS b2_multiple
    FROM s
)
SELECT movies,
       avg_rating,
       avg_ln_votes,
       avg_ln_multiple,
       b1_hit,
       b2_hit,
       b1_multiple,
       b2_multiple,
       (b1_hit * c1h + b2_hit * c2h) / vh                    AS r_squared_hit,
       (b1_multiple * c1m + b2_multiple * c2m) / vm          AS r_squared_multiple
FROM coefficients;

-- 4.1 The fitted model in plain numbers
SELECT movies,
       ROUND((100 * b1_hit)::numeric, 1)                          AS hit_pp_per_rating_point,
       ROUND((100 * b2_hit * LN(2))::numeric, 1)                  AS hit_pp_per_votes_doubling,
       ROUND((100 * r_squared_hit)::numeric, 1)                   AS hit_pct_explained,
       ROUND((100 * (EXP(b1_multiple) - 1))::numeric, 1)          AS multiple_pct_per_rating_point,
       ROUND((100 * (EXP(b2_multiple * LN(2)) - 1))::numeric, 1)  AS multiple_pct_per_votes_doubling,
       ROUND((100 * r_squared_multiple)::numeric, 1)              AS multiple_pct_explained,
       ROUND(avg_rating::numeric, 2)                              AS avg_rating,
       ROUND(EXP(avg_ln_votes)::numeric)                          AS typical_votes
FROM scenario_model;

-- 4.2 Scenarios for each movie
CREATE OR REPLACE TEMP VIEW experiment_scenarios AS
WITH pre_release AS (
    SELECT film, AVG(adjusted_rate) AS chance
    FROM experiment_factors
    GROUP BY film
),
ratings(rating) AS (VALUES (5.5), (6.0), (6.5), (7.0), (7.5), (8.0)),
votes(votes)    AS (VALUES (300), (1000), (3000), (10000), (20000), (50000))
SELECT u.film,
       r.rating,
       v.votes,
       p.chance                                                          AS pre_release_chance,
       LEAST(0.98, GREATEST(0.02,
             p.chance
             + m.b1_hit * (r.rating - m.avg_rating)
             + m.b2_hit * (LN(v.votes) - m.avg_ln_votes)))               AS scenario_chance,
       u.budget * EXP(m.avg_ln_multiple
                      + m.b1_multiple * (r.rating - m.avg_rating)
                      + m.b2_multiple * (LN(v.votes) - m.avg_ln_votes))  AS expected_revenue,
       2 * u.budget                                                      AS revenue_needed_for_hit
FROM upcoming u
JOIN pre_release p ON p.film = u.film
CROSS JOIN ratings r
CROSS JOIN votes v
CROSS JOIN scenario_model m;

SELECT film,
       rating,
       votes,
       ROUND((100 * pre_release_chance)::numeric, 1)                 AS pre_release_chance_pct,
       ROUND((100 * scenario_chance)::numeric, 1)                    AS scenario_hit_chance_pct,
       CASE WHEN scenario_chance >= 0.5 THEN 'Hit' ELSE 'Flop' END   AS prediction,
       ROUND(expected_revenue::numeric, -5)                          AS expected_revenue,
       revenue_needed_for_hit
FROM experiment_scenarios
ORDER BY film, rating, votes;


-- 5. Checking the results (run once the box office is final)
-- Fill in the reported budget and the final worldwide box office, then run.
-- WITH actual(film, actual_budget, worldwide_revenue) AS (
--     VALUES ('Avengers: Doomsday',      NULL::bigint, NULL::bigint),
--            ('Violent Night 2',         NULL, NULL),
--            ('Wife & Dog',              NULL, NULL),
--            ('I Play Rocky',            NULL, NULL),
--            ('The Angry Birds Movie 3', NULL, NULL)
-- )
-- SELECT film,
--        ROUND(1.0 * worldwide_revenue / actual_budget, 2)                        AS revenue_multiple,
--        CASE WHEN worldwide_revenue >= 2 * actual_budget THEN 'Hit' ELSE 'Flop' END AS actual_result
-- FROM actual;
