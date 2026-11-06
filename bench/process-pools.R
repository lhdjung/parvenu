# parvenu against base R run in parallel on pools of R processes: mizu
# (shared memory), mirai (sockets), and mirai with its arguments shared
# through mori; run after installing parvenu. All use all cores, and
# parvenu_1 shows how much of parvenu's lead remains on one. The pools
# start once, outside the timings, and the inputs are split into chunks
# outside the timings, so the pools' times include only moving the data,
# the map, and joining the chunks' results. The other arguments, such as
# match()'s table, are sent to mirai's daemons once per task, outside the
# timings too, as a session would for data it reuses; mizu gets them with
# every chunk. For mori, the times include share() of the chunks. The README
# gives the lower median of the two runs (8 and 32 chunks) for every row.
library(parvenu)
library(mizu)
library(mirai)
library(mori)
set.seed(1)
cores <- parallel::detectCores()

t0 <- Sys.time()
pool <- mizu_pool(n_workers = cores)
cat("Starting mizu with", cores, "workers:", format(Sys.time() - t0), "\n")
t0 <- Sys.time()
daemons(cores)
invisible(everywhere(NULL)[])
cat("Starting mirai with", cores, "daemons:", format(Sys.time() - t0), "\n")

join <- function(results) do.call(c, unname(results))
on_mizu <- function(chunks, f, args) {
  join(mizu_collect(do.call(mizu_map, c(list(pool, chunks, f), args))))
}
# `args` is preloaded on the daemons by everywhere(), below
apply_preloaded <- function(x, f) do.call(f, c(list(x), args))
on_mirai <- function(chunks, f) {
  join(mirai_map(chunks, apply_preloaded, .args = list(f = f))[])
}
on_mirai_mori <- function(chunks, f) {
  join(mirai_map(share(chunks), apply_preloaded, .args = list(f = f))[])
}
chunk <- function(x, k) {
  split(x, rep(seq_len(k), length.out = length(x)) |> sort())
}

words <- vapply(
  1:1e4,
  function(i) paste(sample(letters, 12, TRUE), collapse = ""),
  ""
)
strings <- paste(
  sample(words, 1e6, TRUE),
  sample(words, 1e6, TRUE),
  sample(1:999, 1e6, TRUE)
)
ints <- sample.int(1e8, 1e7, TRUE)
keys <- sample.int(1e8, 1e6)
dates <- format(as.Date("1990-01-01") + sample.int(15000, 1e6, TRUE))

tasks <- list(
  regex = list(
    x = strings,
    f = grepl,
    args = list(pattern = "[aeiou]{3}[0-9]", perl = TRUE),
    parvenu = function(...) par_detect(strings, "[aeiou]{3}[0-9]", ...)
  ),
  match = list(
    x = ints,
    f = match,
    args = list(table = keys),
    parvenu = function(...) par_match(ints, keys, ...)
  ),
  date = list(
    x = dates,
    f = as.Date,
    args = list(),
    parvenu = function(...) par_as_date(dates, ...)
  )
)

for (k in c(cores, 4 * cores)) {
  for (name in names(tasks)) {
    t <- tasks[[name]]
    chunks <- chunk(t$x, k)
    invisible(everywhere({}, args = t$args)[])
    cat("\n", name, "with", k, "chunks\n")
    # check = TRUE: every way gives the same result as base
    print(bench::mark(
      base = do.call(t$f, c(list(t$x), t$args)),
      mizu = on_mizu(chunks, t$f, t$args),
      mirai = on_mirai(chunks, t$f),
      mirai_mori = on_mirai_mori(chunks, t$f),
      parvenu_1 = t$parvenu(nthreads = 1),
      parvenu = t$parvenu(),
      min_iterations = 3,
      filter_gc = FALSE
    )[, c("expression", "median")])
  }
}

mizu_pool_stop(pool)
daemons(0)
cat("\n")
print(sessionInfo())
