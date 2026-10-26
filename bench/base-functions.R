# The functions under "Dates, ranks, and sums" in the README, and the
# factor, table, and set functions, against base, collapse, and data.table;
# run after installing parvenu.
library(parvenu)
set.seed(1)

cat("1e6 dates and times\n")
t <- as.POSIXct("1990-01-01", tz = "UTC") + runif(1e6, 0, 1e9)
dates <- format(as.Date(t))
times <- format(t, "%Y-%m-%d %H:%M:%S")
times_2y <- format(
  as.POSIXct("2024-01-01", tz = "UTC") + runif(1e6, 0, 6.3e7),
  "%Y-%m-%d %H:%M:%S"
)
stopifnot(identical(par_as_date(dates), as.Date(dates)))
print(bench::mark(
  base_date = as.Date(dates),
  data.table_date = data.table::as.IDate(dates),
  parvenu_date = par_as_date(dates),
  base_utc = as.POSIXct(times, tz = "UTC"),
  parvenu_utc = par_as_posixct(times, tz = "UTC"),
  base_berlin_2y = as.POSIXct(times_2y, tz = "Europe/Berlin"),
  parvenu_berlin_2y = par_as_posixct(times_2y, tz = "Europe/Berlin"),
  check = FALSE,
  min_iterations = 3,
  filter_gc = FALSE
)[, c("expression", "median")])

n <- 1e7
cat("\nrank(), 1e7 doubles and 1e7 integers with many ties\n")
xd <- runif(n)
xi <- sample.int(1e4, n, TRUE)
print(bench::mark(
  base_dbl = rank(xd),
  data.table_dbl = data.table::frank(xd),
  parvenu_dbl = par_rank(xd),
  base_int = rank(xi),
  data.table_int = data.table::frank(xi),
  parvenu_int = par_rank(xi),
  check = FALSE,
  min_iterations = 3,
  filter_gc = FALSE
)[, c("expression", "median")])

for (k in c(1e5, 100)) {
  cat("\nrowsum(), 1e7 doubles in", k, "groups\n")
  g <- sample.int(k, n, TRUE)
  print(bench::mark(
    base = rowsum(xd, g),
    collapse = collapse::fsum(xd, g),
    parvenu = par_rowsum(xd, g),
    check = FALSE,
    min_iterations = 3,
    filter_gc = FALSE
  )[, c("expression", "median")])
}

cat("\napprox(), 1e7 points into 1e4\n")
px <- sort(runif(1e4, 0, 10))
py <- rnorm(1e4)
xout <- runif(n, 0, 10)
print(bench::mark(
  base = approx(px, py, xout = xout),
  parvenu = par_approx(px, py, xout = xout),
  min_iterations = 3,
  filter_gc = FALSE
)[, c("expression", "median")])

cat("\nSets and anyDuplicated(), 1e7 integers\n")
a <- sample.int(1e8, n)
b <- sample.int(1e8, n)
print(bench::mark(
  base_union = union(a, b),
  parvenu_union = par_union(a, b),
  base_intersect = intersect(a, b),
  parvenu_intersect = par_intersect(a, b),
  base_setdiff = setdiff(a, b),
  parvenu_setdiff = par_setdiff(a, b),
  base_any_dup = anyDuplicated(a),
  collapse_any_dup = collapse::any_duplicated(a),
  parvenu_any_dup = par_any_duplicated(a),
  check = FALSE,
  min_iterations = 3,
  filter_gc = FALSE
)[, c("expression", "median")])

cat("\nfactor() and table(), 1e7 elements\n")
s <- as.character(sample.int(1e5, n, TRUE))
i6 <- sample.int(1e6, n, TRUE)
print(bench::mark(
  base_factor_chr = factor(s),
  collapse_factor_chr = collapse::qF(s),
  parvenu_factor_chr = par_factor(s),
  base_factor_int = factor(i6),
  parvenu_factor_int = par_factor(i6),
  base_table_int = table(i6),
  parvenu_table_int = par_table(i6),
  base_table_chr = table(s),
  parvenu_table_chr = par_table(s),
  check = FALSE,
  min_iterations = 3,
  filter_gc = FALSE
)[, c("expression", "median")])
cat("\n")
print(sessionInfo())
