# Replace dictionary terms, in parallel

Replaces every term of `terms` in each string with its replacement, such
as to normalize spellings, expand abbreviations, or redact names. It
does what a `gsub(fixed = TRUE)` per term would, but in one pass,
however many terms there are.

## Usage

``` r
par_replace_term(
  x,
  terms,
  replacement,
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

  A string vector of literal strings to find. `NA` is not allowed, nor
  `""` unless `fixed = FALSE`.

- replacement:

  A string vector as long as `terms`, the replacement for each, or one
  string for all of them. With `fixed = FALSE`, `$1` stands for the
  first capture group of the term's match, as in
  [`par_replace_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md).

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

## Value

A string vector as long as `x`, `NA` where `x` is `NA`. It keeps the
names of `x`, as [`gsub()`](https://rdrr.io/r/base/grep.html) does.

## Details

Since it is one pass, a replacement is never searched again for the
terms after it.

Hits don't overlap. The leftmost hit is replaced first, and the search
goes on after it. If several terms start at the same place, the one
earliest in `terms` wins. So put longer terms before their prefixes,
such as `"new york"` before `"new"`. A regex term that can match the
empty string, such as `"x*"`, has an empty hit at each place without
another hit, but not right where a longer hit ended, as in
[`par_replace_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md).

## Examples

``` r
par_replace_term(
  c("NYC and LA", "la la land"),
  c("NYC", "LA"),
  c("New York City", "Los Angeles"),
  whole_word = TRUE
)
#> [1] "New York City and Los Angeles" "la la land"                   

# Redaction
par_replace_term("Ann met Bob", c("ann", "bob"), "[name]", ignore_case = TRUE)
#> [1] "[name] met [name]"

# Longer terms first
par_replace_term("new york, new jersey", c("new york", "new"), c("NY", "N."))
#> [1] "NY, N. jersey"
```
