# TODO

Nothing open.

## Done

- **bit64 in the docs of `par_factor()` and `par_table()`.** The source
  never named bit64: roxygen resolved the bare links `[factor()]` and
  `[table()]` to bit64, which exports those names too, and did the same for
  `rank()`, `union()`, `intersect()`, and `setdiff()`. The links now name
  base, as in `` [`factor()`][base::factor] ``. The description now says
  that both are drop-in replacements, and names the only differences:
  `nthreads`, and `nmax`, which `par_factor()` ignores. `...` of
  `par_table()` had inherited base `factor()`'s text about `ordered()`, and
  now has its own.
- **Snake case.** Only `R/par-factor.R` had other names, copied from the
  source of base's `factor()` and `table()`: `matchAsChar`, `doNA`,
  `fact.a`, and so on. They are snake case now, and `list.names()` is
  `list_names()`. Arguments such as `fromLast`, `useNA`, and `na.rm` keep
  base's names, so the functions stay drop-in.
- **Blank lines and comments.** Every file in `R/` now separates its steps
  with blank lines, and has short comments where a step isn't obvious.
