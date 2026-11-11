#' Make a factor, or count values, in parallel
#'
#' @description Same results as base, but faster for large inputs:
#'   - `par_factor()` for [factor()].
#'   - `par_table()` for [table()].
#'
#' @details Both spend most of their time finding the distinct values and the
#'   position of each element among them. Here, [par_unique()] and
#'   [par_match()] do that on several threads. Sorting the levels stays with
#'   base R.
#'
#'   `factor()` of 1e7 strings in 1e5 levels takes about 0.8s in base R and
#'   0.5s here, most of it sorting the levels. For 1e7 integers in 1e6 levels,
#'   0.85s becomes 0.3s, most of it making the levels' strings. `table()` of
#'   1e7 integers takes about 1s in base and 0.45s here. The rest is R's own
#'   counting.
#'
#'   A double vector is tabulated by its printed values, as in base. That
#'   takes seconds for 1e7 of them either way.
#'
#' @param x A vector, as in [base::factor()].
#' @param nmax Ignored. It is a hint for base's hash table, kept so that the
#'   arguments are in base's order.
#' @inheritParams base::factor
#' @inheritParams base::table
#' @inheritParams par_match
#'
#' @returns `par_factor()`: a factor, as [factor()] returns it, with the names
#'   of `x`. `par_table()`: a `table`, as [table()] returns it.
#'
#' @export
#'
#' @examples
#' par_factor(c("b", "a", "b"))
#' par_factor(c(3, 1, 3), labels = c("low", "high"))
#' par_table(c("b", "a", "b", NA), useNA = "ifany")
#' par_table(c(1, 2, 1), c("x", "x", "y"))
par_factor <- function(
  x = character(),
  levels,
  labels = levels,
  exclude = NA,
  ordered = is.ordered(x),
  nmax = NA,
  nthreads = getOption("parvenu.threads", 0L)
) {
  nthreads <- check_nthreads(nthreads)
  # As base's factor(), with par_unique() and par_match().
  if (is.null(x)) {
    x <- character()
  }
  nx <- names(x)
  # Classed and double inputs are matched as strings, as in base.
  matchAsChar <- is.object(x) ||
    !(is.character(x) || is.integer(x) || is.logical(x))
  if (missing(levels)) {
    # The sorted distinct values.
    y <- par_unique(x, nthreads = nthreads)
    ind <- order(y)
    if (matchAsChar) {
      y <- as.character(y)
    }
    levels <- unique(y[ind])
  }
  force(ordered)
  if (matchAsChar) {
    x <- as.character(x)
  }
  levels <- levels[is.na(match(levels, exclude))]
  f <- par_match(x, levels, nthreads = nthreads)
  if (!is.null(nx)) {
    names(f) <- nx
  }
  nlab <- length(labels)
  if (missing(labels)) {
    levels(f) <- as.character(levels)
  } else if (nlab == length(levels)) {
    # Duplicated labels merge their levels.
    xlevs <- as.character(labels)
    nlevs <- unique(xlevs)
    at <- attributes(f)
    at$levels <- nlevs
    f <- match(xlevs, nlevs)[f]
    attributes(f) <- at
  } else if (nlab == 1L) {
    levels(f) <- paste0(labels, seq_along(levels))
  } else {
    msg <- "invalid 'labels'; length %d should be 1 or %d"
    stop(gettextf(msg, nlab, length(levels)), domain = NA)
  }
  class(f) <- c(if (ordered) "ordered", "factor")
  f
}

#' @rdname par_factor
#' @export
par_table <- function(
  ...,
  exclude = if (useNA == "no") c(NA, NaN),
  useNA = c("no", "ifany", "always"),
  dnn = list.names(...),
  deparse.level = 1,
  nthreads = getOption("parvenu.threads", 0L)
) {
  nthreads <- check_nthreads(nthreads)
  # As base's table(), with par_factor() and par_match().
  # Default names: those of the arguments, or their deparsed expressions.
  list.names <- function(...) {
    l <- as.list(substitute(list(...)))[-1L]
    if (length(l) == 1L && is.list(..1) && !is.null(nm <- names(..1))) {
      return(nm)
    }
    nm <- names(l)
    fixup <- if (is.null(nm)) seq_along(l) else nm == ""
    dep <- vapply(
      l[fixup],
      function(x) {
        switch(
          deparse.level + 1,
          "",
          if (is.symbol(x)) as.character(x) else "",
          deparse(x, nlines = 1)[1L]
        )
      },
      ""
    )
    if (is.null(nm)) {
      dep
    } else {
      nm[fixup] <- dep
      nm
    }
  }
  # Settle `useNA` from `exclude`, as base does.
  miss.use <- missing(useNA)
  miss.exc <- missing(exclude)
  useNA <- if (miss.use && !miss.exc && !match(NA, exclude, nomatch = 0L)) {
    "ifany"
  } else {
    match.arg(useNA)
  }
  doNA <- useNA != "no"
  if (!miss.use && !miss.exc && doNA && match(NA, exclude, nomatch = 0L)) {
    warning(
      "'exclude' containing NA and 'useNA' != \"no\"' are a bit contradicting"
    )
  }
  # A single list argument holds the factors.
  args <- list(...)
  if (length(args) == 1L && is.list(args[[1L]])) {
    args <- args[[1L]]
    if (length(dnn) != length(args)) {
      dnn <- paste(dnn[1L], seq_along(args), sep = ".")
    }
  }
  if (!length(args)) {
    stop("nothing to tabulate")
  }
  # Each factor adds its codes to `bin`, one cell index per element.
  bin <- 0L
  lens <- NULL
  dims <- integer()
  pd <- 1L
  dn <- NULL
  for (a in args) {
    if (is.null(lens)) {
      lens <- length(a)
    } else if (length(a) != lens) {
      stop("all arguments must have the same length")
    }
    fact.a <- is.factor(a)
    if (doNA) {
      aNA <- anyNA(a)
    }
    if (!fact.a) {
      # Warnings become errors here, as in base.
      a0 <- a
      op <- options(warn = 2)
      on.exit(options(op))
      a <- par_factor(a, exclude = exclude, nthreads = nthreads)
      options(op)
    }
    # An NA level is added where there are NAs, and with "always" if there
    # isn't one yet. This is base's logic, untangled.
    add.na <- FALSE
    if (doNA) {
      ifany <- useNA == "ifany"
      anNAc <- anyNA(a)
      ll <- levels(a)
      add.ll <- !anyNA(ll)
      if (add.ll) {
        ll <- c(ll, NA)
      }
      add.na <- anNAc || (!ifany && add.ll)
    }
    if (add.na) {
      a <- par_factor(a, levels = ll, exclude = NULL, nthreads = nthreads)
    } else {
      ll <- levels(a)
    }
    a <- as.integer(a)
    # Drop the excluded levels and values.
    if (fact.a && !miss.exc) {
      keep <- which(match(ll, exclude, nomatch = 0L) == 0L)
      ll <- ll[keep]
      a <- par_match(a, keep, nthreads = nthreads)
    } else if (!fact.a && add.na) {
      if (ifany && !aNA && add.ll) {
        ll <- ll[!is.na(ll)]
        is.na(a) <- par_match(a0, c(exclude, NA), 0L, nthreads = nthreads) > 0L
      } else {
        is.na(a) <- par_match(a0, exclude, 0L, nthreads = nthreads) > 0L
      }
    }
    nl <- length(ll)
    dims <- c(dims, nl)
    if (prod(dims) > .Machine$integer.max) {
      stop("attempt to make a table with >= 2^31 elements")
    }
    dn <- c(dn, list(ll))
    bin <- bin + pd * (a - 1L)
    pd <- pd * nl
  }
  # Count the cells.
  names(dn) <- dnn
  bin <- bin[!is.na(bin)]
  if (length(bin)) {
    bin <- bin + 1L
  }
  y <- array(tabulate(bin, pd), dims, dimnames = dn)
  class(y) <- "table"
  y
}
