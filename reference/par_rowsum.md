# Sum by group, in parallel

Returns the same as base
[`rowsum()`](https://rdrr.io/r/base/rowsum.html): the sum of `x` within
each group, or of each column of a matrix. Base R takes about a second
for 10 million values.

## Usage

``` r
par_rowsum(
  x,
  group,
  reorder = TRUE,
  na.rm = FALSE,
  ...,
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x:

  a matrix, data frame or vector of numeric data. Missing values are
  allowed. A numeric vector will be treated as a column vector.

- group:

  a vector or factor giving the grouping, with one element per row of
  `x`. Missing values will be treated as another group and a warning
  will be given.

- reorder:

  if `TRUE`, then the result will be in order of `sort(unique(group))`,
  if `FALSE`, it will be in the order that groups were encountered.

- na.rm:

  logical (`TRUE` or `FALSE`). Should `NA` (including `NaN`) values be
  discarded?

- ...:

  other arguments to be passed to or from methods.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

As [`rowsum()`](https://rdrr.io/r/base/rowsum.html): a matrix with a row
per group, named by the groups and sorted unless `reorder = FALSE`. It
has a column per column of `x`.

## Details

Computed in Rust for integer and double vectors and matrices with at
least 1e4 rows. Anything else, such as a data frame, goes to base R.

Each group's values are summed in their order, as in base R, so the sums
agree to the last bit. Integer sums that overflow return `NA`, as in
base.

## Examples

``` r
par_rowsum(c(1, 2, 3, 4), c("b", "a", "b", "a"))
#>   [,1]
#> a    6
#> b    4
par_rowsum(matrix(1:6, 3, dimnames = list(NULL, c("p", "q"))), c(2, 1, 2))
#>   p  q
#> 1 2  5
#> 2 4 10
```
