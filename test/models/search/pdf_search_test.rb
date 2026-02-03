require "test_helper"

class Search::PdfSearchTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "returns no match when no text record exists" do
    anga = create(:anga, :pdf, user: @user, filename: "2024-01-01T120000-document.pdf")

    search = Search::PdfSearch.new(anga)
    result = search.search("testing")

    assert_not result.match?
    assert_equal 0.0, result.score
  end

  test "returns no match when text extraction is pending" do
    anga = create(:anga, :pdf, user: @user, filename: "2024-01-01T120000-document.pdf")
    create(:text, :pdf, anga: anga) # pending, no file attached

    search = Search::PdfSearch.new(anga)
    result = search.search("testing")

    assert_not result.match?
    assert_equal 0.0, result.score
  end

  test "searches extracted text content" do
    anga = create(:anga, :pdf, user: @user, filename: "2024-01-01T120000-document.pdf")
    text = create(:text, :pdf, anga: anga, extracted_at: Time.current)
    text.file.attach(
      io: StringIO.new("This document contains important research findings about climate change."),
      filename: "2024-01-01T120000-document.txt",
      content_type: "text/plain"
    )

    search = Search::PdfSearch.new(anga)
    result = search.search("research")

    assert result.match?
    assert result.score >= 0.75
    assert_equal "research", result.matched_text
  end

  test "searches multi-word phrases in extracted text" do
    anga = create(:anga, :pdf, user: @user, filename: "2024-01-01T120000-document.pdf")
    text = create(:text, :pdf, anga: anga, extracted_at: Time.current)
    text.file.attach(
      io: StringIO.new("The quick brown fox jumps over the lazy dog."),
      filename: "2024-01-01T120000-document.txt",
      content_type: "text/plain"
    )

    search = Search::PdfSearch.new(anga)
    result = search.search("quick brown")

    assert result.match?
    assert result.score >= 0.75
  end

  test "uses fuzzy matching for extracted content" do
    anga = create(:anga, :pdf, user: @user, filename: "2024-01-01T120000-document.pdf")
    text = create(:text, :pdf, anga: anga, extracted_at: Time.current)
    text.file.attach(
      io: StringIO.new("Documentation for developers"),
      filename: "2024-01-01T120000-document.txt",
      content_type: "text/plain"
    )

    search = Search::PdfSearch.new(anga)
    result = search.search("documentation")

    assert result.match?
    assert result.score >= 0.75
  end

  test "matches filename when not a common pattern" do
    anga = create(:anga, :pdf, user: @user, filename: "2024-01-01T120000-thesis.pdf")

    search = Search::PdfSearch.new(anga)
    result = search.search("thesis")

    assert result.match?
    assert_equal anga.filename, result.matched_text
  end

  test "returns no match gracefully when text extraction failed" do
    anga = create(:anga, :pdf, user: @user, filename: "2024-01-01T120000-document.pdf")
    create(:text, :pdf, :failed, anga: anga)

    search = Search::PdfSearch.new(anga)
    result = search.search("anything")

    assert_not result.match?
    assert_equal 0.0, result.score
  end
end
