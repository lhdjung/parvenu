# Notes for agents

## Scope

parvenu is a collection of fast, multithreaded utilities for large vectors
that give base R's results, with no R package dependencies. A function
belongs here if it is useful in itself and clearly beats base. It doesn't
need to beat collapse or other packages by a wide margin: if collapse ties
or narrowly wins, the function is still worth having for anyone who doesn't
want another dependency.

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
commit `man/figures/` to `main`, and don't keep a history on `figures`.

## CI status

CI passed on all four jobs at c77ede8 (2026-10-22), after Ubuntu failures
from glibc's handling of times that don't exist. The commits after it
were tested only on macOS and haven't been pushed, to save CI minutes
while more fixes may come. Linux and Windows differ from macOS in ways
local tests miss, so expect the next push to need watching: check each
job with `gh run view <id>`.
