# Make a factor, or count values, in parallel

Drop-in replacements for base functions, faster for large inputs:

- `par_factor()` for [`factor()`](https://rdrr.io/r/base/factor.html).

- `par_table()` for [`table()`](https://rdrr.io/r/base/table.html).

They take base's arguments and give identical results. The only
differences: both take `nthreads`, and `par_factor()` ignores `nmax`.

## Usage

``` r
par_factor(
  x = character(),
  levels,
  labels = levels,
  exclude = NA,
  ordered = is.ordered(x),
  nmax = NA,
  nthreads = getOption("parvenu.threads", 0L)
)

par_table(
  ...,
  exclude = if (useNA == "no") c(NA, NaN),
  useNA = c("no", "ifany", "always"),
  dnn = list_names(...),
  deparse.level = 1,
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x:

  A vector, as in
  [`base::factor()`](https://rdrr.io/r/base/factor.html).

- levels:

  an optional vector of the unique values (as character strings) that
  `x` might have taken. The default is the unique set of values taken by
  [`as.character`](https://rdrr.io/r/base/character.html)`(x)`, sorted
  into increasing order *of `x`*. Note that this set can be specified as
  smaller than `sort(unique(x))`.

- labels:

  *either* an optional character vector of labels for the levels (in the
  same order as `levels` after removing those in `exclude`), *or* a
  character string of length 1. Duplicated values in `labels` can be
  used to map different values of `x` to the same factor level.

- exclude:

  a vector of values to be excluded when forming the set of levels. This
  may be factor with the same level set as `x` or should be a
  `character`.

- ordered:

  logical flag to determine if the levels should be regarded as ordered
  (in the order given).

- nmax:

  Ignored. It is a hint for base's hash table, kept so that the
  arguments are in base's order.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

- ...:

  Vectors or factors of the same length, or a single list of them, such
  as a data frame, as in
  [`base::table()`](https://rdrr.io/r/base/table.html).

- useNA:

  whether to include `NA` values in the table. See ‘Details’. Can be
  abbreviated.

- dnn:

  the names to be given to the dimensions in the result (the *dimnames
  names*).

- deparse.level:

  controls how the default `dnn` is constructed. See ‘Details’.

## Value

As base: a factor from `par_factor()`, a `table` from `par_table()`.

## Details

Both spend most of their time finding the distinct values and the
position of each element among them. Here,
[`par_unique()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md)
and
[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
do that on several threads, and `par_table()` counts the cells on
several threads too. Sorting the levels stays with base R.

[`factor()`](https://rdrr.io/r/base/factor.html) of 1e7 strings in 1e5
levels takes about 0.8s in base R and 0.5s here, most of it sorting the
levels. For 1e7 integers in 1e6 levels, 0.85s becomes 0.3s, most of it
making the levels' strings.
[`table()`](https://rdrr.io/r/base/table.html) of 1e7 integers in 1e4
levels takes about 0.25s in base and 20ms here; of a factor with 100
levels, 80ms and 5ms.

A double vector is tabulated by its printed values, as in base. That
takes seconds for 1e7 of them either way.

## Examples

``` r
par_factor(c("b", "a", "b"))
#> [1] b a b
#> Levels: a b
par_factor(c(3, 1, 3), labels = c("low", "high"))
#> [1] high low  high
#> Levels: low high
par_table(c("b", "a", "b", NA), useNA = "ifany")
#> 
#>    a    b <NA> 
#>    1    2    1 
par_table(c(1, 2, 1), c("x", "x", "y"))
#>    
#>     x y
#>   1 1 1
#>   2 1 0
```
