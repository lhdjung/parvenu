# Set operations, in parallel

Return the same as base [`union()`](https://rdrr.io/r/base/sets.html),
[`intersect()`](https://rdrr.io/r/base/sets.html), and
[`setdiff()`](https://rdrr.io/r/base/sets.html), but much faster for
large inputs.

## Usage

``` r
par_union(x, y, nthreads = getOption("parvenu.threads", 0L))

par_intersect(x, y, nthreads = getOption("parvenu.threads", 0L))

par_setdiff(x, y, nthreads = getOption("parvenu.threads", 0L))
```

## Arguments

- x, y:

  Vectors, as in [`union()`](https://rdrr.io/r/base/sets.html).

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

A vector without duplicates, as the base functions return it: the
elements of `x` or `y`, of both, or of `x` only.

## Details

The distinct elements come from
[`par_unique()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md)
and the lookups from
[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md).
At 1e7 elements, each takes about a tenth of base's time.

## Examples

``` r
par_union(c(3, 1, 3), c(2, 1))
#> [1] 3 1 2
par_intersect(c(3, 1, 3), c(2, 1))
#> [1] 1
par_setdiff(c(3, 1, 3), c(2, 1))
#> [1] 3
```
