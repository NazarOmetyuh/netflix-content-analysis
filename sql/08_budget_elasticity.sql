-- Q: What is the budget elasticity of revenue? Do bigger budgets have diminishing returns?
-- Scope: movies with budget and revenue of at least $100K (same rule as the dashboard).
-- Elasticity = slope of a log-log regression: LN(revenue) = a + b * LN(budget).
--   b = 1   revenue grows at the same rate as budget (constant returns)
--   b < 1   each extra dollar of budget brings less revenue (diminishing returns)
--   b > 1   bigger budgets pay back more than proportionally (increasing returns)
-- Postgres has this built in: REGR_SLOPE(y, x) and REGR_R2(y, x).


-- 1. Overall elasticity
SELECT COUNT(*)                                                         AS movies,
       ROUND(REGR_SLOPE(LN(revenue), LN(budget))::numeric, 3)           AS elasticity,
       ROUND(REGR_R2(LN(revenue), LN(budget))::numeric, 3)              AS r_squared
FROM movies
WHERE budget  >= 100000
  AND revenue >= 100000;


-- 2. Elasticity within budget tiers (three equal-sized groups)
-- If the slope is lower for big budgets, returns diminish as budgets grow.
WITH tiers AS (
    SELECT show_id,
           budget,
           revenue,
           NTILE(3) OVER (ORDER BY budget, show_id) AS tier
    FROM movies
    WHERE budget  >= 100000
      AND revenue >= 100000
)
SELECT CASE tier WHEN 1 THEN 'Low' WHEN 2 THEN 'Mid' ELSE 'High' END AS budget_tier,
       COUNT(*)                                                     AS movies,
       MIN(budget)                                                  AS min_budget,
       MAX(budget)                                                  AS max_budget,
       ROUND(REGR_SLOPE(LN(revenue), LN(budget))::numeric, 3)       AS elasticity,
       ROUND(REGR_R2(LN(revenue), LN(budget))::numeric, 3)          AS r_squared
FROM tiers
GROUP BY tier
ORDER BY tier;


-- 3. Return on budget by budget quintile (five equal-sized groups)
-- Median revenue multiple = revenue / budget. Hit = multiple of at least 2.
WITH quintiles AS (
    SELECT show_id,
           budget,
           revenue,
           revenue::float8 / budget::float8 AS revenue_multiple,
           NTILE(5) OVER (ORDER BY budget, show_id) AS quintile
    FROM movies
    WHERE budget  >= 100000
      AND revenue >= 100000
)
SELECT quintile,
       COUNT(*)                                                                    AS movies,
       MIN(budget)                                                                 AS min_budget,
       MAX(budget)                                                                 AS max_budget,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY budget)::numeric)         AS median_budget,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue)::numeric)        AS median_revenue,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue_multiple)::numeric, 2) AS median_multiple,
       ROUND(100.0 * AVG(CASE WHEN revenue_multiple >= 2 THEN 1 ELSE 0 END), 1)    AS hit_rate_pct
FROM quintiles
GROUP BY quintile
ORDER BY quintile;


-- 4. Hit or flop: do bigger budgets come with hits?
-- Same formulas, but against is_hit (1 = hit = revenue of at least 2x budget, 0 = flop).
-- pct_explained: share of the hit / flop differences budget explains on its own (r²).
-- hit_chance_change_pp: change in the chance of being a hit, in percentage points,
-- when the budget doubles (REGR_SLOPE on LN(budget) x LN(2)).
WITH box_office AS (
    SELECT LN(budget::float8)                                    AS ln_budget,
           CASE WHEN revenue >= 2 * budget THEN 1.0 ELSE 0.0 END AS is_hit
    FROM movies
    WHERE budget  >= 100000
      AND revenue >= 100000
),
stats AS (
    SELECT COUNT(*)                               AS movies,
           CORR(ln_budget, is_hit)                AS r,
           REGR_SLOPE(is_hit, ln_budget) * LN(2)  AS slope_per_doubling
    FROM box_office
)
SELECT movies,
       ROUND(r::numeric, 3)                                       AS r_hit,
       ROUND((100 * r * r)::numeric, 1)                           AS pct_explained,
       ROUND((r * SQRT((movies - 2) / (1 - r * r)))::numeric, 1)  AS t_stat,
       ROUND((100 * slope_per_doubling)::numeric, 1)              AS hit_chance_change_pp
FROM stats;
