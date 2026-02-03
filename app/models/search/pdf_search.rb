module Search
  class PdfSearch < BaseSearch
    protected

    def extract_content
      text = @anga.text
      return nil unless text&.extracted? && text.file.attached?

      text.file.download.force_encoding("UTF-8")
    rescue StandardError => e
      Rails.logger.warn("PdfSearch: Failed to read extracted text for #{@anga.filename}: #{e.message}")
      nil
    end
  end
end
