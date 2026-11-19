# Interpolate linearly, in parallel

Returns the same as base
[`approx()`](https://rdrr.io/r/stats/approxfun.html): interpolates
between the points `x` and `y` at each of `xout`. Each point gets a
binary search, on several threads.

## Usage

``` r
par_approx(
  x,
  y = NULL,
  xout,
  method = "linear",
  n = 50,
  yleft,
  yright,
  rule = 1,
  f = 0,
  ties = mean,
  na.rm = TRUE,
  nthreads = getOption("parvenu.threads", 0L)
)
```

## Arguments

- x, y:

  numeric vectors giving the coordinates of the points to be
  interpolated. Alternatively a single plotting structure can be
  specified: see
  [`xy.coords`](https://rdrr.io/r/grDevices/xy.coords.html).

- xout:

  an optional set of numeric values specifying where interpolation is to
  take place.

- method:

  specifies the interpolation method to be used. Choices are `"linear"`
  or `"constant"`.

- n:

  If `xout` is not specified, interpolation takes place at `n` equally
  spaced points spanning the interval \[`min(x)`, `max(x)`\].

- yleft:

  the value to be returned when input `x` values are less than `min(x)`.
  The default is defined by the value of `rule` given below.

- yright:

  the value to be returned when input `x` values are greater than
  `max(x)`. The default is defined by the value of `rule` given below.

- rule:

  an integer (of length 1 or 2) describing how interpolation is to take
  place outside the interval \[`min(x)`, `max(x)`\]. If `rule` is `1`
  then `NA`s are returned for such points and if it is `2`, the value at
  the closest data extreme is used. Use, e.g., `rule = 2:1`, if the left
  and right side extrapolation should differ.

- f:

  for `method = "constant"` a number between 0 and 1 inclusive,
  indicating a compromise between left- and right-continuous step
  functions. If `y0` and `y1` are the values to the left and right of
  the point then the value is `y0` if `f == 0`, `y1` if `f == 1`, and
  ` y0*(1-f)+y1*f` for intermediate values. In this way the result is
  right-continuous for `f == 0` and left-continuous for `f == 1`, even
  for non-finite `y` values.

- ties:

  handling of tied `x` values. The string `"ordered"` or a function (or
  the name of a function) taking a single vector argument and returning
  a single number or a [`list`](https://rdrr.io/r/base/list.html) of
  both, e.g., `list("ordered", mean)`, see ‘Details’.

- na.rm:

  logical specifying how missing values
  ([`NA`](https://rdrr.io/r/base/NA.html)'s) should be handled. Setting
  `na.rm=FALSE` will propagate `NA`'s in `y` to the interpolated values,
  also depending on the `rule` set. Note that in this case, `NA`'s in
  `x` are invalid, see also the examples.

- nthreads:

  A whole number: the max number of threads to use. `0` means the
  `RAYON_NUM_THREADS` environment variable, or else all cores. The
  default is the `parvenu.threads` option, or `0` if that isn't set.
  Inputs too small to keep that many threads busy get fewer, and more
  threads than cores count as all cores.

## Value

As [`approx()`](https://rdrr.io/r/stats/approxfun.html): a list of `x`,
the points `xout`, and `y`, the values there.

## Details

Computed in Rust when `xout` has at least 1e4 numbers and
`na.rm = TRUE`. The points are first prepared by base
[`approxfun()`](https://rdrr.io/r/stats/approxfun.html), which also
checks the arguments. Anything else goes to
[`approx()`](https://rdrr.io/r/stats/approxfun.html).

## Examples

``` r
par_approx(c(1, 2, 4), c(10, 20, 0), xout = c(1.5, 3, 5))
#> $x
#> [1] 1.5 3.0 5.0
#> 
#> $y
#> [1] 15 10 NA
#> 
par_approx(c(1, 2, 4), c(10, 20, 0), xout = c(1.5, 3, 5), rule = 2)
#> $x
#> [1] 1.5 3.0 5.0
#> 
#> $y
#> [1] 15 10  0
#> 
```
