#' @keywords internal
"_PACKAGE"

#' @importFrom dplyr %>% bind_rows coalesce distinct filter first group_by
#'   mutate select summarise
#' @importFrom openalexR oa_fetch
#' @importFrom purrr %||% map_chr map_dfr
#' @importFrom rscopus scopus_search set_api_key
#' @importFrom stats na.omit
#' @importFrom stringdist stringdistmatrix
#' @importFrom stringr str_detect str_extract str_remove str_replace_all
#'   str_split str_trim
#' @importFrom tibble tibble
#' @importFrom utils write.csv
NULL

# Column names used inside dplyr verbs, declared to silence R CMD check notes
utils::globalVariables(c(
  ".", "abstract", "authors", "authorships", "cited_by_count", "citations",
  "clean_doi_key", "database", "display_name", "doi", "dup_group", "id",
  "journal", "norm_title", "openalex_id", "publication_year", "query_category",
  "scopus_id", "search_date", "search_query", "source_display_name", "title"
))
