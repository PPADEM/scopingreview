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
