#' Bin values by sorted breaks, in parallel
#'
#' @description Returns the same as base [findInterval()], but much faster for
#'   large, unsorted `x`. For each value, it finds the number of the interval
#'   it falls into: how many of the sorted breaks in `vec` are at or below it.
#'
#'   Use it to put ages into age groups, timestamps into shifts, or prices
#'   into tax brackets. The result can index a vector of labels.
#'
#' @details This is `cut(x, vec, right = FALSE, labels = FALSE)`, except at
#'   the ends. Values below the first break return `0`, and values at or above
#'   the last return `length(vec)`. [cut()] returns `NA` for both.
#'
#'   Computed in Rust for integer and double `x` and `vec` (including Dates and
#'   POSIXct) when `x` has at least 1e4 elements. Each element gets a binary
#'   search in `vec`, on several threads. Anything else goes to base
#'   [findInterval()], which also raises its errors. This includes a `vec` that
#'   is unsorted or contains `NA`. Base is already fast for sorted `x`, where
#'   it doesn't need to search from scratch.
#'
#'   `checkSorted` and `checkNA` are passed to base from R 4.5.0, which added
#'   them. Rust always checks.
#'
#' @inheritParams base::findInterval
#' @inheritParams par_match
#'
#' @returns An integer vector as long as `x`, as in [findInterval()]: for each
#'   element, the number of breaks in `vec` at or below it, adjusted by
#'   `rightmost.closed`, `all.inside`, and `left.open`. `NA` where `x` is `NA`.
#'
#' @export
#'
#' @examples
#' age <- c(4, 17, 18, 45, 67, NA)
#' groups <- c("child", "adult", "senior")
#' groups[par_find_interval(age, vec = c(0, 18, 65))]
#'
#' par_find_interval(c(1.5, 3.2, 0, 4), vec = 1:4, nthreads = 2)
#' par_find_interval(c(1.5, 3.2, 0, 4), vec = 1:4, rightmost.closed = TRUE)
par_find_interval <- function(
  x,
  vec,
  rightmost.closed = FALSE,
  all.inside = FALSE,
  left.open = FALSE,
  checkSorted = TRUE,
  checkNA = TRUE,
  nthreads = getOption("parvenu.threads", 0L)
) {
  nthreads <- check_nthreads(nthreads)

  # Base for what Rust doesn't cover.
  use_base <- length(x) < RUST_MIN ||
    !is_num(x) ||
    !is_num(vec) ||
    # Classes whose numbers aren't their as.double(), such as integer64.
    !is_dup_class(x) ||
    !is_dup_class(vec) ||
    length(vec) == 0L ||
    length(vec) > .Machine$integer.max ||
    !is_bool(rightmost.closed) ||
    !is_bool(all.inside) ||
    !is_bool(left.open) ||
    anyNA(vec) ||
    is.unsorted(vec)

  if (!use_base) {
    return(par_find_interval_rs(
      as_dbl(x),
      as_dbl(vec),
      rightmost.closed,
      all.inside,
      left.open,
      nthreads
    ))
  }

  # checkSorted and checkNA arrived in R 4.5.0. A local copy keeps R CMD
  # check on older R from flagging them, and errors still name it.
  findInterval <- base::findInterval

  if (getRversion() < "4.5.0") {
    return(findInterval(x, vec, rightmost.closed, all.inside, left.open))
  }

  findInterval(
    x,
    vec,
    rightmost.closed,
    all.inside,
    left.open,
    checkSorted,
    checkNA
  )
}
