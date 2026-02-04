# Plan: Replace 'cache' with 'words' in sync.rb

## Date
2026-02-04

## Background
The sync.rb script currently syncs three directories:
- `anga` - bookmarks, notes, PDFs, images, and other files
- `meta` - human tags and metadata for anga records (TOML files)
- `cache` - cached webpage content for bookmarks (download-only)

However, per ADR-0003-sync.md, local apps do not require a complete cache of every bookmarked webpage. Instead, they should sync `/words` which contains extracted text content that is smaller and more useful for local apps.

## Current State
- Lines 10: Comment mentions `~/.kaya/cache/`
- Lines 25: `CACHE_DIR` constant defined
- Lines 33-37: Stats tracking includes `cache`
- Line 50: `sync_cache` called
- Lines 73: `CACHE_DIR` directory created
- Lines 274-385: Cache sync implementation (download-only)
- Lines 457-479: Print summary includes cache stats

## Proposed Changes

### 1. Update Constants and Directories
- Line 10: Update comment from `cache/ - cached webpage content` to `words/ - extracted text content for bookmarks`
- Line 25: Change `CACHE_DIR` to `WORDS_DIR`
- Line 73: Change `FileUtils.mkdir_p(CACHE_DIR)` to `FileUtils.mkdir_p(WORDS_DIR)`

### 2. Update Stats Tracking
- Lines 33-37: Replace `cache:` with `words:` in stats hash

### 3. Update Method Names and Calls
- Line 50: Change `sync_cache` to `sync_words`
- Lines 274-385: Rename `sync_cache` to `sync_words` and all internal methods from `cache` to `words`
  - `fetch_server_cache_bookmarks` -> `fetch_server_words`
  - `fetch_local_cache_bookmarks` -> `fetch_local_words`
  - `fetch_server_cache_files` -> `fetch_word_files`
  - `fetch_local_cache_files` -> `fetch_local_word_files`
  - `download_cache_bookmarks` -> `download_words`
  - `download_cache_bookmark` -> `download_word`
  - `sync_existing_cache_bookmarks` -> `sync_existing_words`
  - `download_cache_file` -> `download_word_file`

### 4. Update API Endpoints
- Line 299: Change `/cache` to `/words`
- Line 320: Change `/cache/#{bookmark}` to `/words/#{anga}`
- Line 370: Change `/cache/#{bookmark}/#{filename}` to `/words/#{anga}/#{filename}`

### 5. Update Log Messages and Comments
- Line 279: Update log message from "Cache (bookmark webpage cache)" to "Words (extracted text)"
- Replace "cache" with "words" in all log messages
- Line 476: Update summary header from "Cache (bookmark webpages)" to "Words (extracted text)"

### 6. Update Summary Printing
- Lines 457-479: Replace all `:cache` references with `:words`

## API Structure (from ADR-0003-sync.md)
```
~/.kaya/words/ <=> /api/v1/:user_email/words
~/.kaya/words/{anga} <=> /api/v1/:user_email/words/:anga
~/.kaya/words/{anga}/{filename} <=> /api/v1/:user_email/words/:anga/:filename
```

This maintains the same two-level structure as cache (anga directory -> files within), so the implementation pattern remains similar.

## Testing
After changes, verify:
1. Script runs without syntax errors
2. Correctly calls `/api/v1/:user_email/words` endpoint
3. Downloads words to `~/.kaya/words/` directory
4. Summary shows words statistics instead of cache statistics

## Questions
None - the structure is clear from ADR-0003-sync.md and the current implementation pattern.

## Additional Changes Made

During implementation, additional changes were made based on user request:

### Prompt for URL Instead of Defaulting
- Restored `DEFAULT_URL = "https://kaya.town"` constant
- Updated `prompt_credentials` to prompt for server URL with default value
- Added confirmation before syncing when URL not provided via command line
- If user declines confirmation, prompts for URL again with current value pre-filled

### Retain URL-Encoded Filenames Locally
The script now retains URL-encoded filenames locally to avoid creating files with special characters (spaces, etc.) that are incompatible with URLs:

**Changes:**
- Removed `URI.decode_www_form_component` from all server file list fetching methods:
  - `fetch_server_anga_files` (line 106)
  - `fetch_server_meta_files` (line 203)
  - `fetch_server_words` (line 304)
  - `fetch_word_files` (line 325)
- Local files are now read as-is without decoding
- Local filenames are URL-encoded before comparison with server filenames
- Upload methods now URL-encode filenames before sending to server
- Download methods use URL-encoded filenames as-is for local file creation

This ensures:
1. Local files never contain spaces or URL-incompatible characters
2. Server filenames (already URL-encoded in API output) are used directly
3. Uploads correctly encode filenames before sending
4. The sync process works consistently with URL-encoded filenames in both directions