# CRAN allows at most 2 cores. Elsewhere, use all of them, so the tests
# also split inputs into many chunks.
if (!identical(Sys.getenv("NOT_CRAN"), "true")) {
  withr::local_options(
    parvenu.threads = 2,
    .local_envir = testthat::teardown_env()
  )
}
