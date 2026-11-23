# scopingreview (development)

## New features
* `run_scoping_review()` gains `max_query_chars` (default 1400). In `"multi"` mode, term lists (and geographic terms) are split until every query fits OpenAlex's 1,500-character limit; all combinations are run, merged and deduplicated once. New exported `chunk_search_topics()` previews the split.
* The final banner now reports records and failed requests per database, and warns instead of reporting success when a database contributes nothing.

## Bug Fixes & API Resilience
* OpenAlex pages are fetched one at a time (1.1 s apart, capped at 50 pages), stopping on a short or empty page.
* Only the failed page is retried (5 attempts, 2/5/10 s back-off); "Rate limit exceeded" is treated as retryable, and an empty result with a warning is treated as a failure.
* Errors are no longer silently swallowed; empty pages are no longer retried; `api_key` is passed only when `OPENALEX_KEY` is set, with a message otherwise.
* OpenAlex timeouts and other transient network errors (DNS, connection resets, SSL, empty replies) are now retried, with a 120 s request timeout (was 30 s) and a 5/10/20/30/60 s back-off. Previously a timeout silently cut a query short.
* A page that cannot be fetched is no longer mistaken for the end of results: paging stops with a warning that the query is incomplete, keeping the pages already retrieved.
* openalexR's per-page progress messages are suppressed.
* Added testthat tests for query splitting and retry logic.

---

# scopingreview 0.2.0

## Bug Fixes & API Resilience
* **OpenAlex compatibility**: Fixed a critical failure where upstream schema changes in OpenAlex (adding `doi` inside `primary_location`) caused `openalexR` (<= 3.1.1) to crash with `Column name 'doi' must not be duplicated`. Queries now fetch via `output = "list"`, sanitize nested duplicate fields, and convert safely via `oa2df()`.
* **Scopus view authorization**: Added `scopus_view` parameter (defaulting to `"STANDARD"`) to `fetch_scopus_data()` and `run_scoping_review()`. If `"COMPLETE"` view is requested with an API key lacking institutional entitlement, the pipeline now logs an informative message and falls back gracefully to `"STANDARD"` instead of failing with HTTP 401 Unauthorized.
* **OpenAlex empty search handling**: Genuinely empty search results (signaled by `"No records found!"`) no longer trigger multiple redundant backoff retry sleep cycles.

## Packaging & Build Improvements
* **Portability & R CMD check**: Added `^docs$` and `^_extensions$` to `.Rbuildignore` so Quarto website assets and presentation extensions do not cause file path length or non-portable name warnings during package builds.
* **Transitive deduplication**: Refined Stage 2 fuzzy title deduplication to use union-find with path compression for consistent transitive grouping.

---

# scopingreview 0.1.0

* Initial release of the automated scoping literature review pipeline.
* Supports Boolean query generation across Elsevier Scopus and OpenAlex.
* 2-stage deduplication combining exact DOI matching and Jaro-Winkler fuzzy title distance.
* Target journal flagging against curated political science, public administration, and African studies journals.
