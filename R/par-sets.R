#' Set operations, in parallel
#'
#' @description Same results as [base::union()], [base::intersect()], and
#'   [base::setdiff()], but much faster for large inputs: the distinct elements
#'   come from [par_unique()] and the lookups from [par_match()], so each
#'   takes about a tenth of base's time at 1e7 elements.
#'
#' @param x,y Vectors, as in [base::union()].
#' @inheritParams par_match
#'
#' @returns A vector without duplicates, as the base functions return it:
#'   the elements of `x` and `y`, of both, or of `x` only.
#'
#' @export
#'
#' @examples
#' par_union(c(3, 1, 3), c(2, 1))
#' par_intersect(c(3, 1, 3), c(2, 1))
#' par_setdiff(c(3, 1, 3), c(2, 1))
par_union <- function(x, y, nthreads = getOption("parvenu.threads", 0L)) {
  if (set_ops_need_as_vector(x, y)) {
    x <- as.vector(x)
    y <- as.vector(y)
  } else if (!isa(x, class(y))) {
    x <- c(y[0L], x) # take `y`'s class
  }
  x <- unique_unnamed(x, nthreads)
  y <- unique_unnamed(y, nthreads)
  c(x, y[par_match(y, x, 0L, nthreads = nthreads) == 0L])
}

#' @rdname par_union
#' @export
par_intersect <- function(x, y, nthreads = getOption("parvenu.threads", 0L)) {
  if (is.null(x) || is.null(y)) {
    return(NULL)
  }
  if (set_ops_need_as_vector(x, y)) {
    x <- as.vector(x)
    y <- as.vector(y)
  }
  x <- unique_unnamed(x, nthreads)
  y <- unique_unnamed(y, nthreads)
  c(x[par_match(x, y, 0L, nthreads = nthreads) > 0L], y[0L])
}

#' @rdname par_union
#' @export
par_setdiff <- function(x, y, nthreads = getOption("parvenu.threads", 0L)) {
  if (is.null(x)) {
    return(NULL)
  }
  if (set_ops_need_as_vector(x, y)) {
    x <- as.vector(x)
    y <- as.vector(y)
  }
  x <- unique_unnamed(x, nthreads)
  y <- unique_unnamed(y, nthreads)
  x[par_match(x, y, 0L, nthreads = nthreads) == 0L]
}

# par_unique() without names, as the set operations return it.
unique_unnamed <- function(v, nthreads) {
  v <- par_unique(v, nthreads = nthreads)
  names(v) <- NULL
  v
}

# base:::.set_ops_need_as_vector (R 4.5): whether the set operations work on
# the plain vectors, rather than keeping the classes of `x` and `y`. Before
# R 4.5.0, they always did.
set_ops_need_as_vector <- function(x, y) {
  class0 <- function(v) class(tryCatch(v[0L], error = identity))
  getRversion() < "4.5.0" ||
    length(dim(x)) >= 2L ||
    length(dim(y)) >= 2L ||
    (!isa(x, class(y)) && !isa(y, class(x))) ||
    !identical(class0(x), class(x)) ||
    !identical(class0(y), class(y))
}
