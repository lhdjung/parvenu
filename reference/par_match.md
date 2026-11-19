# Multithreaded `match()` and `%in%`

Same results as [`base::match()`](https://rdrr.io/r/base/match.html) and
`%in%`, but much faster for large inputs. Use as drop-in replacements:

- `par_match()` for [`match()`](https://rdrr.io/r/base/match.html).

- `%par_in%` for `%in%`.

Also, `par_in()` is `%par_in%` as a regular function. It combines better
with the pipe and takes an `nthreads` argument, so you can fine-tune its
performance.

## Usage

``` r
par_match(
  x,
  table,
  nomatch = NA_integer_,
  incomparables = NULL,
  nthreads = getOption("parvenu.threads", 0L)
)

x %par_in% table

par_in(x, table, nthreads = getOption("parvenu.threads", 0L))
```

## Arguments

- x:

  Values to look up.

- table:

  Values to look them up in.

- nomatch:

  The value returned where there is no match, coerced to integer.

- incomparables:

  Values that cannot be matched, as in
  [`base::match()`](https://rdrr.io/r/base/match.html). `NULL` or
  `FALSE` means none. Note that using this argument makes the function
  fall back to base R, so it gets no speedup.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

Just like base [`match()`](https://rdrr.io/r/base/match.html) and
`%in%`:

- `par_match()` returns an integer vector containing the first positions
  of the elements of `x` in `table`, or `nomatch` if an element is not
  in `table`.

- `%par_in%` and `par_in()` return a logical vector: `TRUE` if an
  element of `x` is in `table`, and `FALSE` if not. They never return
  `NA`: an `NA` in `x` is `TRUE` if `table` contains `NA`, and `FALSE`
  if not.

## Details

Speedups result from a Rust implementation using
[rayon](https://docs.rs/rayon/latest/rayon/). To use `%par_in%` within
your package, run this once:

    usethis::use_import_from("parvenu", "%par_in%")

These functions are computed in parallel when `x` or `table` has at
least 1e4 elements and both sides are integer, double (in any mix),
character, Date, or POSIXct. Factors are matched by their levels.
Anything else goes to
[`base::match()`](https://rdrr.io/r/base/match.html) unchanged. Strings
are matched by their pointers, which the threads read straight from R's
memory, as data.table does.

`incomparables` has some quirks and is rarely used, so it gets no Rust
implementation: if it is anything other than `NULL` or `FALSE`, the call
goes to [`base::match()`](https://rdrr.io/r/base/match.html).

## Examples

``` r
par_match(c(3, 1, 9), 1:5, nthreads = 2)
#> [1]  3  1 NA
c("b", "z") %par_in% letters
#> [1] TRUE TRUE
par_in(c("b", "z"), letters, nthreads = 2)
#> [1] TRUE TRUE
```
