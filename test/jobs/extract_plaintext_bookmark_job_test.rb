require "test_helper"

class ExtractPlaintextBookmarkJobTest < ActiveJob::TestCase
  test "extracts plaintext from cached bookmark HTML" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-example.url")
    bookmark = create(:bookmark, anga: anga, url: "https://example.com", cached_at: Time.current)
    bookmark.html_file.attach(
      io: StringIO.new("<html><body><h1>Article Title</h1><p>This is the main content of the article with important information.</p></body></html>"),
      filename: "index.html",
      content_type: "text/html"
    )

    ExtractPlaintextBookmarkJob.perform_now(bookmark.id)

    anga.reload
    assert anga.text.present?
    assert anga.text.extracted?
    assert_equal "bookmark", anga.text.source_type
    assert anga.text.file.attached?
    assert_equal "2024-01-01T120000-example.md", anga.text.text_filename

    content = anga.text.file.download
    assert content.present?
  end

  test "does nothing for non-existent bookmark" do
    assert_nothing_raised do
      ExtractPlaintextBookmarkJob.perform_now(SecureRandom.uuid)
    end
  end

  test "does nothing for uncached bookmark" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-uncached.url")
    create(:bookmark, anga: anga, url: "https://example.com") # not cached

    ExtractPlaintextBookmarkJob.perform_now(anga.bookmark.id)

    anga.reload
    assert_nil anga.text
  end

  test "records error on extraction failure" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-broken.url")
    bookmark = create(:bookmark, anga: anga, url: "https://example.com", cached_at: Time.current)
    # Attach invalid content that will cause readability to produce empty content
    bookmark.html_file.attach(
      io: StringIO.new(""),
      filename: "index.html",
      content_type: "text/html"
    )

    ExtractPlaintextBookmarkJob.perform_now(bookmark.id)

    anga.reload
    assert anga.text.present?
    assert_not anga.text.extracted?
    assert anga.text.extract_error.present?
  end

  test "updates existing text record on re-extraction" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-retry.url")
    bookmark = create(:bookmark, anga: anga, url: "https://example.com", cached_at: Time.current)

    # Create an existing failed text record
    anga.create_text!(source_type: "bookmark", extract_error: "Previous failure")

    bookmark.html_file.attach(
      io: StringIO.new("<html><body><p>Retried content that should now work properly.</p></body></html>"),
      filename: "index.html",
      content_type: "text/html"
    )

    ExtractPlaintextBookmarkJob.perform_now(bookmark.id)

    anga.reload
    assert anga.text.extracted?
    assert_nil anga.text.extract_error
  end
end
