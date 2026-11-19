# Rank values, in parallel

Returns the same as base [`rank()`](https://rdrr.io/r/base/rank.html),
but sorts the values on several threads. Base
[`rank()`](https://rdrr.io/r/base/rank.html) is slow where values tie:
it takes seconds for a million doubles.

## Usage

``` r
par_rank(
  x,
  na.last = TRUE,
  ties.method = c("average", "first", "last", "random", "max", "min"),
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x:

  a numeric, complex, character or logical vector.

- na.last:

  a logical or character string controlling the treatment of
  [`NA`](https://rdrr.io/r/base/NA.html)s. If `TRUE`, missing values in
  the data are put last; if `FALSE`, they are put first; if `NA`, they
  are removed; if `"keep"` they are kept with rank `NA`.

- ties.method:

  a character string specifying how ties are treated, see ‘Details’; can
  be abbreviated.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

As [`rank()`](https://rdrr.io/r/base/rank.html): the ranks, a double
vector for `"average"` and an integer one otherwise, with the names of
`x`.

## Details

Computed in Rust for integer and double vectors and factors of at least
1e4 elements. Anything else goes to base R. So does
`ties.method = "random"`, which draws random numbers.

## Examples

``` r
x <- c(b = 3, a = 1, c = 3, d = NA)
par_rank(x)
#>   b   a   c   d 
#> 2.5 1.0 2.5 4.0 
par_rank(x, ties.method = "min", na.last = "keep")
#>  b  a  c  d 
#>  2  1  2 NA 
```
