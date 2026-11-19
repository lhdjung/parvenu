# Detect regex matches, in parallel

- `par_detect()` is like `grepl(pattern, x)`.

- `par_count()` counts the matches in each string, as many as
  [`gregexpr()`](https://rdrr.io/r/base/grep.html) would find, but
  without building them.

Both run on several threads. They use the syntax of Rust's
[regex](https://docs.rs/regex/latest/regex/#syntax) crate instead of
R's. Most patterns mean the same in both. See Details for the
differences.

## Usage

``` r
par_detect(
  x,
  pattern,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
)

par_count(
  x,
  pattern,
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

- fixed:

  If `TRUE`, `pattern` is found as it is, as in `grepl(fixed = TRUE)`:
  no character has a special meaning.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

A vector as long as `x`, `NA` where `x` or `pattern` is `NA`:

- `par_detect()`: logical, `TRUE` where `pattern` matches and `FALSE`
  where it doesn't.

- `par_count()`: integer, the number of non-overlapping matches.

## Details

The syntax differs from R's in these ways:

- No backreferences (`\\1`) or lookaround (`(?=...)`). In return, time
  grows only linearly with the length of the string. Engines that
  backtrack, such as PCRE (`grepl(perl = TRUE)`), try every way a
  pattern can split the string. That can take exponentially long:
  `^(a+)+$` against 25 `a`s and a `!` exceeds PCRE's match limit.

- Unicode by default: `\\d`, `\\w`, and `\\s` match any Unicode digit,
  word, or space character. Write `[0-9]` or `(?-u:\\d)` for ASCII only.

- Flags go in the pattern: `(?i)` ignores case.

- `NA` returns `NA`, where [`grepl()`](https://rdrr.io/r/base/grep.html)
  returns `FALSE`.

The counts of `par_count()` differ from
[`gregexpr()`](https://rdrr.io/r/base/grep.html) only for patterns that
can match the empty string, such as `""`, `"a*"`, or `"\\b"`. The two
engines treat empty matches in opposite ways:

- At the end of a string, `par_count()` counts an empty match and
  [`gregexpr()`](https://rdrr.io/r/base/grep.html) doesn't (unless the
  string itself is empty). So `""` has 4 matches in `"abc"`, where
  [`gregexpr()`](https://rdrr.io/r/base/grep.html) finds 3.

- Right after a non-empty match,
  [`gregexpr()`](https://rdrr.io/r/base/grep.html) counts an empty match
  and `par_count()` doesn't. So `"a*"` has 4 matches in `"banana"`: an
  empty one before the `"b"`, and the three `"a"`s.
  [`gregexpr()`](https://rdrr.io/r/base/grep.html) also finds an empty
  one after each of the first two `"a"`s, so 6.

The threads read the strings straight from R's memory, as data.table
does.

## Examples

``` r
par_detect(c("apple", "banana", NA), "an+a", nthreads = 2)
#> [1] FALSE  TRUE    NA
par_detect("ABC", "(?i)b")
#> [1] TRUE
par_detect(c("a.c", "abc"), ".", fixed = TRUE)
#> [1]  TRUE FALSE
par_detect(c("apple", "banana", "cherry"), c("^a", "an", "z")) # one each
#> [1]  TRUE  TRUE FALSE
par_count(c("banana", "kiwi", NA), "an")
#> [1]  2  0 NA
```
