#' Multithreaded `match()` on rows
#'
#' @description Finds, for each row of `x`, the position of the first row of
#'   `table` that is equal to it in every column. This is a join on several
#'   key columns.
#'
#' @details Columns are paired by position, not by name. Each pair is compared
#'   as `par_match()` compares vectors: `1L` matches `1`, a factor matches by
#'   its levels, and `NA` matches `NA`.
#'
#'   Whole rows are hashed in parallel, so this costs about as much as one
#'   `par_match()` call, however many columns there are. Integer, double,
#'   character, Date, POSIXct, and factor columns are compared in Rust as they
#'   are. Other columns are first turned by `par_match()` into the positions of
#'   first occurrences in `table`.
#'
#' @param x Rows to look up: a data frame, or a list of vectors of equal
#'   length.
#' @param table Rows to look them up in, in the same form, with as many
#'   columns as `x`.
#' @inheritParams par_match
#'
#' @returns An integer vector with one element per row of `x`: the first row
#'   of `table` equal to it, or `nomatch` if there is none. Use
#'   `par_match_rows(x, table, nomatch = 0L) > 0L` to find which rows of `x`
#'   are in `table`.
#'
#' @export
#'
#' @examples
#' orders <- data.frame(customer = c(1L, 2L, 1L), year = c(2025, 2025, 2026))
#' targets <- data.frame(
#'   customer = c(1L, 1L, 2L),
#'   year = c(2026, 2025, 2026),
#'   goal = c(500, 400, 300)
#' )
#' i <- par_match_rows(orders, targets[c("customer", "year")])
#' targets$goal[i]
par_match_rows <- function(
  x,
  table,
  nomatch = NA_integer_,
  nthreads = getOption("parvenu.threads", 0L)
) {
  nthreads <- check_nthreads(nthreads)

  nomatch <- as.integer(nomatch)[1L]
  rows <- check_rows(x, table)

  call_rows(
    function(xk, tk, day) par_match_rows_rs(xk, tk, day, nomatch, nthreads),
    rows$x,
    rows$table,
    nthreads
  )
}

# `x` and `table` as lists of columns, checked to be rows Rust can number.
check_rows <- function(x, table) {
  x <- as_columns(x, "x")
  table <- as_columns(table, "table")

  if (length(x) != length(table)) {
    stop("`x` and `table` must have the same number of columns.")
  }
  if (max(length(x[[1L]]), length(table[[1L]])) > .Machine$integer.max) {
    stop("`x` and `table` can have at most 2^31 - 1 rows.")
  }

  list(x = x, table = table)
}

# `rust(xk, tk, day)`, par_match_rows_rs() or par_match_rows_all_rs(), on
# the columns of `x` and `table` as Rust compares them.
call_rows <- function(rust, x, table, nthreads) {
  # Each column pair as Rust compares it.
  pairs <- Map(key_pair, x, table, MoreArgs = list(nthreads = nthreads))
  xk <- lapply(pairs, `[[`, "x")
  tk <- lapply(pairs, `[[`, "table")
  day <- vapply(pairs, `[[`, NA, "day")

  out <- rust(xk, tk, day)
  if (!is.null(out)) {
    return(out)
  }

  # Base matches Dates beyond 1e10 days by their printed numbers.
  for (j in which(day)) {
    xk[[j]] <- par_match(x[[j]], table[[j]], nthreads = nthreads)
    tk[[j]] <- par_match(table[[j]], table[[j]], nthreads = nthreads)
  }
  rust(xk, tk, logical(length(x)))
}

# Column `a` of `x` and `b` of `table` as Rust compares them, and whether
# they are Dates that Rust must compare by day.
key_pair <- function(a, b, nthreads) {
  pair <- function(x, table, day = FALSE) list(x = x, table = table, day = day)

  if (identical(class(a), "Date") && identical(class(b), "Date")) {
    # Before R 4.6.0, Dates matched by their printed day, so 1.5 matched 1.
    return(pair(as_dbl(a), as_dbl(b), getRversion() < "4.6.0"))
  }

  if (is.factor(a) && is.factor(b) && !anyNA(c(levels(a), levels(b)))) {
    # Codes stand in for the levels, which as.character() would copy into
    # every element: `a`'s become `b`'s, and levels `b` lacks become 0,
    # which no code of `b` is. A level that is `NA` would equal an `NA`
    # code as a string, so such factors are matched as strings below.
    m <- c(match(levels(a), levels(b), nomatch = 0L), NA)
    return(pair(index_codes(a, m, nthreads), b))
  }

  # Numbers compare as numbers, integer against double as doubles.
  pa <- as_plain(a)
  pb <- as_plain(b)
  if (is_num(pa) && is_num(pb) && is.integer(pa) != is.integer(pb)) {
    return(pair(as.double(pa), as.double(pb))) # integer against double
  }
  if (is_num(pa) && is_num(pb)) {
    return(pair(pa, pb))
  }

  # Strings compare by their pointers in R's cache, unless encodings differ.
  if (
    is.character(pa) &&
      is.character(pb) &&
      par_pointers_suffice(pa, pb, nthreads)
  ) {
    return(pair(pa, pb))
  }

  # Positions of first occurrences in `table` stand in for the values.
  pair(
    par_match(a, b, nthreads = nthreads),
    par_match(b, b, nthreads = nthreads)
  )
}
