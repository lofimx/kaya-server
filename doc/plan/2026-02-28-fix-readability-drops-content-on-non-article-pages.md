# Fix: readability drops content on non-article webpages

## Problem

When Kaya Server caches a bookmarked webpage and extracts plaintext for full-text
search via `ExtractPlaintextBookmarkJob`, the `ruby-readability` gem fails to extract
meaningful content from non-article web pages.

**Reproduction URL:** `https://bort.likes.it.com/moment/hPpWbvcHWe`

The page contains "Costco is my paradise" in an Activity Notes section and a `#costco`
hashtag, but `ruby-readability` only extracts the `<h1>` title ("I ride bikes too") and
a timestamp ("some weeks ago"), discarding all other content.

### Root Cause

`ruby-readability` uses heuristics to find the "main article content" of a page. When a
page has a lot of structural HTML (SVGs, data attributes, map configs, stats grids) but
only short meaningful text content, readability's scoring algorithm picks the wrong
content block.

## Fix

Two-path extraction in `ExtractPlaintextBookmarkJob`:

1. **Article path** (readability): used when `ArticleFilters::ArticleUrlFilter` or
   `ArticleFilters::ArticleHtmlFilter` detects the page is an article (known news domain,
   CMS generator tag, `og:type=article`, or Schema.org Article JSON-LD).
2. **Default path** (Nokogiri body text): used for all other pages. Strips `<script>`,
   `<style>`, `<noscript>` tags then extracts all visible text from `<body>`.

## Files Changed

- `app/models/article_filters/article_url_filter.rb` - new: URL-based article detection
- `app/models/article_filters/article_html_filter.rb` - new: HTML-based article detection
- `app/jobs/extract_plaintext_bookmark_job.rb` - modified: two-path extraction strategy
- `test/models/article_filters/article_url_filter_test.rb` - new: 13 unit tests
- `test/models/article_filters/article_html_filter_test.rb` - new: 18 unit tests
- `test/jobs/extract_plaintext_bookmark_job_test.rb` - existing failing test now passes
- `test/fixtures/files/non_article_page.html` - fixture: real non-article page HTML

## Test Plan

- [x] Write failing test with realistic non-article HTML that contains searchable words
- [x] Implement `ArticleFilters::ArticleUrlFilter` with ~40 news domains
- [x] Implement `ArticleFilters::ArticleHtmlFilter` with generator/OG/JSON-LD detection
- [x] Implement two-path extraction in `ExtractPlaintextBookmarkJob`
- [x] Verify previously failing test passes
- [x] Run full test suite: `rake test`
