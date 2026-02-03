# Full Text Search: Bookmarks and PDFs

## Summary

Implement the plaintext extraction and storage system described in ADR-0005, enabling faster full-text search for bookmarks and PDFs. This adds a `Text` model to store extracted plaintext, background jobs to perform extraction, updates search classes to use the pre-extracted text, and exposes three new API routes for client sync.

## References

- [ADR-0005: Full Text Search](../arch/adr-0005-full-text-search.md)
- [ADR-0003: Sync](../arch/adr-0003-sync.md)
- [PROMPTS.md, "Full Text Search: Bookmarks and PDFs"](../PROMPTS.md)

## New Dependencies

Add to Gemfile:

- `ruby-readability` — extracts readable content from HTML (like Mozilla Readability)
- `reverse_markdown` — converts HTML to Markdown

`pdf-reader` is already in the Gemfile.

---

## Step 1: Text Model and Migration

Create the `texts` table and model, following the same patterns as `Bookmark` and `Meta`.

**Migration: `CreateTexts`**

| Column        | Type      | Notes                              |
|---------------|-----------|------------------------------------|
| id            | string(36)| UUID primary key                   |
| anga_id       | string(36)| FK to angas, not null              |
| source_type   | string    | "bookmark" or "pdf", not null      |
| extracted_at  | datetime  | timestamp of successful extraction |
| extract_error | text      | error message if extraction failed |
| created_at    | datetime  |                                    |
| updated_at    | datetime  |                                    |

Index on `anga_id` (unique).

**Model: `Text` (`app/models/text.rb`)**

```ruby
class Text < ApplicationRecord
  before_create :generate_uuid

  belongs_to :anga

  has_one_attached :file

  validates :source_type, presence: true, inclusion: { in: %w[bookmark pdf] }

  def extracted?
    extracted_at.present? && file.attached?
  end

  def extract_failed?
    extract_error.present?
  end

  def extract_pending?
    !extracted? && !extract_failed?
  end

  # Returns the text filename for the API
  # Bookmarks: {anga_filename}.md
  # PDFs: {anga_filename}.txt
  def text_filename
    base = anga.filename
    case source_type
    when "bookmark"
      "#{File.basename(base, '.*')}.md"
    when "pdf"
      "#{File.basename(base, '.*')}.txt"
    end
  end

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end
end
```

**Anga model update:**

```ruby
has_one :text, dependent: :destroy
```

**Factory: `test/factories/texts.rb`**

---

## Step 2: ExtractPlaintextBookmarkJob

**File: `app/jobs/extract_plaintext_bookmark_job.rb`**

This job is enqueued at the end of `CacheBookmarkJob#perform`, after the bookmark is successfully cached.

**Logic:**

1. Find the `Bookmark` by ID; return early if not found or not cached.
2. Download the cached `html_file` from the bookmark.
3. Use `Readability::Document` (from `ruby-readability`) to extract the readable content from the HTML.
4. Use `ReverseMarkdown.convert` to convert the readable HTML to Markdown.
5. Create or find the `Text` record for this bookmark's `Anga`.
6. Attach the Markdown content as a `.md` file to `Text#file`.
7. Set `extracted_at` and clear any `extract_error`.
8. On failure, set `extract_error` on the `Text` record.

**CacheBookmarkJob update:**

```ruby
def perform(bookmark_id)
  bookmark = Bookmark.find_by(id: bookmark_id)
  return unless bookmark

  WebpageCacheService.new(bookmark).cache

  # Enqueue plaintext extraction after successful caching
  if bookmark.reload.cached?
    ExtractPlaintextBookmarkJob.perform_later(bookmark.id)
  end
end
```

---

## Step 3: ExtractPlaintextPdfJob

**File: `app/jobs/extract_plaintext_pdf_job.rb`**

This job is enqueued when a PDF anga is created. Since PDFs don't go through a bookmark setup flow, we trigger this from the `Anga` model's `after_create_commit` callback (similar to `setup_bookmark`).

**Logic:**

1. Find the `Anga` by ID; return early if not found or if file is not attached.
2. Download the PDF file from the anga.
3. Use `PDF::Reader` to extract text from all pages.
4. Create or find the `Text` record for this `Anga`.
5. Attach the plaintext content as a `.txt` file to `Text#file`.
6. Set `extracted_at` and clear any `extract_error`.
7. On failure, set `extract_error` on the `Text` record.

**Anga model update:**

```ruby
after_create_commit :setup_pdf_text, if: :pdf_file?

def pdf_file?
  FileType.new(filename).pdf?
end

private

def setup_pdf_text
  ExtractPlaintextPdfJob.perform_later(id)
end
```

---

## Step 4: Update Search Classes

### BookmarkSearch

Replace the current `extract_content` (which parses cached HTML on every search) with a lookup of the pre-extracted Markdown from the `Text` model:

```ruby
def extract_content
  text = @anga.text
  return nil unless text&.extracted? && text.file.attached?

  text.file.download.force_encoding("UTF-8")
rescue StandardError => e
  Rails.logger.warn("BookmarkSearch: Failed to read extracted text for #{@anga.filename}: #{e.message}")
  nil
end
```

### PdfSearch

Replace the current `extract_content` (which parses the PDF on every search) with a lookup of the pre-extracted text from the `Text` model:

```ruby
def extract_content
  text = @anga.text
  return nil unless text&.extracted? && text.file.attached?

  text.file.download.force_encoding("UTF-8")
rescue StandardError => e
  Rails.logger.warn("PdfSearch: Failed to read extracted text for #{@anga.filename}: #{e.message}")
  nil
end
```

Both search classes now share the same extraction pattern. If the `Text` record doesn't exist yet (extraction still pending), search falls back to returning no content, which means the anga won't appear in content-based search results until extraction completes. This is acceptable — the filename is still searchable.

### SearchService

Update the eager loading in `SearchService#search` to include `text`:

```ruby
@user.angas.includes(:file_attachment, :file_blob, :text).find_each do |anga|
```

---

## Step 5: Text API Controller

**File: `app/controllers/api/v1/text_controller.rb`**

Follow the same pattern as `CacheController`. All three routes are read-only (GET); text is generated server-side, not uploaded by clients.

### GET `/api/v1/:user_email/text`

Returns a `text/plain` list of anga directory names (URL-escaped) that have extracted text. One directory name per line.

### GET `/api/v1/:user_email/text/:anga`

Returns a `text/plain` list of text filenames for the given anga directory. Typically one file: e.g., `example.md` or `example.txt`.

### GET `/api/v1/:user_email/text/:anga/:filename`

Returns the actual plaintext file content with appropriate MIME type (`text/markdown` for `.md`, `text/plain` for `.txt`).

**Routes update (`config/routes.rb`):**

```ruby
# Text API for full-text search plaintext copies
get "text", to: "text#index", as: "text"
get "text/:anga", to: "text#show", as: "text_anga", constraints: { anga: /[^\/]+/ }
get "text/:anga/:filename", to: "text#file", as: "text_file", constraints: { anga: /[^\/]+/, filename: /[^\/]+/ }
```

---

## Step 6: Tests

### Unit Tests

- **`test/models/text_test.rb`** — validations, `extracted?`, `extract_failed?`, `extract_pending?`, `text_filename`
- **`test/jobs/extract_plaintext_bookmark_job_test.rb`** — successful extraction, missing bookmark, uncached bookmark, extraction error handling
- **`test/jobs/extract_plaintext_pdf_job_test.rb`** — successful extraction, missing anga, extraction error handling
- **`test/models/search/bookmark_search_test.rb`** — update existing tests to use `Text` model instead of raw HTML; add test for missing text record fallback
- **`test/models/search/pdf_search_test.rb`** — new tests mirroring bookmark search tests but for PDF text extraction
- **`test/jobs/cache_bookmark_job_test.rb`** — verify `ExtractPlaintextBookmarkJob` is enqueued after successful caching

### Controller Tests

- **`test/controllers/api/v1/text_controller_test.rb`** — index, show, file for both bookmark and PDF text; 404 cases; authentication

---

## Step 7: Backfill Existing Data

Create a rake task `text:extract_all` that iterates over all existing bookmarks and PDFs and enqueues the appropriate extraction jobs. This is a one-time operation for existing data.

---

## Ordering

1. Step 1 (Text model + migration)
2. Step 2 (ExtractPlaintextBookmarkJob + CacheBookmarkJob update)
3. Step 3 (ExtractPlaintextPdfJob + Anga model update)
4. Step 4 (Update search classes)
5. Step 5 (Text API controller + routes)
6. Step 6 (Tests — written alongside each step)
7. Step 7 (Backfill rake task)
