# SearchService orchestrates full-text search across all anga types.
# It delegates to specialized search objects in app/models/search/ for
# each file type.
class SearchService
  # Minimum Jaro-Winkler score to consider a match (0.0 to 1.0)
  DEFAULT_THRESHOLD = 0.75

  def initialize(user, query, threshold: DEFAULT_THRESHOLD)
    @user = user
    @query = query.to_s.strip.downcase
    @threshold = threshold
  end

  def search
    return @user.angas.none if @query.blank?

    matching_anga_ids = []

    @user.angas.includes(:file_attachment, :file_blob).find_each do |anga|
      result = search_anga(anga)
      matching_anga_ids << anga.id if result.match?
    end

    @user.angas.where(id: matching_anga_ids)
  end

  private

  def search_anga(anga)
    searcher_for(anga).search(@query, threshold: @threshold)
  end

  def searcher_for(anga)
    file_type = FileType.new(anga.filename)

    if file_type.note?
      Search::NoteSearch.new(anga)
    elsif file_type.text?
      Search::TextSearch.new(anga)
    elsif file_type.pdf?
      Search::PdfSearch.new(anga)
    elsif file_type.bookmark?
      Search::BookmarkSearch.new(anga)
    else
      Search::GenericFileSearch.new(anga)
    end
  end
end
