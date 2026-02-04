require "readability"
require "reverse_markdown"

class ExtractPlaintextBookmarkJob < ApplicationJob
  queue_as :default

  def perform(bookmark_id)
    bookmark = Bookmark.find_by(id: bookmark_id)
    return unless bookmark
    return unless bookmark.cached? && bookmark.html_file.attached?

    anga = bookmark.anga
    words = anga.words || anga.build_words(source_type: "bookmark")

    begin
      html_content = bookmark.html_file.download.force_encoding("UTF-8")

      readable = Readability::Document.new(html_content)
      readable_html = readable.content

      markdown = ReverseMarkdown.convert(readable_html, unknown_tags: :bypass).strip

      if markdown.blank?
        Rails.logger.warn "🟠 WARN: ExtractPlaintextBookmarkJob: No readable content extracted from #{anga.filename}"
        words.update!(extract_error: "No readable content extracted")
        return
      end

      filename = "#{File.basename(anga.filename, '.*')}.md"
      words.file.attach(
        io: StringIO.new(markdown),
        filename: filename,
        content_type: "text/markdown"
      )
      words.update!(extracted_at: Time.current, extract_error: nil)

      Rails.logger.info "🔵 INFO: ExtractPlaintextBookmarkJob: Extracted plaintext for #{anga.filename}"
    rescue => e
      Rails.logger.error "🔴 ERROR: ExtractPlaintextBookmarkJob: Failed to extract plaintext for #{anga.filename}: #{e.message}"
      words.update!(extract_error: "#{e.class}: #{e.message}")
    end
  end
end
