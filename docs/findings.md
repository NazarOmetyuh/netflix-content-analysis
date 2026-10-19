# Findings

Insights from the SQL analysis queries. Each finding names the query it comes from.

## 1. Movies vs TV shows by country
**Query:** [`02_movies_vs_tv_by_country.sql`](../sql/02_movies_vs_tv_by_country.sql)
**Scope:** countries with more than 100 titles (movies + TV shows) and at least one of each type. A title made by several countries counts once for each of them. Countries include the ones TMDB filled in where Netflix had none.

| Country | Titles | Movies | TV shows | Movies per TV show |
|---|---:|---:|---:|---:|
| Hong Kong | 111 | 104 | 7 | 14.86 |
| India | 1,098 | 1,002 | 96 | 10.44 |
| Nigeria | 125 | 113 | 12 | 9.42 |
| Egypt | 134 | 118 | 16 | 7.38 |
| Germany | 237 | 192 | 45 | 4.27 |
| France | 413 | 318 | 95 | 3.35 |
| Turkey | 116 | 86 | 30 | 2.87 |
| Italy | 104 | 77 | 27 | 2.85 |
| United States | 3,870 | 2,853 | 1,017 | 2.81 |
| Canada | 464 | 331 | 133 | 2.49 |
| Spain | 249 | 176 | 73 | 2.41 |
| Brazil | 109 | 74 | 35 | 2.11 |
| China | 173 | 116 | 57 | 2.04 |
| United Kingdom | 838 | 551 | 287 | 1.92 |
| Mexico | 183 | 117 | 66 | 1.77 |
| Australia | 165 | 95 | 70 | 1.36 |
| Japan | 353 | 136 | 217 | 0.63 |
| South Korea | 267 | 67 | 200 | 0.34 |
| Taiwan | 104 | 22 | 82 | 0.27 |

- **India is the most movie-heavy of the large catalogues:** about 10 movies per TV show across 1,098 titles. Only Hong Kong has a higher ratio (15 to 1), but it barely passes the 100-title cut and has just 7 TV shows, so its ratio is fragile.
- **South Korea is among the most TV-heavy:** about 1 movie for every 3 TV shows (0.34). Only Taiwan is lower (0.27, with 104 titles). Japan is the only other country with more TV shows than movies (0.63). This fits the strength of K-dramas, Taiwanese dramas and anime.
- **The United States sits near the middle** (2.81) but has the largest catalogue by far, with 3,870 titles.

## 2. India vs South Korea: movies vs TV shows over time
**Query:** [`03_india_vs_south_korea_trend.sql`](../sql/03_india_vs_south_korea_trend.sql) (second query: by release period)
**Scope:** India and South Korea only, grouped by the year titles were released. Assumes the data is correct and large enough to draw conclusions.

| Released | India movies | India TV shows | India % movies | South Korea movies | South Korea TV shows | South Korea % movies |
|---|---:|---:|---:|---:|---:|---:|
| before 2000 | 87 | 0 | 100.0 | 0 | 0 | – |
| 2000-2009 | 165 | 1 | 99.4 | 3 | 3 | 50.0 |
| 2010-2014 | 227 | 18 | 92.7 | 3 | 25 | 10.7 |
| 2015-2017 | 251 | 17 | 93.7 | 23 | 69 | 25.0 |
| 2018-2021 | 272 | 60 | 81.9 | 38 | 103 | 27.0 |

- **India has been focused on movies for a long time.** Before 2010 almost every Indian title on Netflix was a movie (252 movies vs 1 TV show), and movies still make up over 80% today.
- **South Korea's TV-show boom started after 2009.** Before 2010 it had only 6 titles on Netflix. From 2010 on, TV shows clearly lead, with 197 shows against 64 movies.

## 3. Do actors stay in movies or TV shows?
**Query:** [`04_actor_career_paths.sql`](../sql/04_actor_career_paths.sql) (third query: summary by start type)
**Scope:** 342 actors with more than 10 titles on Netflix. The start type is the type of their titles in their earliest release year. The path is based on all their later titles. Assumes the data is correct and large enough to draw conclusions.

| Started in | Actors | Stayed only | Mostly stayed | Switched | Later titles of the same type |
|---|---:|---:|---:|---:|---:|
| Movies | 271 | 104 | 152 | 15 | 86.4% |
| TV shows | 62 | 4 | 33 | 25 | 54.5% |
| Both in first year | 9 | – | – | – | – |

- **Actors who start in movies almost always stay in movies.** 256 of 271 (94%) keep doing mostly movies, and 104 never play in a TV show at all.
- **Actors who start in TV shows often move.** Only 4 of 62 stay in TV only, and 25 (40%) end up doing mostly movies.
- **The switchers are mostly voice actors** (anime and animation, e.g. Daisuke Ono, Hiroshi Kamiya, Grey Griffin), who work in both animated series and animated films.

**Assumption: is the gap caused by the catalogue having more movies?**

At first glance, actors who start in movies are more likely to stay in their type (86.4%) than actors who start in TV shows (54.5%). But Netflix has far more movies than TV shows (6,131 vs 2,676, so 69.6% of the catalogue is movies). Any actor has more chances to get a movie role, which pushes everyone toward movies.

To check this, the later titles were reweighted as if the catalogue had equal numbers of movies and TV shows: every TV show counts 2.29 times (6,131 / 2,676).

| Started in | Later movies | Later TV shows | Later TV shows × 2.29 | Stayed in type (actual) | Stayed in type (equal catalogue) |
|---|---:|---:|---:|---:|---:|
| Movies | 3,084 | 484 | 1,109 | 86.4% | 73.6% |
| TV shows | 384 | 460 | 1,054 | 54.5% | 73.3% |

- **With an equal number of movies and TV shows, the gap disappears.** Both groups would stay in their starting type about 73% of the time.
- **So the gap is most likely caused by the data, not by actors.** Starting in movies doesn't make an actor more loyal to movies. The catalogue simply has more than twice as many movies as TV shows.
- **Actors do tend to stay in the type they start in** (about 3 out of 4 later roles), and this is the same for movies and TV shows.

---

The box office research (queries 05-09: rating, actors, directors, budget and hits) has its own file: [box_office_research.md](box_office_research.md).
