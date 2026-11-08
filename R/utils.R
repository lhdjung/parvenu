# `x`, or `y` if `x` is NULL: base has it only from R 4.4.0. `y` is only
# evaluated when needed, so `rust() %||% base()` calls base only as a fallback.
`%||%` <- function(x, y) if (is.null(x)) y else x

is_bool <- function(x) is.logical(x) && length(x) == 1L && !is.na(x)

is_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

# Can't use is.numeric() because that's FALSE for POSIXct
is_num <- function(x) is.integer(x) || is.double(x)

# Doubles go to Rust as they are, attributes and all, without a copy.
as_dbl <- function(x) if (is.double(x)) x else as.double(x)

# Rust reads strings as UTF-8, converting latin1 ones on its threads, so only
# native strings in a locale that isn't UTF-8 need enc2utf8() first. It takes
# about 6ms per 1e6 strings on one thread, even where it changes nothing.
as_utf8 <- function(x) if (l10n_info()[["UTF-8"]]) x else enc2utf8(x)

check_nthreads <- function(nthreads) {
  if (
    !is.numeric(nthreads) ||
      length(nthreads) != 1L ||
      is.na(nthreads) ||
      nthreads < 0 ||
      nthreads > .Machine$integer.max ||
      nthreads != trunc(nthreads)
  ) {
    stop("`nthreads` must be a single non-negative whole number.")
  }
  as.integer(nthreads)
}

# A data frame or list of columns as an unnamed list of equal-length
# vectors. Lists count, such as POSIXlt and list columns, which par_match()
# compares element by element; data frames don't.
as_columns <- function(x, arg) {
  if (!is.list(x) || length(x) == 0L) {
    stop("`", arg, "` must be a data frame or a list of columns.")
  }
  x <- x |> as.list() |> unname()
  is_column <- function(v) is.atomic(v) || (is.list(v) && !is.data.frame(v))
  same_length <- lengths(x) |> unique() |> length() == 1L
  if (!same_length || !all(vapply(x, is_column, NA))) {
    stop("The columns of `", arg, "` must be vectors of the same length.")
  }
  x
}

# `m[x]` for a factor `x`, with `NA` codes taking `m`'s last element: a result
# per level, from a function that only had to run on the levels.
# index_codes() does integer and logical ones in Rust.
index_levels <- function(x, m, nthreads) {
  if (is.integer(m) || is.logical(m)) {
    return(index_codes(x, m, nthreads))
  }
  codes <- as.integer(x)
  codes[is.na(codes)] <- length(m) # NA codes take the last element
  m[codes]
}
