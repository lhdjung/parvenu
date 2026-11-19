# Package index

## Matching and duplicates

Drop-in replacements for base R functions. Inputs that are too small or
have non-standard types fall back to base R.

### Matching

- [`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
  [`` `%par_in%` ``](https://lhdjung.github.io/parvenu/reference/par_match.md)
  [`par_in()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
  :

  Multithreaded [`match()`](https://rdrr.io/r/base/match.html) and
  `%in%`

- [`par_match_rows()`](https://lhdjung.github.io/parvenu/reference/par_match_rows.md)
  :

  Multithreaded [`match()`](https://rdrr.io/r/base/match.html) on rows

- [`par_match_all()`](https://lhdjung.github.io/parvenu/reference/par_match_all.md)
  [`par_match_rows_all()`](https://lhdjung.github.io/parvenu/reference/par_match_all.md)
  : All matches, not just the first

- [`par_find_interval()`](https://lhdjung.github.io/parvenu/reference/par_find_interval.md)
  : Bin values by sorted breaks, in parallel

### Duplicates and sets

- [`par_duplicated()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md)
  [`par_unique()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md)
  [`par_any_duplicated()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md)
  :

  Multithreaded [`duplicated()`](https://rdrr.io/r/base/duplicated.html)
  and [`unique()`](https://rdrr.io/r/base/unique.html)

- [`par_union()`](https://lhdjung.github.io/parvenu/reference/par_union.md)
  [`par_intersect()`](https://lhdjung.github.io/parvenu/reference/par_union.md)
  [`par_setdiff()`](https://lhdjung.github.io/parvenu/reference/par_union.md)
  : Set operations, in parallel

### Factors, dates, ranks, and sums

- [`par_factor()`](https://lhdjung.github.io/parvenu/reference/par_factor.md)
  [`par_table()`](https://lhdjung.github.io/parvenu/reference/par_factor.md)
  : Make a factor, or count values, in parallel
- [`par_as_date()`](https://lhdjung.github.io/parvenu/reference/par_as_date.md)
  [`par_as_posixct()`](https://lhdjung.github.io/parvenu/reference/par_as_date.md)
  : Parse dates and times, in parallel
- [`par_rank()`](https://lhdjung.github.io/parvenu/reference/par_rank.md)
  : Rank values, in parallel
- [`par_rowsum()`](https://lhdjung.github.io/parvenu/reference/par_rowsum.md)
  : Sum by group, in parallel
- [`par_approx()`](https://lhdjung.github.io/parvenu/reference/par_approx.md)
  : Interpolate linearly, in parallel

## String operations

Not exact base R equivalents. Threads read the strings straight from R’s
memory.

### Regular expressions

Rust’s regex syntax, not R’s.

- [`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
  [`par_count()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
  : Detect regex matches, in parallel
- [`par_extract()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
  [`par_extract_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
  [`par_locate()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
  [`par_locate_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
  [`par_replace()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
  [`par_replace_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
  : Extract or replace regex matches, in parallel

### Dictionary lookup

Many literal terms at once, in one pass per string.

- [`par_match_term()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md)
  [`par_count_term()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md)
  [`par_which_term()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md)
  [`par_match_term_all()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md)
  : Find which term each string contains, in parallel
- [`par_replace_term()`](https://lhdjung.github.io/parvenu/reference/par_replace_term.md)
  : Replace dictionary terms, in parallel
