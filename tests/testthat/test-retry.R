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
