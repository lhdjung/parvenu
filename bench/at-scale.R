# Where waiting for base R stops being an option: large dictionaries, tens
# of millions of times, and ranks in every bootstrap resample. Run after
# installing parvenu; base R takes several minutes in all.
library(parvenu)
set.seed(1)
words <- vapply(
  1:2e4,
  function(i) paste(sample(letters, 8, TRUE), collapse = ""),
  ""
)

cat("Largest alternation base R compiles (PCRE), in terms of 8 letters\n")
compiles <- function(k) {
  pattern <- paste(words[1:k], collapse = "|")
  !inherits(
    try(suppressWarnings(regexpr(pattern, "x", perl = TRUE)), silent = TRUE),
    "try-error"
  )
}
lo <- 1000
hi <- 1e4
while (hi - lo > 50) {
  mid <- (lo + hi) %/% 2
  if (compiles(mid)) lo <- mid else hi <- mid
}
cat("about", lo, "\n")

cat("\n1e5 strings, 1e4 terms\n")
n <- 1e5
x <- paste(sample(words, n, TRUE), sample(words, n, TRUE), sample(999, n, TRUE))
terms <- sample(words, 1e4)
base_loop <- function(x, terms) {
  out <- rep(NA_integer_, length(x))
  for (i in rev(seq_along(terms))) {
    out[grepl(terms[i], x, fixed = TRUE)] <- i
  }
  out
}
print(bench::mark(
  base_loop = base_loop(x, terms),
  stringi = stringi::stri_detect_regex(x, paste(terms, collapse = "|")),
  parvenu = par_match_term(x, terms),
  check = FALSE,
  filter_gc = FALSE
)[, c("expression", "median")])

cat("\n1e7 access-log times in a month, at second resolution\n")
start <- as.POSIXct("2026-10-01", tz = "UTC")
x <- format(
  start + sample(31 * 86400, 1e7, TRUE),
  "%d/%b/%Y:%H:%M:%S +0000",
  tz = "UTC"
)
f <- "%d/%b/%Y:%H:%M:%S %z"
# Logs repeat their times, so base R can parse each distinct one only once
base_unique <- function(x) {
  u <- unique(x)
  as.POSIXct(u, format = f, tz = "UTC")[match(x, u)]
}
print(bench::mark(
  base = as.POSIXct(x, format = f, tz = "UTC"),
  base_unique = base_unique(x),
  parvenu = par_as_posixct(x, format = f, tz = "UTC"),
  filter_gc = FALSE
)[, c("expression", "median")])

cat("\n1e7 ISO times with milliseconds, all distinct\n")
x <- format(
  start + sample(31 * 86400 * 1000, 1e7) / 1000,
  "%Y-%m-%d %H:%M:%OS3",
  tz = "UTC"
)
print(bench::mark(
  base = as.POSIXct(x, tz = "UTC"),
  base_format = as.POSIXct(x, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC"),
  parvenu = par_as_posixct(x, tz = "UTC"),
  filter_gc = FALSE
)[, c("expression", "median")])

cat("\nA search box over 1e7 rows: one search per keystroke\n")
n <- 1e7
x <- paste(sample(words, n, TRUE), sample(words, n, TRUE), sample(999, n, TRUE))
q <- words[5]
print(bench::mark(
  base_fixed = grepl(q, x, fixed = TRUE),
  base_ignore_case = grepl(q, x, ignore.case = TRUE, perl = TRUE),
  parvenu_fixed = par_detect(x, q, fixed = TRUE),
  parvenu_ignore_case = par_detect(x, paste0("(?i)", q)),
  min_iterations = 3,
  check = FALSE,
  filter_gc = FALSE
)[, c("expression", "median")])
rm(x)

cat("\nSpearman's correlation in 1000 bootstrap resamples of 2e5 rows\n")
n <- 2e5
a <- round(rnorm(n), 2)
b <- round(a + rnorm(n), 2)
boot <- function(rank) {
  set.seed(2)
  vapply(
    1:1000,
    function(r) {
      i <- sample.int(n, n, TRUE)
      cor(rank(a[i]), rank(b[i]))
    },
    0
  )
}
print(bench::mark(
  base = boot(rank),
  data.table = boot(data.table::frank),
  parvenu = boot(par_rank),
  filter_gc = FALSE
)[, c("expression", "median")])
cat("\n")
print(sessionInfo())
