# Capture the arguments fetch_openalex_data() passes to oa_fetch_pages()
capture_oa_args <- function(topic_operator, openalex_scope = NULL, topics = NULL) {
  seen <- NULL
  local_mocked_bindings(
    oa_fetch_pages = function(max_pages, oa_key, ...) {
      seen <<- list(...)
      tibble::tibble()
    }
  )
  withr::local_envvar(OPENALEX_KEY = "test-key")
  args <- list(
    search_topics = topics %||% list(party = c("political party", "party decline")),
    geo_terms = c("Africa", "Ghana"),
    start_year = 2010,
    topic_operator = topic_operator,
    max_pages = 1
  )
  if (!is.null(openalex_scope)) args$openalex_scope <- openalex_scope
  capture.output(suppressMessages(do.call(fetch_openalex_data, args)))
  seen
}

EXACT <- "title_abstract_keywords.search.exact"

test_that("default scope uses the exact title/abstract/keywords filter in multi mode", {
  seen <- capture_oa_args("multi")
  expect_true(EXACT %in% names(seen))
  expect_false(any(c("search", "title_and_abstract.search") %in% names(seen)))
  expect_match(seen[[EXACT]], '"political party"', fixed = TRUE)
  expect_equal(seen$from_publication_date, "2010-01-01")
})

test_that("default scope uses the exact filter in per-category mode", {
  seen <- capture_oa_args("OR")
  expect_true(EXACT %in% names(seen))
  expect_false(any(c("search", "title_and_abstract.search") %in% names(seen)))
})

test_that("title_abstract scope still passes the stemmed title_and_abstract.search filter", {
  for (op in c("multi", "OR")) {
    seen <- capture_oa_args(op, openalex_scope = "title_abstract")
    expect_true("title_and_abstract.search" %in% names(seen))
    expect_false(any(c("search", EXACT) %in% names(seen)))
  }
})

test_that("fulltext scope still passes search in both modes", {
  for (op in c("multi", "OR")) {
    seen <- capture_oa_args(op, openalex_scope = "fulltext")
    expect_true("search" %in% names(seen))
    expect_false(any(c("title_and_abstract.search", EXACT) %in% names(seen)))
  }
})

test_that("an unknown scope is rejected", {
  expect_error(capture_oa_args("multi", openalex_scope = "abstract"), "should be one of")
})

test_that("commas are removed from filter values but not from fulltext search", {
  topics <- list(party = c("party, decline"))
  seen <- capture_oa_args("multi", topics = topics)
  expect_false(grepl(",", seen[[EXACT]], fixed = TRUE))
  seen <- capture_oa_args("multi", openalex_scope = "title_abstract", topics = topics)
  expect_false(grepl(",", seen$title_and_abstract.search, fixed = TRUE))
  seen <- capture_oa_args("multi", openalex_scope = "fulltext", topics = topics)
  expect_match(seen$search, ",", fixed = TRUE)
})

test_that("search_query records which OpenAlex scope found each record", {
  fake <- tibble::tibble(
    id = "https://openalex.org/W1", title = "A paper", display_name = "A paper",
    source_display_name = "J", publication_year = 2020, doi = NA_character_,
    cited_by_count = 1, abstract = "x", authorships = list(NULL)
  )
  local_mocked_bindings(oa_fetch_pages = function(...) fake)
  withr::local_envvar(OPENALEX_KEY = "test-key")
  prefixes <- c(
    exact = "title_abstract_keywords.search.exact:",
    title_abstract = "title_and_abstract.search:",
    fulltext = "search:"
  )
  for (scope in names(prefixes)) {
    for (op in c("multi", "OR")) {
      capture.output(res <- fetch_openalex_data(
        list(party = "political party"), "Africa", 2010,
        topic_operator = op, max_pages = 1, openalex_scope = scope
      ))
      expect_true(all(startsWith(res$search_query, prefixes[[scope]])))
    }
  }
})

test_that("the summary flags a large imbalance between databases", {
  expect_match(scopingreview:::db_imbalance_note(9, 16895), "OpenAlex returned 1877x as many records as Scopus")
  expect_match(scopingreview:::db_imbalance_note(5000, 10), "^Scopus returned")
  expect_null(scopingreview:::db_imbalance_note(9, 500))
  expect_null(scopingreview:::db_imbalance_note(0, 16895))
})

test_that("run_scoping_review() warns about an imbalance and passes the scope through", {
  scope_seen <- NULL
  mk <- function(db, n) {
    tibble::tibble(
      database = db, query_category = "party", search_query = "q", search_date = "2026-01-01",
      scopus_id = if (db == "Scopus") as.character(seq_len(n)) else NA_character_,
      openalex_id = if (db == "OpenAlex") as.character(seq_len(n)) else NA_character_,
      title = sprintf("%s distinct title number %d", db, seq_len(n)), journal = "J",
      publication_year = 2020L, doi = NA_character_, citations = 0, abstract = "", authors = "A",
      target_journal = "N"
    )
  }
  local_mocked_bindings(
    fetch_scopus_data = function(...) mk("Scopus", 1),
    fetch_openalex_data = function(..., openalex_scope) {
      scope_seen <<- openalex_scope
      mk("OpenAlex", 150)
    },
    deduplicate_records = function(x) x
  )
  out <- withr::local_tempfile(fileext = ".csv")
  expect_warning(
    capture.output(run_scoping_review(list(party = "political party"), output_filename = out)),
    "OpenAlex returned 150x as many records as Scopus"
  )
  expect_equal(scope_seen, "exact")
})
