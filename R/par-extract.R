#' Extract or replace regex matches, in parallel
#'
#' @description
#'   - `par_extract()` returns the first match in each string, like
#'   `regmatches(x, regexpr(pattern, x))`, but with `NA` where nothing
#'   matches.
#'   - `par_extract_all()` returns every match, like
#'   `regmatches(x, gregexpr(pattern, x))`.
#'   - `par_locate()` finds where the first match is, like
#'   `regexpr(pattern, x)`.
#'   - `par_locate_all()` finds where every match is, like
#'   `gregexpr(pattern, x)`.
#'   - `par_replace()` replaces the first match, like
#'   `sub(pattern, replacement, x)`.
#'   - `par_replace_all()` replaces every match, like
#'   `gsub(pattern, replacement, x)`.
#'
#'   All use the syntax of Rust's regex crate, as [par_detect()] does.
#'
#' @details `par_extract()` can return a capture group instead of the whole
#'   match, which takes the place of lookaround. It can also return several
#'   groups at once, as a matrix.
#'
#'   The threads find the matches and build the replaced strings. Only R's
#'   thread may turn them into R strings, so that part runs serially. Strings
#'   that `par_replace()` and `par_replace_all()` leave unchanged are not
#'   copied.
#'
#' @param group The capture group to extract: 0 for the whole match, 1 for
#'   the first group, and so on. `par_extract()` also takes several, such as
#'   `0:3`. It then returns a matrix with a column per group, from one search.
#' @param replacement The string to put in place of each match. Unless
#'   `fixed = TRUE`, `$1` stands for the first capture group, `${name}` for a
#'   named one, and `$$` for a `$`. Write `${1}a`, not `$1a`, which means a
#'   group named `1a`. R's `\\1` is not a group here.
#' @inheritParams par_detect
#'
#' @returns
#'   - `par_extract()`, `par_replace()`, and `par_replace_all()`: a string
#'   vector as long as `x`, with the names of `x`, as [regmatches()], [sub()],
#'   and [gsub()] keep them. `NA` where `x` or `pattern` is `NA`. For
#'   `par_extract()`, also `NA` where nothing matches or the group took no
#'   part in the match. With several groups, `par_extract()` returns a string
#'   matrix instead, with a row per string (named as `x` is) and a column per
#'   group, as [stringi::stri_match_first_regex()] does.
#'   - `par_extract_all()`: a list as long as `x`. Each element is a string
#'   vector of the matches, `character(0)` if none, or `NA` where `x` or
#'   `pattern` is `NA`. It finds the matches that [par_count()] counts. For a
#'   group, it has `NA` where the group took no part in a match.
#'   - `par_locate()`: an integer matrix with a row per string and columns
#'   `start` and `end`, positions of characters, as in
#'   [stringi::stri_locate_first_regex()]. An empty match has `end` one less
#'   than `start`. `NA` where there is no match, or the group took no part in
#'   it.
#'   - `par_locate_all()`: a list as long as `x`. Each element is such a
#'   matrix with a row per match, no rows if none, or one row of `NA` where
#'   `x` or `pattern` is `NA`.
#'
#' @export
#'
#' @examples
#' x <- c("born 1999 in Oslo", "no year", NA)
#' par_extract(x, "[0-9]{4}")
#' par_extract(x, "born ([0-9]+)", group = 1)
#' par_extract(x, "born ([0-9]+) in (\\w+)", group = 1:2)
#' par_extract_all(c("#rstats and #rust", "none", NA), "#(\\w+)", group = 1)
#' par_locate(x, "[0-9]{4}")
#' par_locate_all(x, "[a-z]+")
#' par_replace(x, "[0-9]", "#")
#' par_replace_all(x, "[0-9]", "#")
#' par_replace_all("Smith, John", "(\\w+), (\\w+)", "$2 $1")
par_extract <- function(
  x,
  pattern,
  group = 0L,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
) {
  if (length(group) > 1L && is.factor(x)) {
    # A matrix can't be indexed by the levels; the names go, as below.
    x <- as.character(x)
  }
  if (length(group) > 1L) {
    # One column per group.
    out <- run_extract(par_extract_rs, x, pattern, group, fixed, nthreads, TRUE)
    dim(out) <- c(length(x), length(group))
    rownames(out) <- names(x)
    return(out)
  }
  out <- run_extract(par_extract_rs, x, pattern, group, fixed, nthreads)
  # As regmatches() keeps them, except on a factor, where as.character()
  # drops them.
  names(out) <- if (!is.factor(x)) names(x)
  out
}

#' @rdname par_extract
#' @export
par_extract_all <- function(
  x,
  pattern,
  group = 0L,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
) {
  out <- run_extract(par_extract_all_rs, x, pattern, group, fixed, nthreads)
  names(out) <- names(x) # as regmatches() keeps them
  out
}

#' @rdname par_extract
#' @export
par_locate <- function(
  x,
  pattern,
  group = 0L,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
) {
  if (is.factor(x)) {
    # A matrix can't be indexed by the levels, and regexpr() drops the names.
    x <- as.character(x)
  }
  out <- run_extract(par_locate_rs, x, pattern, group, fixed, nthreads)
  dim(out) <- c(length(x), 2L)
  dimnames(out) <- list(names(x), c("start", "end"))
  out
}

#' @rdname par_extract
#' @export
par_locate_all <- function(
  x,
  pattern,
  group = 0L,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
) {
  if (is.factor(x)) {
    x <- as.character(x) # as in par_locate(); gregexpr() drops the names
  }
  out <- run_extract(par_locate_all_rs, x, pattern, group, fixed, nthreads)
  names(out) <- names(x)
  out
}

#' @rdname par_extract
#' @export
par_replace <- function(
  x,
  pattern,
  replacement,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
) {
  run_replace(x, pattern, replacement, fixed, FALSE, nthreads)
}

#' @rdname par_extract
#' @export
par_replace_all <- function(
  x,
  pattern,
  replacement,
  fixed = FALSE,
  nthreads = getOption("parvenu.threads", 0L)
) {
  run_replace(x, pattern, replacement, fixed, TRUE, nthreads)
}

# Checks `group`, one number or several if `many`, and calls `rs`,
# par_extract_rs() or the like.
run_extract <- function(rs, x, pattern, group, fixed, nthreads, many = FALSE) {
  ok <- is.numeric(group) &&
    (length(group) == 1L || (many && length(group) > 1L)) &&
    !anyNA(group) &&
    all(group >= 0 & group <= .Machine$integer.max & group == trunc(group))
  if (!ok && many) {
    stop("`group` must be non-negative whole numbers.")
  }
  if (!ok) {
    stop("`group` must be a single non-negative whole number.")
  }
  group <- as.integer(group)
  # run_pattern() doesn't know `group`, so it's bound here.
  rs_group <- function(x, pattern, fixed, nthreads) {
    rs(x, pattern, group, fixed, nthreads)
  }
  run_pattern(rs_group, x, pattern, fixed, nthreads)
}

# Checks `replacement` and replaces every match if `all`, else the first.
run_replace <- function(x, pattern, replacement, fixed, all, nthreads) {
  if (
    !is.character(replacement) ||
      length(replacement) != 1L ||
      is.na(replacement)
  ) {
    stop("`replacement` must be a string.")
  }
  replacement <- enc2utf8(replacement)
  # Binds `replacement` and `all` for run_pattern().
  rs <- function(x, pattern, fixed, nthreads) {
    par_replace_rs(x, pattern, replacement, fixed, all, nthreads)
  }
  out <- run_pattern(rs, x, pattern, fixed, nthreads)
  # As sub() and gsub() keep them, except on a factor.
  names(out) <- if (!is.factor(x)) names(x)
  out
}
