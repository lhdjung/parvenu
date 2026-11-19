# All matches, not just the first

[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
and
[`par_match_rows()`](https://lhdjung.github.io/parvenu/reference/par_match_rows.md)
find the first match of each element or row of `x` in `table`. These
find all of them, as pairs of positions. This is a many-to-many join,
such as [`merge()`](https://rdrr.io/r/base/merge.html) does on key
columns.

- `par_match_all()` compares vectors as
  [`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
  does.

- `par_match_rows_all()` compares rows as
  [`par_match_rows()`](https://lhdjung.github.io/parvenu/reference/par_match_rows.md)
  does.

## Usage

``` r
par_match_all(x, table, nthreads = getOption("parvenu.threads", 0L))

par_match_rows_all(x, table, nthreads = getOption("parvenu.threads", 0L))
```

## Arguments

- x:

  Rows to look up: a data frame, or a list of vectors of equal length.

- table:

  Rows to look them up in, in the same form, with as many columns as
  `x`.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

A data frame with one row per pair, sorted by `x` and then by `table`.
Column `x` is a position (or row) in `x`, and column `table` is a
position in `table` equal to it. Elements of `x` with no match in
`table` have no rows.

## Details

With `x` and `table` the same, the pairs are all groups of equal
elements, including each element paired with itself.

The number of pairs can be much larger than either input: 1e5 equal
elements on each side make 1e10. It is counted before any pair is built.
More than 2^31 - 1 pairs are an error.

The table is hashed once. As each element goes into the map, it is
numbered by its group, the first equal element. Each element of `x` is
then looked up, and the positions in `table` are sorted by group with a
counting sort. The pairs are written on several threads. So the work
beyond the hashing is linear in the number of pairs.

## Examples

``` r
par_match_all(c("b", "a", "z"), c("a", "b", "a"))
#>   x table
#> 1 1     2
#> 2 2     1
#> 3 2     3

# Groups of equal rows, each pair once
keys <- data.frame(x = c(1, 2, 1, 1), y = c("a", "b", "a", "a"))
pairs <- par_match_rows_all(keys, keys)
pairs[pairs$x < pairs$table, ]
#>   x table
#> 2 1     3
#> 3 1     4
#> 7 3     4
```
