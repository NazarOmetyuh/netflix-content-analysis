WITH counts AS (
    SELECT country,
           COUNT(show_id) AS show_count,
           SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END) AS movie_count,
           SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_show_count
    FROM countries
    GROUP BY country
)
SELECT *,
       ROUND(1.0 * movie_count / tv_show_count, 2) AS relation
FROM counts
WHERE movie_count > 0 AND tv_show_count > 0 and show_count > 100
ORDER BY relation DESC;