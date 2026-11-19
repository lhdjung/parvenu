# Extract or replace regex matches, in parallel

- `par_extract()` returns the first match in each string, like
  `regmatches(x, regexpr(pattern, x))`, but with `NA` where nothing
  matches.

- `par_extract_all()` returns every match, like
  `regmatches(x, gregexpr(pattern, x))`.

- `par_locate()` finds where the first match is, like
  `regexpr(pattern, x)`.

- `par_locate_all()` finds where every match is, like
  `gregexpr(pattern, x)`.

- `par_replace()` replaces the first match, like
  `sub(pattern, replacement, x)`.

- `par_replace_all()` replaces every match, like
  `gsub(pattern, replacement, x)`.

All use the syntax of Rust's regex crate, as
[`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
does.

## Usage

``` r
par_extract(
  x,
  pattern,
  group = 0L,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_extract_all(
  x,
  pattern,
  group = 0L,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_locate(
  x,
  pattern,
  group = 0L,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_locate_all(
  x,
  pattern,
  group = 0L,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_replace(
  x,
  pattern,
  replacement,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_replace_all(
  x,
  pattern,
  replacement,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x:

  A string vector, or an object convertible by
  [`as.character()`](https://rdrr.io/r/base/character.html).

- pattern:

  The regex, or the literal string to find if `fixed = TRUE`: one
  string, or one per string of `x`, as in
  [`stringi::stri_detect_regex()`](https://rdrr.io/pkg/stringi/man/stri_detect.html).
  Each distinct pattern is compiled once.

- group:

  The capture group to extract: 0 for the whole match, 1 for the first
  group, and so on. `par_extract()` also takes several, such as `0:3`.
  It then returns a matrix with a column per group, from one search.

- fixed:

  If `TRUE`, `pattern` is found as it is, as in `grepl(fixed = TRUE)`:
  no character has a special meaning.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

- replacement:

  The string to put in place of each match. Unless `fixed = TRUE`, `$1`
  stands for the first capture group, `${name}` for a named one, and
  `$$` for a `$`. Write `${1}a`, not `$1a`, which means a group named
  `1a`. R's `\\1` is not a group here.

## Value

- `par_extract()`, `par_replace()`, and `par_replace_all()`: a string
  vector as long as `x`, with the names of `x`, as
  [`regmatches()`](https://rdrr.io/r/base/regmatches.html),
  [`sub()`](https://rdrr.io/r/base/grep.html), and
  [`gsub()`](https://rdrr.io/r/base/grep.html) keep them. `NA` where `x`
  or `pattern` is `NA`. For `par_extract()`, also `NA` where nothing
  matches or the group took no part in the match. With several groups,
  `par_extract()` returns a string matrix instead, with a row per string
  (named as `x` is) and a column per group, as
  [`stringi::stri_match_first_regex()`](https://rdrr.io/pkg/stringi/man/stri_match.html)
  does.

- `par_extract_all()`: a list as long as `x`. Each element is a string
  vector of the matches, `character(0)` if none, or `NA` where `x` or
  `pattern` is `NA`. It finds the matches that
  [`par_count()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
  counts. For a group, it has `NA` where the group took no part in a
  match.

- `par_locate()`: an integer matrix with a row per string and columns
  `start` and `end`, positions of characters, as in
  [`stringi::stri_locate_first_regex()`](https://rdrr.io/pkg/stringi/man/stri_locate.html).
  An empty match has `end` one less than `start`. `NA` where there is no
  match, or the group took no part in it.

- `par_locate_all()`: a list as long as `x`. Each element is such a
  matrix with a row per match, no rows if none, or one row of `NA` where
  `x` or `pattern` is `NA`.

## Details

`par_extract()` can return a capture group instead of the whole match,
which takes the place of lookaround. It can also return several groups
at once, as a matrix.

The threads find the matches and build the replaced strings. Only R's
thread may turn them into R strings, so that part runs serially. Strings
that `par_replace()` and `par_replace_all()` leave unchanged are not
copied.

## Examples

``` r
x <- c("born 1999 in Oslo", "no year", NA)
par_extract(x, "[0-9]{4}")
#> [1] "1999" NA     NA    
par_extract(x, "born ([0-9]+)", group = 1)
#> [1] "1999" NA     NA    
par_extract(x, "born ([0-9]+) in (\\w+)", group = 1:2)
#>      [,1]   [,2]  
#> [1,] "1999" "Oslo"
#> [2,] NA     NA    
#> [3,] NA     NA    
par_extract_all(c("#rstats and #rust", "none", NA), "#(\\w+)", group = 1)
#> [[1]]
#> [1] "rstats" "rust"  
#> 
#> [[2]]
#> character(0)
#> 
#> [[3]]
#> [1] NA
#> 
par_locate(x, "[0-9]{4}")
#>      start end
#> [1,]     6   9
#> [2,]    NA  NA
#> [3,]    NA  NA
par_locate_all(x, "[a-z]+")
#> [[1]]
#>      start end
#> [1,]     1   4
#> [2,]    11  12
#> [3,]    15  17
#> 
#> [[2]]
#>      start end
#> [1,]     1   2
#> [2,]     4   7
#> 
#> [[3]]
#>      start end
#> [1,]    NA  NA
#> 
par_replace(x, "[0-9]", "#")
#> [1] "born #999 in Oslo" "no year"           NA                 
par_replace_all(x, "[0-9]", "#")
#> [1] "born #### in Oslo" "no year"           NA                 
par_replace_all("Smith, John", "(\\w+), (\\w+)", "$2 $1")
#> [1] "John Smith"
```
