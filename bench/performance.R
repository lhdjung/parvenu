# The timings in the article "Performance: fast paths and slow paths"; run
# after installing parvenu.
library(parvenu)
set.seed(1)
b <- function(..., n = 3) {
  print(bench::mark(
    ...,
    min_iterations = n,
    max_iterations = max(n, 20),
    check = FALSE,
    memory = FALSE, # needed for the forked workers
    filter_gc = FALSE
  )[, c("expression", "median")])
}
word <- function(n) {
  vapply(seq_len(n), \(i) paste(sample(letters, 8, TRUE), collapse = ""), "")
}

cat("\nFactor against character: 1e7 elements, table of 1e7 strings\n")
table <- paste0("k", sample(1e7))
for (levels in c(100, 1e5)) {
  chr <- sample(sample(table, levels), 1e7, TRUE)
  fct <- factor(chr)
  cat("\n", levels, "distinct values\n")
  b(
    match_chr = par_match(chr, table),
    match_fct = par_match(fct, table),
    match_fct_base = match(fct, table),
    detect_chr = par_detect(chr, "7$"),
    detect_fct = par_detect(fct, "7$"),
    par_factor = par_factor(chr)
  )
}
rm(table, chr, fct)

cat("\nWhat a function returns: one regex in 1e5 strings\n")
vocabulary <- word(1e4)
x <- vapply(
  seq_len(1e5),
  \(i) paste(sample(vocabulary, 12, TRUE), collapse = " "),
  ""
)
b(
  detect = par_detect(x, "qu[a-z]+"),
  count = par_count(x, "qu[a-z]+"),
  locate = par_locate(x, "qu[a-z]+"),
  extract = par_extract(x, "qu[a-z]+"),
  extract_all = par_extract_all(x, "qu[a-z]+"),
  replace_all = par_replace_all(x, "qu[a-z]+", "#")
)

cat("\n1000 terms in 1e5 strings\n")
terms <- sample(vocabulary, 1000)
alternation <- paste(terms, collapse = "|")
b(
  detect_alternation = par_detect(x, alternation),
  match_term = par_match_term(x, terms),
  match_term_ignore_case = par_match_term(x, terms, ignore_case = TRUE)
)
b(detect_alternation_i = par_detect(x, paste0("(?i)", alternation)), n = 1)

cat("\n1e4 terms in 100 strings: the first call builds the automaton\n")
terms <- sample(vocabulary)
first <- system.time(par_match_term(x[1:100], terms))[["elapsed"]]
cat("first call:", round(first * 1000, 1), "ms\n")
b(repeated = par_match_term(x[1:100], terms))

cat("\nSmall inputs: match(a, a) on a permutation\n")
for (n in c(1e3, 1e4, 1e5)) {
  a <- sample(n)
  cat("\n", n, "elements\n")
  b(base = match(a, a), parvenu = par_match(a, a), n = 20)
}

cat("\nMixed encodings: 1e6 strings in 5e5\n")
utf8 <- sample(c(word(1000), "café"), 1e6, TRUE)
mixed <- utf8
mixed[1] <- iconv("café", "UTF-8", "latin1")
b(
  all_utf8 = par_match(utf8, utf8[1:5e5]),
  one_latin1 = par_match(mixed, mixed[1:5e5]),
  one_latin1_enc2utf8 = par_match(enc2utf8(mixed), enc2utf8(mixed[1:5e5])),
  base = match(utf8, utf8[1:5e5])
)

cat("\n1e6 times over 54 years, as UTC and as local times in Berlin\n")
instants <- runif(1e6, 0, 1.7e9)
f <- "%Y-%m-%d %H:%M:%S"
utc <- format(.POSIXct(instants, "UTC"), f)
berlin <- format(.POSIXct(instants, "Europe/Berlin"), f)
b(
  utc = par_as_posixct(utc, "UTC"),
  berlin = par_as_posixct(berlin, "Europe/Berlin")
)
b(
  base_utc = as.POSIXct(utc, "UTC"),
  base_berlin = as.POSIXct(berlin, "Europe/Berlin"),
  n = 1
)
# A time that the clock skipped fits no format but the date alone, as in base.
skipped <- c("2024-03-31 02:30:00", berlin)
b(
  berlin_skipped = par_as_posixct(skipped, "Europe/Berlin"),
  berlin_skipped_format = par_as_posixct(skipped, "Europe/Berlin", format = f)
)
print(par_as_posixct(skipped, "Europe/Berlin")[1:2])
print(par_as_posixct(skipped, "Europe/Berlin", format = f)[1:2])

cat("\nTables of 1e7 values with one decimal\n")
dbl <- round(runif(1e7, 0, 100), 1)
int <- as.integer(round(dbl * 10))
b(
  par_table_dbl = par_table(dbl),
  table_dbl = table(dbl),
  n = 1
)
b(par_table_int = par_table(int), table_int = table(int))

cat("\nfindInterval: 1e7 values into 1e4 breaks\n")
v <- runif(1e7)
sorted <- sort(v)
breaks <- sort(runif(1e4))
b(
  base_unsorted = findInterval(v, breaks),
  parvenu_unsorted = par_find_interval(v, breaks),
  base_sorted = findInterval(sorted, breaks),
  parvenu_sorted = par_find_interval(sorted, breaks)
)

cat("\nTwo key columns: 1e7 rows in 1e6\n")
k1 <- sample(1e5L, 1e7, TRUE)
k2 <- sample(2000:2025 + 0, 1e7, TRUE)
i <- seq_len(1e6)
b(match_rows = par_match_rows(list(k1, k2), list(k1[i], k2[i])))
b(paste_keys = paste(k1, k2, sep = "\r"), n = 1)

cat("\nOne call against 8 forked workers: a regex in 4e5 strings\n")
big <- rep(x, 4)
parts <- split(big, rep(1:8, length.out = length(big)))
pattern <- "[aeiou]{2}[a-z]+"
b(
  one_call = par_count(big, pattern),
  workers = parallel::mclapply(parts, par_count, pattern, mc.cores = 8),
  workers_1_thread = parallel::mclapply(
    parts,
    par_count,
    pattern,
    nthreads = 1,
    mc.cores = 8
  )
)

cat("\n")
print(sessionInfo())
