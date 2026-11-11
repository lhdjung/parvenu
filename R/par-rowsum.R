#' Sum by group, in parallel
#'
#' @description Returns the same as base [rowsum()]: the sum of `x` within each
#'   group, or of each column of a matrix. Base R takes about a second for 10
#'   million values.
#'
#' @details Computed in Rust for integer and double vectors and matrices with
#'   at least 1e4 rows. Anything else, such as a data frame, goes to base R.
#'
#'   Each group's values are summed in their order, as in base R, so the sums
#'   agree to the last bit. Integer sums that overflow return `NA`, as in base.
#'
#' @inheritParams base::rowsum
#' @inheritParams par_match
#'
#' @returns As [rowsum()]: a matrix with a row per group, named by the groups
#'   and sorted unless `reorder = FALSE`. It has a column per column of `x`.
#'
#' @export
#'
#' @examples
#' par_rowsum(c(1, 2, 3, 4), c("b", "a", "b", "a"))
#' par_rowsum(matrix(1:6, 3, dimnames = list(NULL, c("p", "q"))), c(2, 1, 2))
par_rowsum <- function(
  x,
  group,
  reorder = TRUE,
  na.rm = FALSE,
  ...,
  nthreads = getOption("parvenu.threads", 0L)
) {
  nthreads <- check_nthreads(nthreads)
  if (
    !is.numeric(x) ||
      is.object(x) ||
      length(dim(x)) > 2L ||
      NROW(x) < RUST_MIN ||
      NROW(x) > .Machine$integer.max ||
      NCOL(x) == 0L ||
      !is.atomic(group) || # POSIXlt is a list
      length(group) != NROW(x) ||
      !is_bool(reorder) ||
      !is_bool(na.rm)
  ) {
    return(rowsum(x, group, reorder = reorder, na.rm = na.rm, ...))
  }
  if (anyNA(group)) {
    warning("missing values for 'group'")
  }
  # The groups, sorted as base sorts them.
  groups <- par_unique(group, nthreads = nthreads)
  if (reorder) {
    groups <- sort(groups, na.last = TRUE, method = "quick")
  }
  # Base finds each row's group by its raw value, not as match() compares
  # classed ones, such as difftime by its printed number.
  codes <- par_match(unclass(group), unclass(groups), nthreads = nthreads)
  # Of NA and NaN in one group, base keeps the first or the second,
  # depending on how R was compiled.
  nan_first <- !is.nan(rowsum(c(NA, NaN), c(1, 1))[1L])
  out <- par_rowsum_rs(x, codes, length(groups), na.rm, nan_first, nthreads)
  dim(out) <- c(length(groups), NCOL(x))
  # colnames() fails on a 1-d array with dimnames, which base sums as a vector.
  dimnames(out) <- list(as.character(groups), if (is.matrix(x)) colnames(x))
  out
}
