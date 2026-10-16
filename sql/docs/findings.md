# Findings

Insights from the SQL analysis queries. Each finding names the query it comes from.

## 1. Movies vs TV shows by country
**Query:** `02_movies_vs_tv_by_country.sql`
**Scope:** countries with more than 100 titles (movies + TV shows) and at least one of each type. A title made by several countries counts once for each of them.

| Country | Titles | Movies | TV shows | Movies per TV show |
|---|---:|---:|---:|---:|
| Hong Kong | 105 | 100 | 5 | 20.00 |
| India | 1,046 | 962 | 84 | 11.45 |
| Nigeria | 103 | 94 | 9 | 10.44 |
| Egypt | 117 | 102 | 15 | 6.80 |
| Germany | 226 | 182 | 44 | 4.14 |
| France | 393 | 303 | 90 | 3.37 |
| United States | 3,690 | 2,752 | 938 | 2.93 |
| Spain | 232 | 171 | 61 | 2.80 |
| Turkey | 113 | 83 | 30 | 2.77 |
| Canada | 445 | 319 | 126 | 2.53 |
| China | 162 | 114 | 48 | 2.38 |
| United Kingdom | 806 | 534 | 272 | 1.96 |
| Mexico | 169 | 111 | 58 | 1.91 |
| Australia | 160 | 94 | 66 | 1.42 |
| Japan | 318 | 119 | 199 | 0.60 |
| South Korea | 231 | 61 | 170 | 0.36 |

- **India is the most movie-heavy of the large catalogues:** about 11 movies per TV show across 1,046 titles. Only Hong Kong has a higher ratio (20 to 1), but it barely passes the 100-title cut and has just 5 TV shows, so its ratio is fragile.
- **South Korea has the lowest ratio:** about 1 movie for every 3 TV shows (0.36). Japan is the only other country with more TV shows than movies (0.60). Both fit the strength of K-dramas and anime.
- **The United States sits near the middle** (2.93) but has the largest catalogue by far, with 3,690 titles.

## 2. India vs South Korea: movies vs TV shows over time
**Query:** `03_india_vs_south_korea_trend.sql` (second query: by release period)
**Scope:** India and South Korea only, grouped by the year titles were released. Assumes the data is correct and large enough to draw conclusions.

| Released | India movies | India TV shows | India % movies | South Korea movies | South Korea TV shows | South Korea % movies |
|---|---:|---:|---:|---:|---:|---:|
| before 2000 | 86 | 0 | 100.0 | 0 | 0 | – |
| 2000-2009 | 163 | 1 | 99.4 | 3 | 3 | 50.0 |
| 2010-2014 | 214 | 15 | 93.4 | 3 | 25 | 10.7 |
| 2015-2017 | 247 | 14 | 94.6 | 23 | 62 | 27.1 |
| 2018-2021 | 252 | 54 | 82.4 | 32 | 80 | 28.6 |

- **India has been focused on movies for a long time.** Before 2010 almost every Indian title on Netflix was a movie (249 movies vs 1 TV show), and movies still make up over 80% today.
- **South Korea's TV-show boom started after 2009.** Before 2010 it had only 6 titles on Netflix. From 2010 on, TV shows clearly lead, with 167 shows against 58 movies.

## 3. Do actors stay in movies or TV shows?
**Query:** `04_actor_career_paths.sql` (third query: summary by start type)
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
