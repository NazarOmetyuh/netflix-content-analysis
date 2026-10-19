# Experiment: Predicting 5 Upcoming Movies

**Made on:** 2026-10-19, before any of the films were released
**Query:** `10_experiment_upcoming_films.sql`
**Check results:** after the last film's box office is final (about March 2027)
**Two predictions per movie:** one before release (director, actors, genres, budget) and one for each possible rating and vote count after release

## Goal
The [box office research](box_office_research.md) found which factors come with hits. This experiment tests whether those findings can predict real movies **before** they come out. Five theatrical releases from late 2026 were picked, each by a director who already has box office movies in our Netflix data.

A hit means the same as in the research: **worldwide revenue of at least 2x the production budget**.

## The movies

| Movie | Release (US) | Director | Lead cast | Genres | Budget used |
|---|---|---|---|---|---:|
| Wife & Dog | Oct 23, 2026 | Guy Ritchie | Benedict Cumberbatch, Rosamund Pike, Anthony Hopkins | Comedy, Crime, Thriller | $30M* |
| I Play Rocky | Nov 6, 2026 (wide Nov 20) | Peter Farrelly | Anthony Ippolito, AnnaSophia Robb, Toby Kebbell | Drama, History | $25M* |
| Violent Night 2 | Dec 4, 2026 | Tommy Wirkola | David Harbour, Kristen Bell, Jared Harris | Action, Comedy, Crime, Thriller | $30M* |
| Avengers: Doomsday | Dec 18, 2026 | Anthony & Joe Russo | Robert Downey Jr., Chris Hemsworth, Chris Evans | Action, Adventure, Science Fiction | $400M** |
| The Angry Birds Movie 3 | Dec 23, 2026 | John Rice | Jason Sudeikis, Josh Gad, Danny McBride | Animation, Adventure, Comedy, Family | $65M* |

\* **Estimate.** No budget has been reported, so the cost of a comparable film is used: The Gentlemen (2019, $22M) for Wife & Dog, Green Book (2018, $23M) for I Play Rocky, Violent Night (2022, $20M) for its sequel, and The Angry Birds Movie 2 (2019, $65M) for the third film.
\*\* **Unofficial.** Several outlets report about $400M, citing anonymous sources.

## Method
Rating and votes were the strongest hit factors in the research, but they only exist **after** release, so they can't be used for a prediction. Only information known today is used, in four factors. Each one is turned into a hit rate from our data:

| Factor | What it measures | Research link with hits |
|---|---|---|
| Director | Hit rate of the director's movies in our data | Small but real (finding 3) |
| Lead actors | Hit rate of movies where any of the 3 leads was a lead | Very weak (finding 2) |
| Genres | Average hit rate of the movie's genres | Horror best, history and war worst (finding 5) |
| Budget | Hit rate of the budget quintile the movie falls into | Slightly negative (finding 4) |

**Small samples are adjusted.** A director with one hit in our data would get a 100% hit rate, which says almost nothing. Each rate is therefore pulled toward the overall hit rate (57.2%), as if 5 average movies were added:

```
adjusted hit rate = (hits + 5 × 57.2%) / (movies + 5)
```

**Predicted hit chance** = average of the four adjusted hit rates. **Prediction:** Hit if the chance is at least 50%, otherwise Flop. **Confidence:** High if the chance is 15+ points from 50%, Medium if 5-15 points, Low if under 5.

## Factors for each movie

| Movie | Director | Lead actors | Genres | Budget quintile |
|---|---|---|---|---|
| Avengers: Doomsday | 1 of 1 hits → **64.3%** | 9 of 11 → **74.1%** | 54.0% | Q5: 57.7% |
| The Angry Birds Movie 3 | 1 of 1 → 64.3% | 3 of 5 → 58.6% | 57.1% | Q5: 57.7% |
| Wife & Dog | 2 of 2 → **69.4%** | 4 of 7 → 57.1% | 55.1% | Q4: 56.1% |
| I Play Rocky | 2 of 4 → 53.9% | 2 of 3 → 60.7% | 49.9% | Q3: 50.5% |
| Violent Night 2 | 0 of 1 → **47.6%** | 1 of 2 → 55.1% | 55.6% | Q4: 56.1% |

Adjusted hit rates are shown, with the raw "hits of movies" behind them.

## Predictions

| Movie | Predicted hit chance | Prediction | Confidence | Revenue needed for a hit |
|---|---:|---|---|---:|
| Avengers: Doomsday | 62.5% | **Hit** | Medium | $800M |
| The Angry Birds Movie 3 | 59.4% | **Hit** | Medium | $130M |
| Wife & Dog | 59.4% | **Hit** | Medium | $60M |
| I Play Rocky | 53.8% | **Hit** | Low | $50M |
| Violent Night 2 | 53.6% | **Hit** | Low | $60M |

- **All five are predicted as hits, but none with high confidence.** Every chance is between 54% and 63%, close to the 57% base rate. That matches the research: without rating and votes, the information available before release only moves the odds a little.
- **Avengers: Doomsday is the most likely hit,** driven by its cast (9 of the leads' 11 movies in our data were hits). Even so, it needs about $800M worldwide just to reach 2x its reported budget.
- **Wife & Dog has the strongest director signal:** both Guy Ritchie movies in our data were hits (Lock, Stock and Two Smoking Barrels at 21x, Sherlock Holmes at 5.8x).
- **Violent Night 2 and I Play Rocky are close calls.** Tommy Wirkola's only movie in our data (What Happened to Monday) was a flop, and I Play Rocky's drama/history genres are among the weakest for hits.

## After-release scenarios
Rating and votes were the strongest hit factors in the research, but they only exist after release. This section prepares a prediction for **every likely outcome**: if a movie ends up with a given TMDB rating and number of votes, what is its hit chance and expected revenue? After release, look up the cell closest to the real rating and votes and compare it with the real box office.

### Method
The slope formula from the research, fitted on **rating and votes together**. They are related (well-rated movies get more votes), so fitting them separately would count the same effect twice. Fitted on 1,219 past movies (fourth query in the SQL file):

| Effect | Hit chance | Revenue multiple |
|---|---:|---:|
| +1 rating point | **+9.6 percentage points** | **+49.8%** |
| Votes doubled | +3.8 percentage points | +10.8% |
| Share explained by rating and votes together (r²) | 7.6% | 11.4% |
| Average past movie | rating 6.56, about 1,200 votes | multiple 2.07x |

- **Hit chance** = the movie's pre-release chance, moved up or down by how far its rating and votes are from the average past movie:
  `pre-release chance + 9.6 pp × (rating − 6.56) + 5.4 pp × (LN(votes) − LN(1,200))`, kept between 2% and 98%.
- **Expected revenue** = budget × typical multiple for that rating and votes. It is the middle outcome, not a guarantee.
- **The two numbers can disagree.** The hit chance includes the pre-release factors (director, actors, genres, budget), while expected revenue only uses rating and votes. When a cell says "Hit" but expected revenue is below the revenue needed, the call is close.

**How to read the tables:** each cell is *hit chance, prediction · expected worldwide revenue*. Hits are in bold.

**Votes need care.** Votes keep growing for years. Movies from 2020 in our data have a median of about 650 votes, and movies from 2005 about 2,000. A few months after release, a new movie's votes will look low compared with the past movies the model learned from. Read the votes columns as a minimum, and note the date when you check them.

**20,000 and 50,000 votes are outside most of our data.** Only 11 past movies have 20,000+ votes (all of them hits), and none has 50,000 (the most is about 40,400). Those two columns extend the fitted line beyond the data, so treat them as rough. A blockbuster like Avengers: Doomsday can still reach them within a year or two.

### Avengers: Doomsday
Pre-release chance: 62.5% · Revenue needed for a hit: $800M

| Rating \ Votes | 300 | 1,000 | 3,000 | 10,000 | 20,000 | 50,000 |
|---|---|---|---|---|---|---|
| **5.5** | 44.9% Flop · $440M | **51.4% Hit · $525M** | **57.4% Hit · $618M** | **63.9% Hit · $738M** | **67.7% Hit · $817M** | **72.7% Hit · $936M** |
| **6.0** | 49.7% Flop · $538M | **56.2% Hit · $643M** | **62.2% Hit · $756M** | **68.7% Hit · $903M** | **72.5% Hit · $1.00B** | **77.5% Hit · $1.15B** |
| **6.5** | **54.5% Hit · $659M** | **61.0% Hit · $787M** | **67.0% Hit · $925M** | **73.5% Hit · $1.11B** | **77.3% Hit · $1.22B** | **82.3% Hit · $1.40B** |
| **7.0** | **59.2% Hit · $806M** | **65.8% Hit · $963M** | **71.8% Hit · $1.13B** | **78.3% Hit · $1.35B** | **82.1% Hit · $1.50B** | **87.1% Hit · $1.72B** |
| **7.5** | **64.0% Hit · $987M** | **70.6% Hit · $1.18B** | **76.6% Hit · $1.39B** | **83.1% Hit · $1.66B** | **86.9% Hit · $1.83B** | **91.9% Hit · $2.10B** |
| **8.0** | **68.8% Hit · $1.21B** | **75.4% Hit · $1.44B** | **81.3% Hit · $1.70B** | **87.9% Hit · $2.03B** | **91.7% Hit · $2.25B** | **96.6% Hit · $2.57B** |

### The Angry Birds Movie 3
Pre-release chance: 59.4% · Revenue needed for a hit: $130M

| Rating \ Votes | 300 | 1,000 | 3,000 | 10,000 | 20,000 | 50,000 |
|---|---|---|---|---|---|---|
| **5.5** | 41.8% Flop · $71M | 48.3% Flop · $85M | **54.3% Hit · $100M** | **60.8% Hit · $120M** | **64.6% Hit · $133M** | **69.6% Hit · $152M** |
| **6.0** | 46.5% Flop · $87M | **53.1% Hit · $104M** | **59.1% Hit · $123M** | **65.6% Hit · $147M** | **69.4% Hit · $163M** | **74.4% Hit · $186M** |
| **6.5** | **51.3% Hit · $107M** | **57.9% Hit · $128M** | **63.9% Hit · $150M** | **70.4% Hit · $180M** | **74.2% Hit · $199M** | **79.2% Hit · $228M** |
| **7.0** | **56.1% Hit · $131M** | **62.7% Hit · $156M** | **68.6% Hit · $184M** | **75.2% Hit · $220M** | **79.0% Hit · $244M** | **83.9% Hit · $279M** |
| **7.5** | **60.9% Hit · $160M** | **67.5% Hit · $192M** | **73.4% Hit · $225M** | **80.0% Hit · $269M** | **83.8% Hit · $298M** | **88.7% Hit · $341M** |
| **8.0** | **65.7% Hit · $196M** | **72.3% Hit · $234M** | **78.2% Hit · $276M** | **84.8% Hit · $329M** | **88.5% Hit · $365M** | **93.5% Hit · $418M** |

### Wife & Dog
Pre-release chance: 59.4% · Revenue needed for a hit: $60M

| Rating \ Votes | 300 | 1,000 | 3,000 | 10,000 | 20,000 | 50,000 |
|---|---|---|---|---|---|---|
| **5.5** | 41.8% Flop · $33M | 48.3% Flop · $39M | **54.3% Hit · $46M** | **60.8% Hit · $55M** | **64.6% Hit · $61M** | **69.6% Hit · $70M** |
| **6.0** | 46.6% Flop · $40M | **53.1% Hit · $48M** | **59.1% Hit · $57M** | **65.6% Hit · $68M** | **69.4% Hit · $75M** | **74.4% Hit · $86M** |
| **6.5** | **51.4% Hit · $49M** | **57.9% Hit · $59M** | **63.9% Hit · $69M** | **70.4% Hit · $83M** | **74.2% Hit · $92M** | **79.2% Hit · $105M** |
| **7.0** | **56.2% Hit · $60M** | **62.7% Hit · $72M** | **68.7% Hit · $85M** | **75.2% Hit · $101M** | **79.0% Hit · $112M** | **84.0% Hit · $129M** |
| **7.5** | **61.0% Hit · $74M** | **67.5% Hit · $88M** | **73.5% Hit · $104M** | **80.0% Hit · $124M** | **83.8% Hit · $138M** | **88.8% Hit · $158M** |
| **8.0** | **65.7% Hit · $91M** | **72.3% Hit · $108M** | **78.3% Hit · $127M** | **84.8% Hit · $152M** | **88.6% Hit · $168M** | **93.6% Hit · $193M** |

### I Play Rocky
Pre-release chance: 53.8% · Revenue needed for a hit: $50M

| Rating \ Votes | 300 | 1,000 | 3,000 | 10,000 | 20,000 | 50,000 |
|---|---|---|---|---|---|---|
| **5.5** | 36.1% Flop · $27M | 42.7% Flop · $33M | 48.6% Flop · $39M | **55.2% Hit · $46M** | **59.0% Hit · $51M** | **63.9% Hit · $58M** |
| **6.0** | 40.9% Flop · $34M | 47.5% Flop · $40M | **53.4% Hit · $47M** | **60.0% Hit · $56M** | **63.8% Hit · $63M** | **68.7% Hit · $72M** |
| **6.5** | 45.7% Flop · $41M | **52.3% Hit · $49M** | **58.2% Hit · $58M** | **64.8% Hit · $69M** | **68.5% Hit · $77M** | **73.5% Hit · $88M** |
| **7.0** | **50.5% Hit · $50M** | **57.0% Hit · $60M** | **63.0% Hit · $71M** | **69.6% Hit · $85M** | **73.3% Hit · $94M** | **78.3% Hit · $107M** |
| **7.5** | **55.3% Hit · $62M** | **61.8% Hit · $74M** | **67.8% Hit · $87M** | **74.4% Hit · $103M** | **78.1% Hit · $115M** | **83.1% Hit · $131M** |
| **8.0** | **60.1% Hit · $75M** | **66.6% Hit · $90M** | **72.6% Hit · $106M** | **79.2% Hit · $127M** | **82.9% Hit · $140M** | **87.9% Hit · $161M** |

### Violent Night 2
Pre-release chance: 53.6% · Revenue needed for a hit: $60M

| Rating \ Votes | 300 | 1,000 | 3,000 | 10,000 | 20,000 | 50,000 |
|---|---|---|---|---|---|---|
| **5.5** | 35.9% Flop · $33M | 42.5% Flop · $39M | 48.5% Flop · $46M | **55.0% Hit · $55M** | **58.8% Hit · $61M** | **63.8% Hit · $70M** |
| **6.0** | 40.7% Flop · $40M | 47.3% Flop · $48M | **53.3% Hit · $57M** | **59.8% Hit · $68M** | **63.6% Hit · $75M** | **68.5% Hit · $86M** |
| **6.5** | 45.5% Flop · $49M | **52.1% Hit · $59M** | **58.0% Hit · $69M** | **64.6% Hit · $83M** | **68.4% Hit · $92M** | **73.3% Hit · $105M** |
| **7.0** | **50.3% Hit · $60M** | **56.9% Hit · $72M** | **62.8% Hit · $85M** | **69.4% Hit · $101M** | **73.1% Hit · $112M** | **78.1% Hit · $129M** |
| **7.5** | **55.1% Hit · $74M** | **61.7% Hit · $88M** | **67.6% Hit · $104M** | **74.2% Hit · $124M** | **77.9% Hit · $138M** | **82.9% Hit · $158M** |
| **8.0** | **59.9% Hit · $91M** | **66.4% Hit · $108M** | **72.4% Hit · $127M** | **79.0% Hit · $152M** | **82.7% Hit · $168M** | **87.7% Hit · $193M** |

### What the scenarios show
- **Rating decides most cases.** Each movie flips from Flop to Hit somewhere between a rating of 5.5 and 7.0, depending on votes and its pre-release chance.
- **Avengers: Doomsday is a hit in almost every scenario,** but at a 7.0 rating with few votes its expected revenue only just passes the $800M it needs. Its high budget makes 2x a hard line. With 20,000+ votes, which is realistic for an Avengers movie over time, its expected revenue passes $800M at every rating.
- **I Play Rocky and Violent Night 2 need a rating of about 6.5-7.0** with average votes to become likely hits, because their pre-release chances are the lowest.
- **A rating of 6.0 or lower with only about 300 votes means a likely flop for every movie.**

## Results (to fill in, about March 2027)
Replace the estimated budgets with reported ones, add the final worldwide box office, and run the fifth query in the SQL file. Write down each movie's TMDB rating and votes on the day you check, and take the prediction from the closest cell in the scenario table.

| Movie | Reported budget | Worldwide box office | Multiple | Actual result | Pre-release prediction | TMDB rating / votes (date) | Scenario prediction | Correct before? | Correct after? |
|---|---:|---:|---:|---|---|---|---|---|---|
| Avengers: Doomsday | | | | | Hit | | | | |
| The Angry Birds Movie 3 | | | | | Hit | | | | |
| Wife & Dog | | | | | Hit | | | | |
| I Play Rocky | | | | | Hit | | | | |
| Violent Night 2 | | | | | Hit | | | | |

If the scenario predictions are right more often than the pre-release ones, it confirms the research finding that rating and audience size matter most for hits.

**Baseline to beat:** always guessing "Hit" would be right about 57% of the time. Here it gives the same answers as the model, so five films can't show whether the model beats that baseline. The interesting part is whether the model's *ranking* holds: did the higher predicted chances do better?

## Limitations
- **Five movies is a demonstration, not a test.** With five films, even a perfect score could be luck.
- **Most budgets are estimates.** A different budget can change the budget quintile and, above all, the revenue needed for a hit.
- **Small samples for directors and actors.** Most directors have 1-4 movies in our data, and the data only includes movies that are on Netflix.
- **2x budget is a rough hit line.** It ignores marketing (often as much as the budget) and the cinemas' share of ticket sales.
- **The four factors are averaged with equal weights,** although the research found that directors matter more for hits than actors, and budget slightly works against them.

## Sources
- Release dates: [Avengers: Doomsday (Looper)](https://looper.com/1737855/avengers-doomsday-everything-we-know), [Violent Night 2 (Empire)](https://www.empireonline.com/movies/news/violent-night-2-christmas-2026-david-harbour-tommy-wirkola), [Wife & Dog (Coming Soon)](https://www.comingsoon.net/movies/news/2083957-wife-and-dog-plot-details-release-date-guy-ritchie), [I Play Rocky (Amazon)](https://www.aboutamazon.com/news/entertainment/i-play-rocky-trailer-cast-release-date-amazon-mgm-studios), [The Angry Birds Movie 3 (Rovio)](https://www.rovio.com/articles/mrbeast-and-salish-matter-join-the-flock-in-the-angry-birds-movie-3-in-theaters-december-23-2026/)
- Cast: [Violent Night 2 (Dark Horizons)](https://www.darkhorizons.com/?p=186363), [Wife & Dog (KinoCheck)](https://kinocheck.com/news/na5ooh/star-cast-of-guy-ritchies-new-film-continues-to-grow), [I Play Rocky (Wikipedia)](https://en.wikipedia.org/wiki/I_Play_Rocky), [The Angry Birds Movie 3 (Dark Horizons)](https://www.darkhorizons.com/?p=183480)
- Budget: [Avengers: Doomsday estimates (Soap Central)](https://soapcentral.com/entertainment/news-avengers-doomsday-pre-production-cost-reports-upcoming-marvel-project-seen-really-big-numbers-already)
