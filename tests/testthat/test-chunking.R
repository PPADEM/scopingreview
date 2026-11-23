query_len <- function(chunk) {
  blocks <- c(chunk$search_topics, if (!is.null(chunk$geo_terms)) list(chunk$geo_terms))
  strs <- vapply(blocks, function(b) paste0("(", paste(sprintf('"%s"', b), collapse = " OR "), ")"), "")
  nchar(paste(strs, collapse = " AND "))
}

make_terms <- function(prefix, n, width = 20) {
  sprintf("%s%s", prefix, formatC(seq_len(n), width = width, flag = "0"))
}

test_that("every term is kept and every query fits", {
  topics <- list(a = make_terms("alpha", 40), b = make_terms("beta", 30), c = make_terms("gamma", 10))
  chunks <- chunk_search_topics(topics, geo_terms = make_terms("geo", 20), max_query_chars = 1400)
  expect_gt(length(chunks), 1)
  for (nm in names(topics)) {
    seen <- unique(unlist(lapply(chunks, function(ch) ch$search_topics[[nm]])))
    expect_setequal(seen, topics[[nm]])
  }
  geo_seen <- unique(unlist(lapply(chunks, `[[`, "geo_terms")))
  expect_setequal(geo_seen, make_terms("geo", 20))
  expect_true(all(vapply(chunks, query_len, numeric(1)) <= 1400))
})

test_that("a query already under the limit is not split", {
  chunks <- chunk_search_topics(list(a = c("x", "y"), b = c("z")), max_query_chars = 1400)
  expect_length(chunks, 1)
})

test_that("a Run 2-like query (~1,570 chars) splits into 2 queries", {
  topics <- list(a = make_terms("alpha", 75, 14), b = make_terms("beta", 6, 14))
  full <- query_len(list(search_topics = topics, geo_terms = NULL))
  expect_gt(full, 1400)
  expect_length(chunk_search_topics(topics, max_query_chars = 1400), 2)
})

test_that("a single over-long term errors clearly", {
  expect_error(
    chunk_search_topics(list(a = strrep("x", 2000), b = "y"), max_query_chars = 1400),
    "longer than max_query_chars"
  )
})

test_that("max_query_chars = NULL leaves the query unchanged", {
  topics <- list(a = make_terms("alpha", 200))
  chunks <- chunk_search_topics(topics, geo_terms = c("Africa"), max_query_chars = NULL)
  expect_length(chunks, 1)
  expect_identical(chunks[[1]]$search_topics, topics)
  expect_identical(chunks[[1]]$geo_terms, "Africa")
})
