test_that("NULL plus a rate-limit warning is retried", {
  calls <- 0
  local_mocked_bindings(
    oa_fetch = function(...) {
      calls <<- calls + 1
      if (calls < 2) {
        warning("Rate limit exceeded")
        return(NULL)
      }
      list()
    },
    .package = "scopingreview"
  )
  res <- suppressWarnings(suppressMessages(
    scopingreview:::oa_fetch_retry(page = 1, backoff = c(0, 0))
  ))
  expect_equal(calls, 2)
  expect_equal(nrow(res), 0)
})

test_that("NULL plus 'No records found' returns empty without retrying", {
  calls <- 0
  local_mocked_bindings(
    oa_fetch = function(...) {
      calls <<- calls + 1
      warning("No records found!")
      NULL
    },
    .package = "scopingreview"
  )
  res <- scopingreview:::oa_fetch_retry(page = 1)
  expect_equal(calls, 1)
  expect_equal(nrow(res), 0)
})

test_that("exhausted retries count as a failure", {
  local_mocked_bindings(
    oa_fetch = function(...) stop("429 Too Many Requests"),
    .package = "scopingreview"
  )
  state <- scopingreview:::.run_state
  state$oa_failed <- 0L
  suppressMessages(scopingreview:::oa_fetch_retry(page = 1, max_retries = 2, backoff = c(0, 0)))
  expect_equal(state$oa_failed, 1L)
})

test_that("a timeout is retried and the next success is returned", {
  calls <- 0
  local_mocked_bindings(
    oa_fetch = function(...) {
      calls <<- calls + 1
      if (calls == 1) {
        stop("Timeout was reached [api.openalex.org]: Operation timed out after 30001 milliseconds with 0 bytes received")
      }
      list(list(id = "W1"))
    },
    oa2df = function(...) tibble::tibble(id = "W1"),
    .package = "scopingreview"
  )
  state <- scopingreview:::.run_state
  state$oa_failed <- 0L
  res <- suppressMessages(
    scopingreview:::oa_fetch_retry(page = 1, backoff = c(0, 0))
  )
  expect_equal(calls, 2)
  expect_equal(res$id, "W1")
  expect_equal(state$oa_failed, 0L)
})

test_that("the timeout argument is passed through to oa_fetch()", {
  seen <- NULL
  local_mocked_bindings(
    oa_fetch = function(..., timeout) {
      seen <<- timeout
      list()
    },
    .package = "scopingreview"
  )
  scopingreview:::oa_fetch_retry(page = 1, timeout = 99)
  expect_equal(seen, 99)
})

test_that("five consecutive timeouts return NULL and count as a failure", {
  calls <- 0
  local_mocked_bindings(
    oa_fetch = function(...) {
      calls <<- calls + 1
      stop("Timeout was reached [api.openalex.org]")
    },
    .package = "scopingreview"
  )
  state <- scopingreview:::.run_state
  state$oa_failed <- 0L
  res <- suppressMessages(
    scopingreview:::oa_fetch_retry(page = 1, max_retries = 5, backoff = 0)
  )
  expect_null(res)
  expect_equal(calls, 5)
  expect_equal(state$oa_failed, 1L)
})

test_that("a non-retryable error returns NULL without retrying", {
  calls <- 0
  local_mocked_bindings(
    oa_fetch = function(...) {
      calls <<- calls + 1
      stop("OpenAlex API request failed [400]")
    },
    .package = "scopingreview"
  )
  state <- scopingreview:::.run_state
  state$oa_failed <- 0L
  res <- suppressMessages(scopingreview:::oa_fetch_retry(page = 1))
  expect_null(res)
  expect_equal(calls, 1)
  expect_equal(state$oa_failed, 1L)
})

test_that("'No records found' still returns an empty tibble, not NULL", {
  local_mocked_bindings(
    oa_fetch = function(...) {
      warning("No records found!")
      NULL
    },
    .package = "scopingreview"
  )
  res <- scopingreview:::oa_fetch_retry(page = 1)
  expect_false(is.null(res))
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 0)
})

test_that("oa_fetch_pages() keeps earlier pages and warns when a page fails", {
  pages_requested <- integer()
  local_mocked_bindings(
    oa_fetch_retry = function(..., page) {
      pages_requested <<- c(pages_requested, page)
      if (page == 3) {
        return(NULL)
      }
      tibble::tibble(id = paste0("W", page, "_", 1:2))
    },
    oa_options = function(...) list(),
    .package = "scopingreview"
  )
  expect_warning(
    res <- scopingreview:::oa_fetch_pages(
      max_pages = 5,
      oa_key = "",
      per_page = 2,
      pause_sec = 0
    ),
    "stopped early at page 3"
  )
  expect_equal(pages_requested, 1:3)
  expect_equal(nrow(res), 4)
  expect_equal(res$id, c("W1_1", "W1_2", "W2_1", "W2_2"))
})

test_that("oa_fetch_pages() stops quietly on a genuinely empty page", {
  local_mocked_bindings(
    oa_fetch_retry = function(..., page) {
      if (page == 2) {
        return(tibble::tibble())
      }
      tibble::tibble(id = paste0("W", page, "_", 1:2))
    },
    oa_options = function(...) list(),
    .package = "scopingreview"
  )
  expect_no_warning(
    res <- scopingreview:::oa_fetch_pages(
      max_pages = 5,
      oa_key = "",
      per_page = 2,
      pause_sec = 0
    )
  )
  expect_equal(nrow(res), 2)
})
