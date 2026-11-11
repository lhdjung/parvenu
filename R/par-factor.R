#' Make a factor, or count values, in parallel
#'
#' @description Drop-in replacements for base functions, faster for large
#'   inputs:
#'   - `par_factor()` for [`factor()`][base::factor].
#'   - `par_table()` for [`table()`][base::table].
#'
#'   They take base's arguments and give identical results. The only
#'   differences: both take `nthreads`, and `par_factor()` ignores `nmax`.
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
#' @param ... Vectors or factors of the same length, or a single list of
#'   them, such as a data frame, as in [base::table()].
#' @inheritParams base::factor
#' @inheritParams base::table
#' @inheritParams par_match
#'
#' @returns As base: a factor from `par_factor()`, a `table` from
#'   `par_table()`.
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
  as_chr <- is.object(x) ||
    !(is.character(x) || is.integer(x) || is.logical(x))

  if (missing(levels)) {
    # The sorted distinct values.
    y <- par_unique(x, nthreads = nthreads)
    ind <- order(y)
    if (as_chr) {
      y <- as.character(y)
    }
    levels <- unique(y[ind])
  }

  # Evaluate `ordered` while `x` is still as given.
  force(ordered)

  if (as_chr) {
    x <- as.character(x)
  }

  # Each element's code is its position among the levels.
  levels <- levels[is.na(match(levels, exclude))]
  f <- par_match(x, levels, nthreads = nthreads)

  if (!is.null(nx)) {
    names(f) <- nx
  }

  # Name the levels: by `labels`, numbered from one label, or as themselves.
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
  dnn = list_names(...),
  deparse.level = 1,
  nthreads = getOption("parvenu.threads", 0L)
) {
  nthreads <- check_nthreads(nthreads)

  # As base's table(), with par_factor() and par_match().
  # Default names: those of the arguments, or their deparsed expressions.
  list_names <- function(...) {
    l <- as.list(substitute(list(...)))[-1L]

    # A single named list, such as a data frame, gives its own names.
    if (length(l) == 1L && is.list(..1) && !is.null(nm <- names(..1))) {
      return(nm)
    }

    # Unnamed arguments are named after their expressions.
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
  miss_use <- missing(useNA)
  miss_exc <- missing(exclude)
  useNA <- if (miss_use && !miss_exc && !match(NA, exclude, nomatch = 0L)) {
    "ifany"
  } else {
    match.arg(useNA)
  }

  # Contradicting arguments: base warns, but goes ahead.
  do_na <- useNA != "no"
  if (!miss_use && !miss_exc && do_na && match(NA, exclude, nomatch = 0L)) {
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

    # Whether `a` is a factor, and had NAs before par_factor() can drop them.
    is_fct <- is.factor(a)
    if (do_na) {
      raw_na <- anyNA(a)
    }

    if (!is_fct) {
      # Warnings become errors here, as in base.
      a0 <- a
      op <- options(warn = 2)
      on.exit(options(op))
      a <- par_factor(a, exclude = exclude, nthreads = nthreads)
      options(op)
    }

    # An NA level is added where there are NAs, and with "always" if there
    # isn't one yet. This is base's logic, untangled.
    add_na <- FALSE
    if (do_na) {
      ifany <- useNA == "ifany"
      fct_na <- anyNA(a)
      ll <- levels(a)
      add_ll <- !anyNA(ll)
      if (add_ll) {
        ll <- c(ll, NA)
      }
      add_na <- fct_na || (!ifany && add_ll)
    }

    if (add_na) {
      a <- par_factor(a, levels = ll, exclude = NULL, nthreads = nthreads)
    } else {
      ll <- levels(a)
    }

    # From here on, `a` holds the codes.
    a <- as.integer(a)

    # Drop the excluded levels and values.
    if (is_fct && !miss_exc) {
      keep <- which(match(ll, exclude, nomatch = 0L) == 0L)
      ll <- ll[keep]
      a <- par_match(a, keep, nthreads = nthreads)
    } else if (!is_fct && add_na) {
      # Excluded values, which par_factor() made NA, took the new NA level, so
      # they are made NA again.
      if (ifany && !raw_na && add_ll) {
        # Only excluded values were NA: the NA level goes again.
        ll <- ll[!is.na(ll)]
        is.na(a) <- par_match(a0, c(exclude, NA), 0L, nthreads = nthreads) > 0L
      } else {
        is.na(a) <- par_match(a0, exclude, 0L, nthreads = nthreads) > 0L
      }
    }

    # This factor's levels add a dimension to the table.
    nl <- length(ll)
    dims <- c(dims, nl)

    if (prod(dims) > .Machine$integer.max) {
      stop("attempt to make a table with >= 2^31 elements")
    }

    # This factor's codes become the next digit of the cell index.
    dn <- c(dn, list(ll))
    bin <- bin + pd * (a - 1L)
    pd <- pd * nl
  }

  # Count the cells. An NA code in any factor drops the element.
  names(dn) <- dnn
  bin <- bin[!is.na(bin)]
  if (length(bin)) {
    bin <- bin + 1L
  }

  y <- array(tabulate(bin, pd), dims, dimnames = dn)
  class(y) <- "table"

  y
}
