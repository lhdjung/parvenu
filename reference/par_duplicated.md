# Multithreaded `duplicated()` and `unique()`

- `par_duplicated()` returns the same as base
  [`duplicated()`](https://rdrr.io/r/base/duplicated.html), but much
  faster for large inputs. For a data frame, rows are compared, as in
  base.

- `par_unique()` behaves like base
  [`unique()`](https://rdrr.io/r/base/unique.html) but is much faster
  for large inputs.

- `par_any_duplicated()` behaves like base
  [`anyDuplicated()`](https://rdrr.io/r/base/duplicated.html): it finds
  the position of the first duplicate (or `0` if there is none). It is
  much faster where the first duplicate comes late or not at all.

## Usage

``` r
par_duplicated(
  x,
  incomparables = FALSE,
  fromLast = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_unique(
  x,
  incomparables = FALSE,
  fromLast = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_any_duplicated(
  x,
  incomparables = FALSE,
  fromLast = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x:

  A vector or data frame.

- incomparables:

  Values that are never marked as duplicates, as in base
  [`duplicated()`](https://rdrr.io/r/base/duplicated.html). `FALSE`
  means none; anything else goes to base.

- fromLast:

  If `TRUE`, an element is a duplicate if an equal one comes later,
  rather than earlier.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

- `par_duplicated()`: a logical vector as long as `x` (or with one
  element per row of a data frame): `TRUE` where an equal element (or
  row) comes earlier, or later if `fromLast = TRUE`.

- `par_unique()`: `x` without those elements (or rows), as
  [`unique()`](https://rdrr.io/r/base/unique.html) returns it.

- `par_any_duplicated()`: an integer, the position of the first `TRUE`
  of `par_duplicated()`, the last if `fromLast = TRUE`, or `0L`.

## Details

Computed in Rust when `x` has at least 1e4 elements (or rows) and is an
integer, double, or string vector, a factor, a Date, or a POSIXct, or a
data frame of such columns and logical ones. Anything else goes to base
[`duplicated()`](https://rdrr.io/r/base/duplicated.html) unchanged.

Like
[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md),
this hashes `x` in parallel. It marks the duplicates while it builds the
hash table, so it never looks the elements up a second time, as
`par_match(x, x) != seq_along(x)` would. `par_unique()` collects the
first occurrences instead, so it never subsets `x` either.

Base [`anyDuplicated()`](https://rdrr.io/r/base/duplicated.html) stops
at the first duplicate, so it is quick when one comes early.
`par_any_duplicated()` checks the first 65536 elements (the last, with
`fromLast`) that way. If none is there, it searches the whole vector.

## Examples

``` r
x <- c(3, 1, 3, NA, 1, NA)
par_duplicated(x)
#> [1] FALSE FALSE  TRUE FALSE  TRUE  TRUE
par_duplicated(x, fromLast = TRUE)
#> [1]  TRUE  TRUE FALSE  TRUE FALSE FALSE
par_unique(x)
#> [1]  3  1 NA
length(par_unique(x)) # number of distinct values
#> [1] 3
par_any_duplicated(x)
#> [1] 3

df <- data.frame(id = c(1, 2, 1), day = c("mon", "mon", "mon"))
par_duplicated(df)
#> [1] FALSE FALSE  TRUE
```
