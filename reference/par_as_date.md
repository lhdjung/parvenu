# Parse dates and times, in parallel

Same results as base for strings, but much faster for large inputs:

- `par_as_date()` for
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html).

- `par_as_posixct()` for
  [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html).

Base R takes seconds to parse a million dates, on one thread.

## Usage

``` r
par_as_date(
  x,
  format,
  tryFormats = c("%Y-%m-%d", "%Y/%m/%d"),
  optional = FALSE,
  ...,
  nthreads = getOption("parvenu.threads", 0L)
)

par_as_posixct(
  x,
  tz = "",
  format,
  tryFormats = c("%Y-%m-%d %H:%M:%OS", "%Y/%m/%d %H:%M:%OS",
    "%Y-%m-%d %H:%M", "%Y/%m/%d %H:%M", "%Y-%m-%d", "%Y/%m/%d"),
  optional = FALSE,
  ...,
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x:

  A string vector, or a factor.

- format:

  a [`character`](https://rdrr.io/r/base/character.html) string. If not
  specified when converting from a character representation, it will try
  `tryFormats` one by one on the first non-`NA` element, and give an
  error if none works. Otherwise, the processing is via
  [`strptime()`](https://rdrr.io/r/base/strptime.html) whose help page
  describes available conversion specifications.

- tryFormats:

  [`character`](https://rdrr.io/r/base/character.html) vector of
  `format` strings to try if `format` is not specified.

- optional:

  [`logical`](https://rdrr.io/r/base/logical.html) indicating to return
  `NA` (instead of signalling an error) if the format guessing does not
  succeed.

- ...:

  Passed on to base R where it takes over.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

- tz:

  a time zone name.

## Value

As [`as.Date()`](https://rdrr.io/r/base/as.Date.html): a Date vector as
long as `x`, `NA` where a string doesn't parse. `par_as_posixct()`
returns a POSIXct vector instead, as
[`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) does.

## Details

Formats may use `%Y`, `%y`, `%m`, `%b`, `%d`, `%e`, `%j`, `%H`, `%I`
with `%p`, `%M`, `%S`, `%OS`, `%z` (an offset such as `+0530`), `%F`,
`%T`, and `%R`. `%B` and `%h` are read as `%b`: English month names,
full or abbreviated to three letters, in any case. This works where the
`LC_TIME` locale is C or English. A format needs a year, and a month and
day or a day of the year, as the default `tryFormats` have.

Strings are read as [`strptime()`](https://rdrr.io/r/base/strptime.html)
reads them, quirks included. Text after the format is ignored,
`"24:00:00"` is midnight of the next day, and `"2020-1-5"` is a date.

In UTC (`"UTC"`, `"GMT"`, or `""` in a session whose time zone is UTC),
the parse returns the times directly. In other time zones, base R's own
C code places the local times, so a time that doesn't exist there, or
occurs twice, comes out as in base. It places only the start and end of
each day without a change of clock, whose times then follow from them,
and every time of days with one. Where the times span more days than
there are times, base R reads them all, as it is faster there.

Factors are turned into strings first. Everything else goes to base R:

- other formats, or several formats in `format`

- month names in other locales

- inputs that aren't strings or factors, or fewer than 1e4 of them

- `tryFormats` with `%j` or `%z`

- spaces other than ASCII ones

- seconds written in hexadecimal, with more than 15 digits, or as
  `nan(...)`

- an input that no format fits, which base R reports.

## Examples

``` r
par_as_date(c("2024-02-29", "2024-02-30", NA))
#> [1] "2024-02-29" NA           NA          
par_as_date("05.03.2024", format = "%d.%m.%Y")
#> [1] "2024-03-05"
par_as_posixct(c("2024-03-05 14:30:00.25", "2024-03-05 24:00:00"), tz = "UTC")
#> [1] "2024-03-05 14:30:00 UTC" "2024-03-06 00:00:00 UTC"
par_as_posixct("5 Mar 2024 2:30 PM", format = "%d %b %Y %I:%M %p", tz = "UTC")
#> [1] "2024-03-05 14:30:00 UTC"
par_as_posixct("2024-03-05T14:30:00+0530", format = "%FT%T%z", tz = "UTC")
#> [1] "2024-03-05 09:00:00 UTC"
par_as_posixct("2024-03-05 14:30:00", tz = "Europe/Berlin")
#> [1] "2024-03-05 14:30:00 CET"
```
