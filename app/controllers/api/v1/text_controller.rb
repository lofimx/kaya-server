module Api
  module V1
    class TextController < BaseController
      before_action :authorize_user_access

      # GET /api/v1/:user_email/text
      # Lists all anga directories that have extracted text (URL-escaped for direct use in URLs)
      def index
        filenames = current_user.angas
                                .joins(:text)
                                .where.not(texts: { extracted_at: nil })
                                .order(filename: :asc)
                                .pluck(:filename)

        escaped_filenames = filenames.map { |f| ERB::Util.url_encode(f) }
        render plain: escaped_filenames.join("\n"), content_type: "text/plain"
      end

      # GET /api/v1/:user_email/text/:anga
      # Lists text files for a given anga directory (URL-escaped for direct use in URLs)
      def show
        anga = current_user.angas.find_by(filename: CGI.unescape(params[:anga]))
        text = anga&.text

        unless text&.extracted?
          head :not_found
          return
        end

        escaped_filename = ERB::Util.url_encode(text.text_filename)
        render plain: escaped_filename, content_type: "text/plain"
      end

      # GET /api/v1/:user_email/text/:anga/:filename
      # Returns the plaintext file content
      def file
        anga = current_user.angas.find_by(filename: CGI.unescape(params[:anga]))
        text = anga&.text

        unless text&.extracted? && text.file.attached?
          head :not_found
          return
        end

        requested_filename = CGI.unescape(params[:filename])
        unless text.text_filename == requested_filename
          head :not_found
          return
        end

        content_type = text.source_type == "bookmark" ? "text/markdown" : "text/plain"
        send_data text.file.download,
                  filename: text.text_filename,
                  type: content_type,
                  disposition: "inline"
      end

      private

      def authorize_user_access
        unless current_user.email_address == params[:user_email].downcase.strip
          head :forbidden
        end
      end
    end
  end
end
