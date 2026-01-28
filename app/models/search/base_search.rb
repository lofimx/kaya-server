require "amatch"

module Search
  # Base class for file content search using Jaro-Winkler distance.
  # Subclasses implement #extract_content to provide searchable text.
  class BaseSearch
    SearchResult = Struct.new(:match?, :score, :matched_text, keyword_init: true)

    # Common filename patterns that clients auto-generate. These should only
    # match on exact queries, not fuzzy matches like "notwithstanding" -> "note".
    COMMON_FILENAME_PATTERNS = %w[note bookmark].freeze

    def initialize(anga)
      @anga = anga
    end

    def search(query, threshold: 0.75)
      filename_base = filename_without_timestamp

      # Check if query exactly matches a common pattern (user wants all notes/bookmarks)
      if exact_common_pattern_query?(query)
        if filename_base == query.downcase
          return SearchResult.new(match?: true, score: 1.0, matched_text: @anga.filename)
        end
      else
        # For non-exact queries, only match filename if it's not a common pattern
        unless common_filename_pattern?(filename_base)
          filename_score = jaro_winkler_score(query, filename_base)
          if filename_score >= threshold
            return SearchResult.new(match?: true, score: filename_score, matched_text: @anga.filename)
          end
        end
      end

      # Then check content if available
      content = extract_content
      return SearchResult.new(match?: false, score: 0.0, matched_text: nil) if content.blank?

      best_match = find_best_match(query, content, threshold)
      best_match || SearchResult.new(match?: false, score: 0.0, matched_text: nil)
    end

    protected

    # Subclasses must implement this to extract searchable text content
    def extract_content
      raise NotImplementedError, "#{self.class} must implement #extract_content"
    end

    private

    def filename_without_timestamp
      # Remove the YYYY-mm-ddTHHMMSS prefix and extension for matching
      name = @anga.filename
      # Remove timestamp prefix (with optional nanoseconds)
      name = name.sub(/^\d{4}-\d{2}-\d{2}T\d{6}(_\d{9})?-?/, "")
      # Remove extension
      File.basename(name, ".*").downcase
    end

    def jaro_winkler_score(query, text)
      return 0.0 if text.blank?
      Amatch::JaroWinkler.new(query.downcase).match(text.downcase)
    end

    def find_best_match(query, content, threshold)
      words = tokenize(content)
      best_score = 0.0
      best_match = nil

      words.each do |word|
        score = jaro_winkler_score(query, word)
        if score > best_score
          best_score = score
          best_match = word
        end
      end

      # Also try matching against phrases (sliding window)
      query_word_count = query.split.size
      if query_word_count > 1
        phrases = extract_phrases(content, query_word_count)
        phrases.each do |phrase|
          score = jaro_winkler_score(query, phrase)
          if score > best_score
            best_score = score
            best_match = phrase
          end
        end
      end

      if best_score >= threshold
        SearchResult.new(match?: true, score: best_score, matched_text: best_match)
      else
        nil
      end
    end

    def tokenize(content)
      content.downcase.scan(/[\w'-]+/)
    end

    def extract_phrases(content, word_count)
      words = tokenize(content)
      return [] if words.size < word_count

      phrases = []
      (0..words.size - word_count).each do |i|
        phrases << words[i, word_count].join(" ")
      end
      phrases
    end

    def exact_common_pattern_query?(query)
      COMMON_FILENAME_PATTERNS.include?(query.downcase.strip)
    end

    def common_filename_pattern?(filename_base)
      COMMON_FILENAME_PATTERNS.include?(filename_base)
    end
  end
end
