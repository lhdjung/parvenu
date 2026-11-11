#' All matches, not just the first
#'
#' @description `par_match()` and `par_match_rows()` find the first match of
#'   each element or row of `x` in `table`. These find all of them, as pairs
#'   of positions. This is a many-to-many join, such as [merge()] does on key
#'   columns.
#'
#'   - `par_match_all()` compares vectors as `par_match()` does.
#'   - `par_match_rows_all()` compares rows as `par_match_rows()` does.
#'
#' @details With `x` and `table` the same, the pairs are all groups of equal
#'   elements, including each element paired with itself.
#'
#'   The number of pairs can be much larger than either input: 1e5 equal
#'   elements on each side make 1e10. It is counted before any pair is built.
#'   More than 2^31 - 1 pairs are an error.
#'
#'   The table is hashed once. As each element goes into the map, it is
#'   numbered by its group, the first equal element. Each element of `x` is
#'   then looked up, and the positions in `table` are sorted by group with a
#'   counting sort. The pairs are written on several threads. So the work
#'   beyond the hashing is linear in the number of pairs.
#'
#' @inheritParams par_match_rows
#'
#' @returns A data frame with one row per pair, sorted by `x` and then by
#'   `table`. Column `x` is a position (or row) in `x`, and column `table` is
#'   a position in `table` equal to it. Elements of `x` with no match in
#'   `table` have no rows.
#'
#' @export
#'
#' @examples
#' par_match_all(c("b", "a", "z"), c("a", "b", "a"))
#'
#' # Groups of equal rows, each pair once
#' keys <- data.frame(x = c(1, 2, 1, 1), y = c("a", "b", "a", "a"))
#' pairs <- par_match_rows_all(keys, keys)
#' pairs[pairs$x < pairs$table, ]
par_match_all <- function(
  x,
  table,
  nthreads = getOption("parvenu.threads", 0L)
) {
  nthreads <- check_nthreads(nthreads)
  if (max(length(x), length(table)) > .Machine$integer.max) {
    stop("`x` and `table` can have at most 2^31 - 1 elements.")
  }
  # One column of rows compares as par_match() compares vectors.
  match_all(list(x), list(table), nthreads)
}

#' @rdname par_match_all
#' @export
par_match_rows_all <- function(
  x,
  table,
  nthreads = getOption("parvenu.threads", 0L)
) {
  nthreads <- check_nthreads(nthreads)
  rows <- check_rows(x, table)
  match_all(rows$x, rows$table, nthreads)
}

match_all <- function(x, table, nthreads) {
  x |>
    call_rows(
      rust = function(xk, tk, day) par_match_rows_all_rs(xk, tk, day, nthreads),
      table = table,
      nthreads = nthreads
    ) |>
    list2DF()
}
