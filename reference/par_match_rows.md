# Multithreaded `match()` on rows

Finds, for each row of `x`, the position of the first row of `table`
that is equal to it in every column. This is a join on several key
columns.

## Usage

``` r
par_match_rows(
  x,
  table,
  nomatch = NA_integer_,
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x:

  Rows to look up: a data frame, or a list of vectors of equal length.

- table:

  Rows to look them up in, in the same form, with as many columns as
  `x`.

- nomatch:

  The value returned where there is no match, coerced to integer.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

An integer vector with one element per row of `x`: the first row of
`table` equal to it, or `nomatch` if there is none. Use
`par_match_rows(x, table, nomatch = 0L) > 0L` to find which rows of `x`
are in `table`.

## Details

Columns are paired by position, not by name. Each pair is compared as
[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
compares vectors: `1L` matches `1`, a factor matches by its levels, and
`NA` matches `NA`.

Whole rows are hashed in parallel, so this costs about as much as one
[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
call, however many columns there are. Integer, double, character, Date,
POSIXct, and factor columns are compared in Rust as they are. Other
columns are first turned by
[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
into the positions of first occurrences in `table`.

## Examples

``` r
orders <- data.frame(customer = c(1L, 2L, 1L), year = c(2025, 2025, 2026))
targets <- data.frame(
  customer = c(1L, 1L, 2L),
  year = c(2026, 2025, 2026),
  goal = c(500, 400, 300)
)
i <- par_match_rows(orders, targets[c("customer", "year")])
targets$goal[i]
#> [1] 400  NA 500
```
