# parvenu against stringfish and ahocorasick; run after installing parvenu.
# stringfish runs PCRE2 on as many threads as `nthreads`. Its functions that
# return strings return them lazily, so materialize() is timed with them.
# ahocorasick wraps the same aho-corasick crate as parvenu, on one thread.
# Its automaton is built once outside the timing; parvenu keeps the automaton
# of the last `terms` it saw, so repeated calls skip the build too.
# The `_1` rows run on one thread, to separate gains from threads from the
# rest: on one thread, both run the same search, but ahocorasick copies each
# string into Rust first, which costs more than the search on short strings.
library(parvenu)
library(stringfish)
library(ahocorasick)
set.seed(1)
word <- function(n) {
  vapply(
    seq_len(n),
    function(i) paste(sample(letters, 8, TRUE), collapse = ""),
    ""
  )
}
vocabulary <- word(1e4)
n <- 1e6
x <- paste(
  sample(vocabulary, n, TRUE),
  sample(vocabulary, n, TRUE),
  sample(999, n, TRUE)
)
X <- toupper(x)
threads <- parallel::detectCores()
b <- function(...) {
  print(bench::mark(..., min_iterations = 3, filter_gc = FALSE)[,
    c("expression", "median")
  ])
}

cat("ahocorasick: 1000 terms in 1e6 strings\n")
terms <- sample(vocabulary, 1000)
pattern <- paste(terms, collapse = "|")
ac <- ac_build(terms)
ac_first <- ac_build(terms, match_kind = "leftmost_first")
ac_nocase <- ac_build(terms, ascii_case_insensitive = TRUE)
cat(
  "ac_build():",
  format(bench::mark(ac_build(terms))$median),
  " first par_count_term() with new terms:",
  system.time(par_count_term(x, sample(terms)))[["elapsed"]],
  "s\n"
)

cat("\nDoes each string contain a term?\n")
stopifnot(identical(ac_detect(ac, x), par_detect(x, pattern)))
b(
  ahocorasick = ac_detect(ac, x),
  par_detect = par_detect(x, pattern),
  par_match_term = !is.na(par_match_term(x, terms))
)

cat("\nHits per string, overlapping\n")
stopifnot(identical(
  ac_count(ac, x, overlapping = TRUE),
  par_count_term(x, terms)
))
b(
  ahocorasick = ac_count(ac, x, overlapping = TRUE),
  parvenu_1 = par_count_term(x, terms, nthreads = 1),
  parvenu_2 = par_count_term(x, terms, nthreads = 2),
  parvenu_all = par_count_term(x, terms)
)

cat("\nSame, 1e4 strings of ~2200 bytes: the same text in longer strings\n")
xl <- vapply(split(x, rep(1:1e4, each = 100)), paste, "", collapse = " ")
xl <- unname(xl)
stopifnot(identical(
  ac_count(ac, xl, overlapping = TRUE),
  par_count_term(xl, terms)
))
b(
  ahocorasick = ac_count(ac, xl, overlapping = TRUE),
  parvenu_1 = par_count_term(xl, terms, nthreads = 1),
  parvenu_all = par_count_term(xl, terms)
)

cat("\nSame, uppercased, ignoring case\n")
stopifnot(identical(
  ac_count(ac_nocase, X, overlapping = TRUE),
  par_count_term(X, terms, ignore_case = TRUE)
))
b(
  ahocorasick = ac_count(ac_nocase, X, overlapping = TRUE),
  parvenu_all = par_count_term(X, terms, ignore_case = TRUE)
)

cat("\nReplace every term, earliest term first\n")
replacement <- toupper(terms)
stopifnot(identical(
  ac_replace(ac_first, x, replacement),
  par_replace_term(x, terms, replacement)
))
b(
  ahocorasick = ac_replace(ac_first, x, replacement),
  parvenu_1 = par_replace_term(x, terms, replacement, nthreads = 1),
  parvenu_2 = par_replace_term(x, terms, replacement, nthreads = 2),
  parvenu_all = par_replace_term(x, terms, replacement)
)

cat("\nEvery term in each string: ahocorasick gives every hit's position\n")
b(
  ahocorasick_locate_df = ac_locate_df(ac, x, overlapping = TRUE),
  par_which_term = par_which_term(x, terms),
  par_match_term_all = par_match_term_all(x, terms),
  check = FALSE
)

cat("\n10,000 terms, hits per string\n")
terms4 <- vocabulary
ac4 <- ac_build(terms4)
b(
  ahocorasick = ac_count(ac4, x, overlapping = TRUE),
  parvenu_1 = par_count_term(x, terms4, nthreads = 1),
  parvenu_all = par_count_term(x, terms4)
)

cat("\nstringfish: regexes in 1e6 strings,", threads, "threads\n")
for (pat in c("[aeiou]{3}[0-9]", "^q.*z\\s")) {
  cat("\nDetect", pat, "\n")
  stopifnot(identical(sf_grepl(x, pat), par_detect(x, pat)))
  b(
    stringfish_1 = sf_grepl(x, pat),
    stringfish_all = sf_grepl(x, pat, nthreads = threads),
    parvenu_1 = par_detect(x, pat, nthreads = 1),
    parvenu_all = par_detect(x, pat)
  )
}
cat("\nDetect a fixed string\n")
b(
  stringfish_all = sf_grepl(x, "abc", fixed = TRUE, nthreads = threads),
  parvenu_all = par_detect(x, "abc", fixed = TRUE)
)
cat("\nDetect an alternation of 1000 terms, 1e5 strings\n")
x5 <- x[1:1e5]
b(
  stringfish_all = sf_grepl(x5, pattern, nthreads = threads),
  parvenu_all = par_detect(x5, pattern)
)
for (pat in c("[aeiou]{3}", "[0-9]")) {
  cat("\nReplace every match of", pat, "\n")
  b(
    stringfish_1 = materialize(sf_gsub(x, pat, "_")),
    stringfish_all = materialize(sf_gsub(x, pat, "_", nthreads = threads)),
    parvenu_1 = par_replace_all(x, pat, "_", nthreads = 1),
    parvenu_all = par_replace_all(x, pat, "_")
  )
}

cat("\nstringfish: match 1e7 strings against 1e6 keys\n")
keys <- unique(paste(sample(vocabulary, 1.1e6, TRUE), sample(999, 1.1e6, TRUE)))
keys <- keys[1:1e6]
y <- sample(c(keys, word(1e5)), 1e7, TRUE)
stopifnot(identical(sf_match(y, keys), par_match(y, keys)))
b(
  base = match(y, keys),
  stringfish_1 = sf_match(y, keys),
  stringfish_all = sf_match(y, keys, nthreads = threads),
  parvenu_1 = par_match(y, keys, nthreads = 1),
  parvenu_all = par_match(y, keys)
)
cat("\n")
print(sessionInfo())
