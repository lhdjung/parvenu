# Find which term each string contains, in parallel

For each string in `x`:

- `par_match_term()` finds the index of the first term in `terms` it
  contains. It is like [`match()`](https://rdrr.io/r/base/match.html)
  for substrings.

- `par_count_term()` counts every hit of every term, such as to score
  strings against a lexicon of positive and negative words. With
  `weights`, it sums a score per hit instead.

- `par_which_term()` finds every term the string contains, such as every
  drug an abstract names.

- `par_match_term_all()` returns every pair of a string and a term it
  contains, with the number of hits. This is a document-term matrix in
  long form.

- `par_locate_term_all()` finds where each hit is, such as to highlight
  terms or show them in context.

## Usage

``` r
par_match_term(
  x,
  terms,
  ignore_case = FALSE,
  whole_word = FALSE,
  fixed = TRUE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_count_term(
  x,
  terms,
  ignore_case = FALSE,
  whole_word = FALSE,
  fixed = TRUE,
  weights = NULL,
  nthreads = getOption("parvenu.threads", 0L)
)

par_which_term(
  x,
  terms,
  ignore_case = FALSE,
  whole_word = FALSE,
  fixed = TRUE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_match_term_all(
  x,
  terms,
  ignore_case = FALSE,
  whole_word = FALSE,
  fixed = TRUE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_locate_term_all(
  x,
  terms,
  ignore_case = FALSE,
  whole_word = FALSE,
  fixed = TRUE,
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x:

  A string vector, or an object convertible by
  [`as.character()`](https://rdrr.io/r/base/character.html).

- terms:

  A string vector of literal strings to find. `NA` is not allowed.

- ignore_case:

  If `TRUE`, letters match regardless of case, in any script: `"é"`
  matches `"É"`. ASCII letters cost nothing extra. Strings with other
  characters are lowercased first. With `fixed = FALSE`, this is `(?i)`.

- whole_word:

  If `TRUE`, a term counts only where it isn't part of a longer word.
  `"york"` then matches `"new york"` and `"york, uk"`, but not
  `"yorkshire"`. The characters right before and after the term must not
  be word characters, those `\\w` matches. These are letters, digits,
  and marks (such as an accent written as a character of its own) in any
  script, and `_`. An apostrophe (`'` or the curly `\u2019`) between two
  word characters joins them into one word. So `"won"` doesn't match
  `"won't"`, nor `"heaven"` `"heaven's"`. With `fixed = FALSE`, the same
  goes for a term's match.

  If `"start"`, a term must start a word but may end inside one, as a
  prefix: `"happ"` matches `"happy"` and `"happiness"`, but not
  `"unhappy"`. This is the `"happ*"` of dictionaries such as LIWC.

- fixed:

  If `FALSE`, `terms` are regexes, in the syntax of
  [`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md).

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

- weights:

  For `par_count_term()`: `NULL` to count hits, or a numeric vector as
  long as `terms`, without `NA`. Each hit then adds the weight of its
  term, as for a lexicon that rates words from -5 to 5.

## Value

- `par_match_term()`: an integer vector as long as `x`, with the
  position in `terms` of the first term found in each string. `NA` if
  none is found, or where `x` is `NA`. Use
  `terms[par_match_term(x, terms)]` to get the terms themselves.

- `par_count_term()`: an integer vector as long as `x`, with the number
  of hits in each string, or `NA` where `x` is `NA`. Every occurrence of
  every term counts, also where they overlap. So `"new york"` has two
  hits for `c("new york", "york")`, and a term listed twice counts
  twice. For regexes, each term's matches are counted as
  [`par_count()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
  counts them, which don't overlap. With `weights`, it returns a double
  vector: the sum of the weights of the hits, `0` if none.

- `par_which_term()`: a list as long as `x`. Each element has the
  positions in `terms` of every term found in the string, in increasing
  order and each once. It is `integer(0)` if none, or `NA` where `x` is
  `NA`.

- `par_match_term_all()`: a data frame with one row per pair, sorted by
  `x` and then by `term`. Column `x` is a position in `x`, `term` is a
  position in `terms` found there, and `n` is the number of its hits, as
  `par_count_term()` counts them. Strings with no term, and `NA`, have
  no rows.

- `par_locate_term_all()`: a data frame with one row per hit, the hits
  that `par_count_term()` counts, sorted by `x`, then by `start`, then
  by `term`. Columns `x` and `term` are as above. `start` and `end` are
  the positions of the first and last characters of the hit, as in
  [`par_locate()`](https://lhdjung.github.io/parvenu/reference/par_extract.md).
  An empty term's hit has `end` one less than `start`. Strings with no
  term, and `NA`, have no rows.

## Details

Terms are literal, as in `grepl(fixed = TRUE)`, so no character needs
escaping. With `fixed = FALSE`, they are regular expressions.

Order sets priority. If a string contains several terms, the one
earliest in `terms` wins, wherever it occurs in the string. Put specific
terms before general ones, such as `"new york"` before `"york"`.

All terms are compiled into one Aho-Corasick automaton. It finds every
occurrence of every term in a single pass over each string, however many
terms there are. The last automaton is kept, so calls that repeat the
same `terms` don't build it again. The threads read the strings straight
from R's memory, as data.table does.

With `fixed = FALSE`, the terms are compiled into one regex set instead.
It also finds in one pass which terms match a string. That is much
slower than the automaton, but much faster than a regex per term.

## Examples

``` r
cities <- c("new york", "york", "paris")

par_match_term(c("york and new york", "paris, texas", "rome", NA), cities)
#> [1]  1  3 NA NA

par_match_term("NEW YORK", cities, ignore_case = TRUE)
#> [1] 1

par_match_term(c("yorkshire", "york, uk"), cities, whole_word = TRUE)
#> [1] NA  2

par_match_term("1+1=2", c("+", "("))
#> [1] 1

par_count_term("good food, not bad", c("good", "bad"), whole_word = TRUE)
#> [1] 2

par_count_term("happy, unhappy, happiness", "happ", whole_word = "start")
#> [1] 2

par_count_term("good food, not bad", c("good", "bad"), weights = c(1, -2))
#> [1] -1

par_which_term(c("york and new york", "rome", NA), cities)
#> [[1]]
#> [1] 1 2
#> 
#> [[2]]
#> integer(0)
#> 
#> [[3]]
#> [1] NA
#> 

par_match_term_all(c("york and new york", "rome", NA), cities)
#>   x term n
#> 1 1    1 1
#> 2 1    2 2

par_locate_term_all(c("york and new york", "rome", NA), cities)
#>   x term start end
#> 1 1    2     1   4
#> 2 1    1    10  17
#> 3 1    2    14  17

par_match_term(c("call 555-1234", "mail a@b.org"), c("\\d{3}-\\d{4}", "@"), fixed = FALSE)
#> [1] 1 2
```
