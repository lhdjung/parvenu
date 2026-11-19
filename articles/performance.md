# Performance: fast paths and slow paths

``` r

library(parvenu)
```

parvenu’s functions are fast without any tuning. A few habits make them
faster still, and a few inputs quietly take a slow path. This article
collects both. If you are new to parvenu, start with the [use case
examples](https://lhdjung.github.io/parvenu/articles/use-cases.md),
which show what each function is for.

Every timing here comes from one script,
[`bench/performance.R`](https://github.com/lhdjung/parvenu/blob/main/bench/performance.R),
run on 8 cores. Its output, with the R version and platform, is in
[`bench/performance.out`](https://github.com/lhdjung/parvenu/blob/main/bench/performance.out).
The numbers are medians, rounded. Run the script to get your own.

## Keep repeated values as a factor

A column that repeats a few values, such as a country, a product code,
or a status, is faster as a factor.
[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md),
`%par_in%`, and the text functions then work on the levels only, and
give each element the result of its level:

``` r

country <- factor(c("France", "Peru", "France", "Chad", "Peru"))

country %par_in% c("Peru", "Chad")
#> [1] FALSE  TRUE FALSE  TRUE  TRUE
par_detect(country, "^P")
#> [1] FALSE  TRUE FALSE FALSE  TRUE
par_match_term(country, c("an", "er"))
#> [1]  1  2  1 NA  2
```

The results are the same as for a character vector. With 10 million
elements, a factor takes about a tenth of the time:

| 10 million elements | Character | Factor |
|:---|---:|---:|
| [`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md) in 10 million strings, 100 distinct values | 79ms | 8ms |
| [`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md) in 10 million strings, 100,000 distinct values | 107ms | 16ms |
| [`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md), 100 distinct values | 36ms | 4ms |
| [`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md), 100,000 distinct values | 75ms | 6ms |

Base [`match()`](https://rdrr.io/r/base/match.html) takes 2.3s and 1.6s
for the two lookups, factor or not.

So keep such a column as a factor if it already is one, rather than
calling [`as.character()`](https://rdrr.io/r/base/character.html) on it
first. Converting a character column with
[`par_factor()`](https://lhdjung.github.io/parvenu/reference/par_factor.md)
pays off if you use it more than once. It takes 33ms for 100 distinct
values, but 0.56s for 100,000, most of it sorting the levels.

## Ask for no more than you need

The threads find the matches, but only R’s own thread can make R
strings. So a function that returns positions, counts, or `TRUE` and
`FALSE` is faster than one that returns strings. For one regex in
100,000 strings:

| Function | Returns | Time |
|:---|:---|---:|
| [`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md) | logical | 2.2ms |
| [`par_count()`](https://lhdjung.github.io/parvenu/reference/par_detect.md) | integer | 2.9ms |
| [`par_locate()`](https://lhdjung.github.io/parvenu/reference/par_extract.md) | integer matrix | 3.0ms |
| [`par_extract()`](https://lhdjung.github.io/parvenu/reference/par_extract.md) | strings | 8.5ms |
| [`par_extract_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md) | list of strings | 10ms |
| [`par_replace_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md) | strings | 12ms |

To filter rows, use
[`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
rather than checking the result of
[`par_extract()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
for `NA`. To count words, use
[`par_count()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
rather than the lengths of
[`par_extract_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md).

## Many terms: a dictionary, not `(?i)`

An alternation of literal terms, such as `"aspirin|ibuprofen"`, is fast
in
[`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md).
With `(?i)` in front, it is not. `par_match_term(ignore_case = TRUE)`
keeps its speed. For 1,000 terms in 100,000 strings:

| Call | Time |
|:---|---:|
| [`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md), alternation | 51ms |
| [`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md), alternation with `(?i)` | 15s |
| [`par_match_term()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md) | 18ms |
| `par_match_term(ignore_case = TRUE)` | 18ms |

The term functions also keep the automaton of the last `terms`. Building
it for 10,000 terms takes most of the 11ms that a first search of 100
strings needs. A call that repeats the same `terms`, as on every
keystroke in a Shiny app, takes 0.16ms. The same goes for the last regex
of
[`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
and its relatives.

## One call, not one per chunk

A single call on the whole input beats splitting it across R processes
that each call parvenu. Counting a regex in 400,000 strings takes 35ms
in one call, and 96ms split across 8 forked workers, since the workers
have to start and the results have to come back. Giving each worker one
thread doesn’t help: 103ms. Use process pools for R code that parvenu
doesn’t cover.

The default is all cores. On a machine you share, set
`options(parvenu.threads = 4)` once, or the `RAYON_NUM_THREADS`
environment variable. Inputs too small to keep that many threads busy
use fewer on their own, so there is no need to lower `nthreads` for
them.

## Small inputs

The base R family
([`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md),
[`par_duplicated()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md),
[`par_rank()`](https://lhdjung.github.io/parvenu/reference/par_rank.md),
and so on) calls base R itself below 10,000 elements. So these functions
are within a few microseconds of base there, and safe to use where the
size varies. The gain starts right above that size and grows with it:

| Elements | [`match()`](https://rdrr.io/r/base/match.html) | [`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md) |
|---:|---:|---:|
| 1,000 | 0.01ms | 0.02ms |
| 10,000 | 0.34ms | 0.10ms |
| 100,000 | 18ms | 0.7ms |

The text functions always run in Rust, since their results differ from
base R’s. Below 5,000 strings they use one thread.

## Inputs that take a slow path

These give correct results, but at base R’s speed or close to it. None
of them warns.

**Strings in mixed encodings.**
[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md),
[`par_duplicated()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md),
and
[`par_unique()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md)
compare strings by where R stores them, which only works if equal
strings are stored once. If a vector holds non-ASCII strings both as
UTF-8 and as latin1, they leave it to base R. Convert once with
[`enc2utf8()`](https://rdrr.io/r/base/Encoding.html):

``` r

x <- c("café", iconv("café", "UTF-8", "latin1"))
Encoding(x)
#> [1] "UTF-8"  "latin1"
x <- enc2utf8(x)
Encoding(x)
#> [1] "UTF-8" "UTF-8"
```

With a single latin1 string among a million,
[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
takes 39ms, more than base
[`match()`](https://rdrr.io/r/base/match.html) at 31ms. After
[`enc2utf8()`](https://rdrr.io/r/base/Encoding.html), and including it,
it takes 11ms.

**Times in a time zone other than UTC.**
[`par_as_posixct()`](https://lhdjung.github.io/parvenu/reference/par_as_date.md)
reads UTC times directly. In other zones, base R’s code places the local
times, on days with a change of clock every one of them. A million times
over 54 years take 13ms in UTC and 0.34s in `"Europe/Berlin"`, against
14s and 22s in base. If your times are in UTC, say `tz = "UTC"` rather
than leaving the session’s time zone to decide.

Also pass `format` if you know it. Without it, the first of `tryFormats`
that reads every string is used, as in base R. A single time that the
clock skipped, such as 02:30 on the night it moved from 02:00 to 03:00,
is `NA` in its zone. So it fails every format with a time of day, and
the date-only format takes over for the whole vector:

``` r

x <- c("2024-03-31 02:30:00", "2024-05-01 12:00:00")
par_as_posixct(x, tz = "Europe/Berlin")
#> [1] "2024-03-31 03:30:00 CEST" "2024-05-01 12:00:00 CEST"
par_as_posixct(x, tz = "Europe/Berlin", format = "%Y-%m-%d %H:%M:%S")
#> [1] "2024-03-31 03:30:00 CEST" "2024-05-01 12:00:00 CEST"
```

Base [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) returns
the same. Besides losing the times, trying the formats took 1.1s for a
million strings, against 0.29s with `format`.

**Tables of doubles.**
[`par_table()`](https://lhdjung.github.io/parvenu/reference/par_factor.md)
and
[`par_factor()`](https://lhdjung.github.io/parvenu/reference/par_factor.md)
turn doubles into their printed values, as base does, which takes
seconds for 10 million of them either way. Integers don’t need that. If
the values are tenths or cents, tabulate them as whole numbers:

``` r

price <- c(1.5, 2.25, 1.5)
par_table(as.integer(round(price * 100)))
#> 
#> 150 225 
#>   2   1
```

For 10 million values, that is 0.45s against 4.1s.

**Sorted values in
[`par_find_interval()`](https://lhdjung.github.io/parvenu/reference/par_find_interval.md).**
Base [`findInterval()`](https://rdrr.io/r/base/findInterval.html) is
already fast when `x` is sorted, since it doesn’t search from scratch
for each value: 25ms for 10 million values into 10,000 breaks, against
28ms here. The gain is for unsorted `x`, 30ms against 0.91s.

**Arguments and classes that go to base R.** Each help page says what
its function leaves to base. The common ones:

- `incomparables` other than `FALSE` in
  [`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md),
  [`par_duplicated()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md),
  and
  [`par_unique()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md)
- classes other than factor, Date, and POSIXct, such as `integer64` or
  `difftime`
- `ties.method = "random"` in
  [`par_rank()`](https://lhdjung.github.io/parvenu/reference/par_rank.md)
- data frames in
  [`par_rowsum()`](https://lhdjung.github.io/parvenu/reference/par_rowsum.md)
- `na.rm = FALSE` in
  [`par_approx()`](https://lhdjung.github.io/parvenu/reference/par_approx.md)
- date formats beyond those
  [`?par_as_date`](https://lhdjung.github.io/parvenu/reference/par_as_date.md)
  lists, and month names in a locale that isn’t English

## Joins on several columns

To match on several key columns, pass them to
[`par_match_rows()`](https://lhdjung.github.io/parvenu/reference/par_match_rows.md)
as they are. Pasting them into one string first costs far more than the
match: for two columns of 10 million rows,
[`paste()`](https://rdrr.io/r/base/paste.html) takes 11s on one thread,
and
[`par_match_rows()`](https://lhdjung.github.io/parvenu/reference/par_match_rows.md)
on the columns themselves 0.07s.

``` r

orders <- data.frame(customer = c(1L, 2L, 1L), year = c(2025, 2025, 2026))
targets <- data.frame(customer = c(1L, 1L, 2L), year = c(2026, 2025, 2026))

par_match_rows(orders, targets)
#> [1]  2 NA  1
```

[`par_match_all()`](https://lhdjung.github.io/parvenu/reference/par_match_all.md)
and
[`par_match_rows_all()`](https://lhdjung.github.io/parvenu/reference/par_match_all.md)
return every pair of equal elements. Their result can be far larger than
the inputs: 100,000 equal keys on each side make 10 billion pairs. More
than 2^31 - 1 pairs are an error, raised before any pair is built.
