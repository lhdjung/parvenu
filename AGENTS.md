# Notes for agents

## Scope

parvenu is a collection of fast, multithreaded utilities for large vectors,
with no R package dependencies, in two families:

- Base R functions that give base R's results, named `par_` plus the base
  name. Results identical to base are the promise, and tests compare
  against base.
- Text search with Rust's regex and aho-corasick crates, named `par_` plus
  a stringr verb. These can't give base's results, since the syntax is
  Rust's, so their docs say where they differ.

The text family is where threads pay off most: search is bound by the CPU,
where hashing numbers is bound by memory and collapse is already close to
that limit. Building R strings happens on R's thread only, so functions
that return new strings gain less than those that return positions or
counts.

A function belongs here if it is useful in itself and clearly beats base.
It doesn't need to beat collapse, stringi, or other packages by a wide
margin: if they tie or narrowly win, the function is still worth having.
Cover every common use within a family, so users of one family don't need
another package for the rest of it. Don't remove a function for a thin
margin over other packages.

A simple R version is fine where it is good enough; Rust is for where it
pays off. Measure against the fastest packages and report the numbers
honestly, but don't let them veto a good function.

## PLAN.md

PLAN.md is a working record, not a set of rules. Much of it was written
before any parvenu function, so it doesn't always reflect how fast the
package is. Revise it when it stands in the way of a good feature,
rather than following it to the letter.

## Formatting

R code is formatted with air, which indents by 2 spaces. After editing R
files from the shell (heredocs, sed), run `air format` on them: the
pre-commit hook rejects staged R files that air would change.

## README figures

README plots are not committed to `main`, so re-knitting doesn't add
figures to the history. After knitting, replace the `figures` branch with a
single commit, using the recipe in the setup chunk of README.Rmd. Don't
commit the README plots (`man/figures/README-*`) to `main`, and don't keep
a history on `figures`. The logo in `man/figures/` does belong on `main`.

## CI status

CI passed on all four jobs at c77ede8 (2026-10-22), after Ubuntu failures
from glibc's handling of times that don't exist. The commits after it
were tested only on macOS and haven't been pushed, to save CI minutes
while more fixes may come. Linux and Windows differ from macOS in ways
local tests miss, so expect the next push to need watching: check each
job with `gh run view <id>`.
