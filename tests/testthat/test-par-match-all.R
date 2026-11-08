# The definition: every pair of positions whose elements match() the same
# element of `table`, sorted by `x` and then `table`.
match_all_base <- function(x_first, table_first) {
  pairs <- expand.grid(table = seq_along(table_first), x = seq_along(x_first))
  same <- x_first[pairs$x] == table_first[pairs$table]
  pairs <- pairs[!is.na(same) & same, c("x", "table")]
  rownames(pairs) <- NULL
  pairs
}

test_that("par_match_all() pairs every equal element", {
  set.seed(3)
  x <- sample(c(1:30, NA, NaN), 400, TRUE)
  table <- sample(c(1:40, NA), 300, TRUE)
  expect_identical(
    par_match_all(x, table),
    match_all_base(match(x, table), match(table, table))
  )
  expect_identical(
    par_match_all(table, table),
    match_all_base(match(table, table), match(table, table))
  )
  # Long enough for the Rust path and a split by hash
  x <- sample(1e5, 2e5, TRUE)
  table <- sample(1e5, 7e4, TRUE)
  pairs <- par_match_all(x, table)
  expect_true(all(x[pairs$x] == table[pairs$table]))
  expect_identical(
    nrow(pairs),
    sum(tabulate(match(table, table))[match(x, table)], na.rm = TRUE)
  )
  expect_false(is.unsorted(pairs$x * 1e6 + pairs$table, strictly = TRUE))
})

test_that("par_match_rows_all() pairs every equal row", {
  set.seed(4)
  rows <- function(n) {
    data.frame(
      i = sample(c(1:3, NA), n, TRUE),
      s = sample(c("a", "b"), n, TRUE),
      d = sample(c(0.5, -0, 0, NaN), n, TRUE)
    )
  }
  x <- rows(200)
  table <- rows(150)
  expect_identical(
    par_match_rows_all(x, table),
    match_all_base(par_match_rows(x, table), par_match_rows(table, table))
  )
})

test_that("par_match_all() handles no matches and empty inputs", {
  empty <- data.frame(x = integer(), table = integer())
  expect_identical(par_match_all(1:3, 4:6), empty)
  expect_identical(par_match_all(integer(), 1:3), empty)
  expect_identical(par_match_all(1:3, integer()), empty)
  expect_identical(
    par_match_all(c(2, 2), c(2, 2)),
    data.frame(
      x = c(1L, 1L, 2L, 2L),
      table = c(1L, 2L, 1L, 2L)
    )
  )
})

test_that("par_match_all() agrees with match() on every type, split by hash or not", {
  # The pairs from first positions, sorted by x and then table
  pairs_of <- function(x_first, table_first) {
    by_group <- order(table_first, method = "radix")
    sizes <- tabulate(table_first, length(table_first))
    starts <- cumsum(c(1L, sizes))
    matched <- which(!is.na(x_first))
    counts <- sizes[x_first[matched]]
    data.frame(
      x = rep(matched, counts),
      table = by_group[sequence(counts, from = starts[x_first[matched]])]
    )
  }
  set.seed(5)
  for (n in c(500, 2e5)) {
    k <- n / 4
    vectors <- list(
      int = sample(c(1:k, NA), n, TRUE),
      dbl = sample(c(1:k / 2, NA, NaN, -0), n, TRUE),
      chr = sample(c(as.character(1:k), NA), n, TRUE),
      fct = factor(sample(c(letters, NA), n, TRUE)),
      date = as.Date(sample(c(1:k, NA), n, TRUE))
    )
    for (v in vectors) {
      x <- v[seq(1, n, 3)]
      expect_identical(par_match_all(x, v), pairs_of(match(x, v), match(v, v)))
    }
    # integer against double
    expect_identical(
      par_match_all(vectors$int, as.double(vectors$int)),
      pairs_of(match(vectors$int, vectors$int), match(vectors$int, vectors$int))
    )
    rows <- data.frame(a = vectors$int %% 7L, b = vectors$chr, c = vectors$dbl > 3)
    x <- rows[seq(1, n, 2), ]
    expect_identical(
      par_match_rows_all(x, rows),
      pairs_of(par_match_rows(x, rows), par_match_rows(rows, rows))
    )
  }
  # Dates too far out for Rust to match by day
  far <- as.Date(c(1e11, 2, 1e11))
  expect_identical(par_match_all(far, far), pairs_of(match(far, far), match(far, far)))
})
