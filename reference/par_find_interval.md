# Bin values by sorted breaks, in parallel

Returns the same as base
[`findInterval()`](https://rdrr.io/r/base/findInterval.html), but much
faster for large, unsorted `x`. For each value, it finds the number of
the interval it falls into: how many of the sorted breaks in `vec` are
at or below it.

Use it to put ages into age groups, timestamps into shifts, or prices
into tax brackets. The result can index a vector of labels.

## Usage

``` r
par_find_interval(
  x,
  vec,
  rightmost.closed = FALSE,
  all.inside = FALSE,
  left.open = FALSE,
  checkSorted = TRUE,
  checkNA = TRUE,
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x:

  numeric.

- vec:

  numeric, sorted (weakly) increasingly, of length `N`, say.

- rightmost.closed:

  logical; if true, the rightmost interval, `vec[N-1] .. vec[N]` is
  treated as *closed*, see below.

- all.inside:

  logical; if true, the returned indices are coerced into `1,...,N-1`,
  i.e., `0` is mapped to `1` and `N` to `N-1`.

- left.open:

  logical; if true all the intervals are open at left and closed at
  right; in the formulas below, \\\le\\ should be swapped with \\\<\\
  (and \\\>\\ with \\\ge\\), and `rightmost.closed` means ‘leftmost is
  closed’. This may be useful, e.g., in survival analysis computations.

- checkSorted:

  logical indicating if `vec` should be checked, i.e.,
  [`is.unsorted`](https://rdrr.io/r/base/is.unsorted.html)`(vec)` is
  asserted to be false. Setting this to `FALSE` skips the check gaining
  speed, but may return nonsense results in case `vec` is not sorted.

- checkNA:

  logical indicating if each `x[i]` should be checked as with
  [`is.na`](https://rdrr.io/r/base/NA.html)`(.)`. Setting this to
  `FALSE` in case of `NA`'s in `x[]` may result in platform dependent
  nonsense.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

An integer vector as long as `x`, as in
[`findInterval()`](https://rdrr.io/r/base/findInterval.html): for each
element, the number of breaks in `vec` at or below it, adjusted by
`rightmost.closed`, `all.inside`, and `left.open`. `NA` where `x` is
`NA`.

## Details

This is `cut(x, vec, right = FALSE, labels = FALSE)`, except at the
ends. Values below the first break return `0`, and values at or above
the last return `length(vec)`.
[`cut()`](https://rdrr.io/r/base/cut.html) returns `NA` for both.

Computed in Rust for integer and double `x` and `vec` (including Dates
and POSIXct) when `x` has at least 1e4 elements. Each element gets a
binary search in `vec`, on several threads. Anything else goes to base
[`findInterval()`](https://rdrr.io/r/base/findInterval.html), which also
raises its errors. This includes a `vec` that is unsorted or contains
`NA`. Base is already fast for sorted `x`, where it doesn't need to
search from scratch.

`checkSorted` and `checkNA` are passed to base from R 4.5.0, which added
them. Rust always checks.

## Examples

``` r
age <- c(4, 17, 18, 45, 67, NA)
groups <- c("child", "adult", "senior")
groups[par_find_interval(age, vec = c(0, 18, 65))]
#> [1] "child"  "child"  "adult"  "adult"  "senior" NA      

par_find_interval(c(1.5, 3.2, 0, 4), vec = 1:4, nthreads = 2)
#> [1] 1 3 0 4
par_find_interval(c(1.5, 3.2, 0, 4), vec = 1:4, rightmost.closed = TRUE)
#> [1] 1 3 0 3
```
