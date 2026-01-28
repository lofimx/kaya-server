module Search
  class BookmarkSearch < BaseSearch
    protected

    # Bookmarks (.url files) only contain a URL, so we search filename only.
    # The base class already handles filename matching, so we return nil here
    # to skip content search.
    def extract_content
      nil
    end
  end
end
