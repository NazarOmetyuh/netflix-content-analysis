# Box Office Research: What Drives Movie Revenue?

This research answers three questions from the README:
- Is there a correlation between box office and rating?
- What is the budget elasticity of revenue? Do bigger budgets have diminishing returns?
- What influences revenue the most, and what comes with a hit?

It is based on five SQL files, `05` to `09`. Each factor is tested twice with the same formulas:
- **Revenue:** does it come with earning more money?
- **Hit or flop:** does it come with earning at least 2x the budget?

Part 1 explains the measures used, Part 2 shows the results of each query, and Part 3 compares all factors and lists the conclusions.

**Data used everywhere:** movies with a budget and revenue of at least $100K from TMDB (smaller values are junk, such as a $5 budget). Where rating or votes are used, movies also need at least 10 TMDB votes. That leaves 1,219-1,231 movies. TV shows have no box office, so they are not included.

**Limitation:** box office data exists for only about 1,231 of the 6,131 movies on Netflix (20%), mostly theatrical releases. Netflix Originals and small streaming films have none. The results therefore describe theatrical movies that later came to Netflix, not the Netflix catalogue as a whole.

---

# Part 1: How the measures work

## Pearson correlation (r)
r measures how strongly two values move together, on a scale from -1 to +1.

```
        Σ (x − x̄)(y − ȳ)
r = ─────────────────────────────
     √Σ(x − x̄)²  ·  √Σ(y − ȳ)²
```

- `x` and `y` are the two values for each movie (for example rating and revenue), and `x̄` and `ȳ` are their averages.
- **Top:** for each movie, multiply how far it is from the average on `x` by how far it is from the average on `y`, and add these up. If movies above average on one tend to be above average on the other, the sum is positive.
- **Bottom:** scales the result so it always lands between -1 and +1.
- In Postgres: `CORR(x, y)`.

| r | Meaning |
|---|---|
| +1 | Perfect: when x goes up, y always goes up proportionally |
| +0.5 or more | Strong positive relationship |
| about +0.3 | Moderate |
| +0.1 to +0.2 | Weak: the trend exists but has many exceptions |
| 0 | No straight-line relationship |
| negative | Opposite direction: when x goes up, y goes down |

A bigger r isn't "better". It means a stronger relationship, and the sign gives the direction.

## r² (share explained)
r² = r × r. It is **the share of the differences between movies that one factor explains on its own.** For example, r = 0.2 gives r² = 0.04: the factor explains 4% of why movies earn different amounts, and the other 96% comes from other things.

r² does **not** mean "the factor changes revenue by 4%". How much revenue changes is the slope (below). In Postgres: `REGR_R2(y, x)`.

## t-statistic (could it be chance?)
Even two unrelated values rarely give exactly r = 0 in a sample. The t-statistic checks whether r is too large to be luck.

```
t = r × √( (n − 2) / (1 − r²) )
```

- `n` is the number of movies. More movies or a larger r both give a larger t.
- **|t| above about 2:** less than a 5% chance that the relationship is luck, so it is "statistically significant".
- **Significant isn't the same as important.** With 1,200 movies even a weak r is significant. t says whether a relationship is *real*, and r says whether it is *strong*.

## Logarithms (LN)
Revenue is very skewed: most movies earn a few million, and a few earn over $1 billion. Without logs, those few blockbusters would decide the result. `LN()` squeezes big values together, and it turns "times" into "plus", so the results can be read as percentages.

## Spearman correlation
Pearson's r computed on **ranks** (1st, 2nd, 3rd...) instead of values. It only asks "do movies that rank higher on x also rank higher on y?" and ignores how big the gaps are. If Pearson and Spearman agree, the result isn't caused by a few extreme movies.

## Slope: how big the effect is
r and r² say how *reliable* a relationship is. The slope says how *big* it is: how much y changes when x goes up by one unit. In Postgres: `REGR_SLOPE(y, x)`.

- **Per rating point:** with `REGR_SLOPE(LN(revenue), rating)`, `EXP(slope) − 1` is the % change in revenue per extra rating point.
- **Elasticity:** when both sides are logged, `REGR_SLOPE(LN(revenue), LN(budget))`, the slope is the **% change in revenue for a 1% change in budget**.

| Elasticity | Meaning | Budget +10% gives... |
|---|---|---|
| 1 | Constant returns | revenue +10% |
| below 1 | Diminishing returns: each extra dollar brings back less | revenue +5% at 0.5 |
| above 1 | Increasing returns | revenue +12% at 1.2 |

## Track record (for actors and directors)
Each movie gets a score: the average log revenue of its lead actors' (or its director's) **other** movies. The movie itself is left out ("leave-one-out"), otherwise it would partly explain its own revenue. In SQL, a window function gives each person's total, and the movie's own revenue is subtracted:

```
(SUM(ln_revenue) OVER (PARTITION BY actor) − ln_revenue) / (COUNT(*) OVER (PARTITION BY actor) − 1)
```

## Hit, hit rate and lift
- **Hit:** a movie that earns at least 2x its budget (revenue multiple ≥ 2).
- **Hit rate:** share of movies in a group that are hits. Overall it is 57.2%.
- **Lift:** group hit rate / overall hit rate. A lift of 1.3 means 30% more likely to be a hit than average, and 0.8 means 20% less likely.

## Hit or flop: the same formulas on a yes/no outcome
To see what comes with hits, every factor is also correlated with `is_hit` (1 = hit, 0 = flop) instead of revenue. It's the same `CORR()`, `REGR_R2()` and `REGR_SLOPE()`. Pearson's r on a yes/no value is also called the point-biserial correlation.

- **r and r²** read the same way: r² is the share of the hit / flop differences the factor explains on its own.
- **The slope becomes a change in hit chance.** `REGR_SLOPE(is_hit, x) × 100` is the change in the chance of being a hit, in **percentage points (pp)**, per unit of x. For example, +13.6 pp per rating point means the hit chance goes from about 50% to about 64% when the rating goes up by 1.
- **For logged factors (budget, votes, track records) the unit is a doubling:** slope × LN(2).
- **r² for hits is always much smaller than for revenue.** A yes/no outcome carries less information than a dollar amount, and whether a movie pays back 2x depends on many things no single factor captures. So compare hit r² values with each other, not with revenue r² values.

## Quintiles
`NTILE(5)` sorts the movies and splits them into five equal-sized groups, Q1 (lowest) to Q5 (highest). This shows how revenue and hit rate change from the bottom to the top.

---

# Part 2: Research

## 1. Is there a correlation between box office and rating?
**Query:** [`05_box_office_vs_rating.sql`](../sql/05_box_office_vs_rating.sql) · **Movies:** 1,219

| Measure | r | t |
|---|---:|---:|
| Rating vs revenue (Pearson) | 0.170 | 6.0 |
| Rating vs log revenue (Pearson) | 0.194 | 6.9 |
| Rating vs revenue (Spearman, ranks) | 0.144 | 5.1 |
| Rating vs log revenue multiple (revenue / budget) | 0.301 | 11.0 |
| Log votes vs log revenue (for comparison) | 0.625 | 27.9 |

| Effect of +1 rating point | r² | Change |
|---|---:|---:|
| Revenue | 3.8% | **+54.5%** |
| Revenue / budget | 9.0% | **+67.3%** |

| Rating band | Movies | Median revenue | Median multiple | Hit rate |
|---|---:|---:|---:|---:|
| under 5.5 | 106 | $14.7M | 1.53x | 38.7% |
| 5.5-5.9 | 187 | $41.0M | 1.86x | 48.1% |
| 6.0-6.4 | 256 | $34.3M | 1.99x | 50.0% |
| 6.5-6.9 | 299 | $48.0M | 2.37x | 57.9% |
| 7.0-7.4 | 226 | $38.1M | 3.03x | 66.8% |
| 7.5 and above | 145 | $60.3M | 4.75x | 78.6% |

- **The correlation is real but weak.** All three versions give r = 0.15-0.20, and t = 5-7 shows it isn't chance. Rating alone explains only 3.8% of the differences in revenue.
- **The effect of one rating point is large anyway.** +1 point comes with about +55% revenue on average, so a 7.5 movie earns about 55% more than a 6.5 movie. Rating explains little only because movies with the same rating still earn very different amounts.
- **Rating matters more for profit than for revenue.** r with revenue / budget is 0.30, the median multiple rises from 1.5x to 4.75x across the bands, and the hit rate doubles from 39% to 79%.
- **How many people watched matters more than how much they liked it.** Votes correlate with revenue three times more strongly (r = 0.63) than rating does.

**Hit or flop** (fourth query)

| Factor | r with hit | Explains hit / flop (r²) | t | Hit chance change |
|---|---:|---:|---:|---:|
| Rating | 0.224 | 5.0% | 8.0 | **+13.6 pp per rating point** |
| Votes | 0.234 | 5.5% | 8.4 | +5.1 pp per doubling of votes |

- **For hits, rating is almost as strong as audience size.** For revenue, votes beat rating by 10 to 1 (39% vs 3.8%), but for hits they are nearly equal (5.5% vs 5.0%).
- **Each rating point adds about 14 percentage points to the chance of being a hit.** That makes rating the factor with the biggest effect on hits in this research.

## 2. How much do actors influence box office?
**Query:** [`06_actor_influence.sql`](../sql/06_actor_influence.sql) · **Movies:** 1,042 (at least one of the first 3 cast members has another box office movie)

| Measure | Value |
|---|---:|
| r (actor score vs log revenue) | 0.335 |
| **Share of revenue differences explained (r²)** | **11.2%** |
| t | 11.4 |
| Elasticity | 0.52 |
| Explained by budget, same movies | 46.4% |
| Overlap between actor score and budget (r) | 0.396 |

| Actor score quintile | Median track record of leads | Median revenue | Hit rate |
|---|---:|---:|---:|
| Q1 (weakest) | $8.1M | $14.0M | 56.9% |
| Q2 | $22.2M | $34.5M | 52.6% |
| Q3 | $46.7M | $37.7M | 51.0% |
| Q4 | $78.5M | $85.4M | 61.1% |
| Q5 (strongest) | $145.0M | $101.3M | 61.5% |

- **Actors explain about 11% of the differences in revenue.** That's three times more than rating but far less than budget.
- **Star power brings revenue, not much profit.** Movies with the strongest leads earn about 7 times more (median $101M vs $14M), but their hit rate is only slightly higher (62% vs 57%). Stars come with bigger budgets, which eat much of the extra revenue.
- **If the leads' other movies earned 10% more, a movie earns about 5% more** (elasticity 0.52).

**Hit or flop** (fifth query)

| Factor | r with hit | Explains hit / flop (r²) | t | Hit chance change |
|---|---:|---:|---:|---:|
| Lead actors' track record | 0.036 | 0.1% | 1.1 | +1.1 pp per doubling of track record |

- **Star actors don't make hits.** The actor score explains 0.1% of the hit / flop differences, and t = 1.1 means even that could be chance. Actors bring revenue (11%), but not profitability.

## 3. How much do directors influence box office?
**Query:** [`07_director_influence.sql`](../sql/07_director_influence.sql) · **Movies:** 584 (the director has another box office movie)

| Measure | Value |
|---|---:|
| r (director score vs log revenue) | 0.487 |
| **Share of revenue differences explained (r²)** | **23.7%** |
| t | 13.5 |
| Elasticity | 0.53 |
| Explained by budget, same movies | 43.1% |
| Overlap between director score and budget (r) | 0.431 |

| Director score quintile | Median track record of director | Median revenue | Hit rate |
|---|---:|---:|---:|
| Q1 (weakest) | $5.9M | $13.0M | 52.1% |
| Q2 | $27.3M | $40.2M | 54.7% |
| Q3 | $67.9M | $87.8M | 68.4% |
| Q4 | $132.7M | $118.9M | 59.0% |
| Q5 (strongest) | $294.5M | $182.9M | 69.8% |

- **Directors explain about 24% of the differences in revenue**, twice as much as actors and six times more than rating.
- **A director's track record predicts both revenue and hits.** Movies by the strongest directors earn about 14 times more (median $183M vs $13M) and are hits more often (70% vs 52%).
- **This covers only repeat directors.** One-off directors have no track record, so the result shows how much an *established* director's history matters.

**Hit or flop** (fifth query)

| Factor | r with hit | Explains hit / flop (r²) | t | Hit chance change |
|---|---:|---:|---:|---:|
| Director's track record | 0.123 | 1.5% | 3.0 | +2.7 pp per doubling of track record |

- **Directors come with hits, but only a little.** The link is real (t = 3.0) but small: doubling a director's track record adds about 2.7 percentage points to the hit chance. Still, directors do better than actors (0.1%, not significant) and budget (negative).

## 4. Budget elasticity of revenue
**Query:** [`08_budget_elasticity.sql`](../sql/08_budget_elasticity.sql) · **Movies:** 1,231

| Group | Movies | Budget range | Elasticity | r² |
|---|---:|---|---:|---:|
| All movies | 1,231 | $0.1M-$300M | 0.84 | 0.44 |
| Low budget | 411 | $0.1M-$9M | 0.56 | 0.11 |
| Mid budget | 410 | $9M-$30M | 1.25 | 0.09 |
| High budget | 410 | $30M-$300M | 1.17 | 0.24 |

| Budget quintile | Budget range | Median revenue | Median multiple | Hit rate |
|---|---|---:|---:|---:|
| Q1 (smallest) | $0.1M-$4.5M | $5.8M | 3.57x | 67.6% |
| Q2 | $4.5M-$12M | $16.7M | 2.18x | 53.7% |
| Q3 | $12M-$25M | $35.7M | 2.06x | 50.4% |
| Q4 | $25M-$52M | $80.1M | 2.23x | 56.1% |
| Q5 (biggest) | $53M-$300M | $196.5M | 2.20x | 57.7% |

- **Overall elasticity is 0.84:** 10% more budget comes with about 8.4% more revenue. Budget alone explains 44% of the differences in revenue.
- **Bigger budgets don't show diminishing returns.** Above about $9M the elasticity is above 1, and from $4.5M up the median multiple stays flat at about 2.1-2.2x. A $100M movie returns about the same multiple as a $10M movie.
- **The overall "below 1" comes only from very small budgets.** Movies under $4.5M have the highest multiple (3.6x). This is likely partly a data effect: a tiny film usually has box office data on TMDB only if it did well.

**Hit or flop** (fourth query)

| Factor | r with hit | Explains hit / flop (r²) | t | Hit chance change |
|---|---:|---:|---:|---:|
| Budget | -0.068 | 0.5% | -2.4 | **-1.6 pp per doubling of budget** |

- **A bigger budget slightly lowers the chance of a hit.** Doubling the budget comes with 1.6 percentage points *less* hit chance. The link is weak, but it points the wrong way: budget explains 44% of revenue and nothing of profitability.

## 5. What influences revenue, and what comes with a hit?
**Query:** [`09_revenue_drivers_and_hits.sql`](../sql/09_revenue_drivers_and_hits.sql) · **Movies:** 1,219 · **Overall hit rate:** 57.2%

| Outcome | Movies | Avg rating | Median votes | Median budget | Median revenue | Avg runtime | Avg release year |
|---|---:|---:|---:|---:|---:|---:|---:|
| Hit | 697 | 6.71 | 2,309 | $17.0M | $79.0M | 114.9 min | 2005.5 |
| Flop | 522 | 6.35 | 1,013 | $19.0M | $12.8M | 113.0 min | 2009.5 |

| Statistic | r with log revenue | Explains revenue | Revenue rank | r with hit | Explains hit / flop | t (hit) | Hit rank |
|---|---:|---:|---:|---:|---:|---:|---:|
| Votes (log) | 0.625 | 39.0% | 2 | 0.234 | 5.5% | 8.4 | 1 |
| Rating | 0.194 | 3.8% | 4 | 0.224 | 5.0% | 8.0 | 2 |
| Release year | -0.208 | 4.3% | 3 | -0.185 | 3.4% | -6.6 | 3 |
| Budget (log) | 0.659 | 43.4% | 1 | -0.070 | 0.5% | -2.5 | 4 |
| Runtime | 0.024 | 0.1% | 5 | 0.041 | 0.2% | 1.4 | 5 |

Groups with the highest and lowest hit rates (groups with at least 30 movies):

| Characteristic | Group | Movies | Hit rate | Lift |
|---|---|---:|---:|---:|
| Votes | top quartile | 304 | 81.3% | 1.42 |
| Rating | 7.5 and above | 145 | 78.6% | 1.38 |
| Decade | 1980s | 39 | 71.8% | 1.26 |
| Decade | 1990s | 142 | 71.1% | 1.24 |
| Genre | Horror | 104 | 69.2% | 1.21 |
| Budget | smallest quintile | 244 | 68.4% | 1.20 |
| ... | | | | |
| Genre | History | 80 | 43.8% | 0.77 |
| Rating | under 6.0 | 293 | 44.7% | 0.78 |
| Age rating | TV-MA | 96 | 44.8% | 0.78 |
| Votes | second quartile | 305 | 39.7% | 0.69 |

- **Budget decides how much a movie earns, but not whether it's a hit.** Budget has the strongest link to revenue (r = 0.66) but none to being a hit (r = -0.07). Hits and flops have about the same median budget ($17M vs $19M).
- **Audience size and quality come with hits most often.** The top quarter by votes are hits 81% of the time, and movies rated 7.5+ 79% of the time. Votes partly measure success itself (more viewers leave more votes), so rating is the cleaner signal.
- **Horror is the most reliable genre** (69% hits), likely because horror films are cheap to make. History and war films do worst (44-48%).
- **Older movies on Netflix are more often hits** (about 71% for the 1980s-1990s against 52% for the 2010s). Netflix probably licenses older films that are already proven classics, so this is a selection effect.
- **Runtime and age rating barely matter.** Their hit rates stay close to the average, except TV-MA (45%).

---

# Part 3: What contributes the most?

## Revenue vs hit or flop, side by side

| Factor | Explains revenue (r²) | Revenue rank | Explains hit / flop (r²) | Hit rank | Effect on revenue | Effect on hit chance | Query |
|---|---:|---:|---:|---:|---|---|---|
| Budget | **43%** | 1 | 0.5% (negative) | 5 | +10% budget → +8.4% revenue | **-1.6 pp** per doubling | 08 |
| Votes (audience size) | **39%** | 2 | **5.5%** | 1 | – | +5.1 pp per doubling | 05, 09 |
| Director's track record | **24%** | 3 | 1.5% | 4 | +10% track record → +5.3% revenue | +2.7 pp per doubling | 07 |
| Lead actors' track record | 11% | 4 | 0.1% (not significant) | 7 | +10% track record → +5.2% revenue | +1.1 pp per doubling | 06 |
| Release year | 4% | 5 | 3.4% (negative) | 3 | – | older movies are more often hits | 09 |
| Rating | 4% | 6 | **5.0%** | 2 | +1 point → +55% revenue | **+13.6 pp** per point | 05 |
| Runtime | 0% | 7 | 0.2% (not significant) | 6 | – | – | 09 |

**How to read this table:**
- **Compare within a column, not across.** Hit r² values are always much smaller than revenue r² values, because hit or flop is a yes/no outcome (see Part 1).
- **The percentages overlap and can't be added up.** Big-name directors and actors get bigger budgets (r of about 0.4 with budget), so part of what they explain is the budget itself.
- **Directors and actors are measured on fewer movies** (584 and 1,042): only movies whose director or leads have other box office movies.
- **These are correlations, not proof of cause.** For example, votes grow because many people watched a movie, so they partly measure success instead of causing it.

## What decides revenue vs what decides a hit

| | Revenue (how much a movie earns) | Hit or flop (whether it earns 2x its budget) |
|---|---|---|
| **Strongest** | Budget, audience size | Audience size, rating |
| **Middle** | Director, actors | Release year, director |
| **Weakest** | Release year, rating, runtime | Budget (negative), runtime, actors |

## Key findings
1. **Revenue and hits have different drivers.** Budget, audience size and big names decide *how much* a movie earns. Audience size and quality decide *whether it pays back 2x*.
2. **Money buys revenue, not profit.** Budget explains 43% of revenue but nothing of hits, and doubling the budget comes with slightly *fewer* hits (-1.6 pp). There are no diminishing returns on revenue above about $9M, but the multiple stays flat at about 2.2x.
3. **Quality is the strongest lever for a hit.** Rating explains only 4% of revenue, but it is the #2 factor for hits: each extra point adds about 55% revenue and about 14 percentage points of hit chance. 7.5+ movies are hits 79% of the time against 39% under 5.5.
4. **Directors matter more than actors, on both measures.** A director's track record explains 24% of revenue and has a small but real link to hits (+2.7 pp per doubling). Star actors explain 11% of revenue and nothing of hits: they bring box office, and a budget that eats it.
5. **Hits are hard to predict from any single factor.** Even the best one, audience size, explains only 5.5% of hit / flop differences. A hit needs several things together: a modest budget, a strong rating, a wide audience and an established director. Horror is the most reliable genre.
