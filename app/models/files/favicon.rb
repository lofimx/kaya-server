# Favicon handles validation of favicon image data.
# Used during bookmark caching to detect and discard broken favicons
# before they are stored.
#
# Example usage:
#   Files::Favicon.valid?(image_data, "image/vnd.microsoft.icon")  # => false
#   Files::Favicon.valid?(image_data, "image/png")                 # => true
#
module Files
  class Favicon
    ICO_CONTENT_TYPES = %w[image/x-icon image/vnd.microsoft.icon].freeze

    # Validates that favicon image data is well-formed and can be rendered by browsers.
    # ICO files get special validation since ImageMagick is too lenient with them.
    # Other image formats are validated with MiniMagick.
    def self.valid?(content, content_type)
      if ico_content_type?(content_type) || ico_magic_bytes?(content)
        valid_ico?(content)
      else
        valid_image_via_magick?(content)
      end
    rescue StandardError => e
      Rails.logger.warn("🟠 WARN: Favicon validation error: #{e.message}")
      false
    end

    def self.ico_content_type?(content_type)
      ICO_CONTENT_TYPES.include?(content_type)
    end

    def self.ico_magic_bytes?(content)
      content.bytesize >= 6 && content.getbyte(0) == 0 && content.getbyte(1) == 0 &&
        content.getbyte(2) == 1 && content.getbyte(3) == 0
    end

    # Validates an ICO file by checking that directory entry dimensions match
    # the actual BMP/PNG sub-image dimensions. Browsers enforce this consistency
    # and reject ICO files where they disagree.
    def self.valid_ico?(content)
      bytes = content.bytes
      return false if bytes.length < 6

      num_images = bytes[4] | (bytes[5] << 8)
      return false if num_images == 0
      return false if bytes.length < 6 + (num_images * 16)

      num_images.times do |i|
        entry_offset = 6 + (i * 16)
        dir_width = bytes[entry_offset] == 0 ? 256 : bytes[entry_offset]
        dir_height = bytes[entry_offset + 1] == 0 ? 256 : bytes[entry_offset + 1]
        img_size = bytes[entry_offset + 8] | (bytes[entry_offset + 9] << 8) |
                   (bytes[entry_offset + 10] << 16) | (bytes[entry_offset + 11] << 24)
        img_offset = bytes[entry_offset + 12] | (bytes[entry_offset + 13] << 8) |
                     (bytes[entry_offset + 14] << 16) | (bytes[entry_offset + 15] << 24)

        return false if img_offset + img_size > bytes.length

        if img_offset + 8 > bytes.length
          return false
        end

        sub_magic = bytes[img_offset, 4]
        if sub_magic == [ 137, 80, 78, 71 ] # PNG
          # PNG sub-images: browsers trust the PNG header, directory dims are informational
          next
        end

        # BMP sub-image: validate directory dimensions match BMP header dimensions
        bmp_header_size = sub_magic[0] | (sub_magic[1] << 8) | (sub_magic[2] << 16) | (sub_magic[3] << 24)
        return false unless bmp_header_size == 40 # BITMAPINFOHEADER

        bmp_width = bytes[img_offset + 4] | (bytes[img_offset + 5] << 8) |
                    (bytes[img_offset + 6] << 16) | (bytes[img_offset + 7] << 24)
        bmp_raw_height = bytes[img_offset + 8] | (bytes[img_offset + 9] << 8) |
                         (bytes[img_offset + 10] << 16) | (bytes[img_offset + 11] << 24)
        bmp_height = bmp_raw_height / 2 # ICO BMP height includes image + mask

        unless dir_width == bmp_width && dir_height == bmp_height
          Rails.logger.debug("🟢 DEBUG: ICO directory says #{dir_width}x#{dir_height} but BMP says #{bmp_width}x#{bmp_height}")
          return false
        end
      end

      true
    end

    def self.valid_image_via_magick?(content)
      tempfile = Tempfile.new([ "favicon", ".img" ])
      tempfile.binmode
      tempfile.write(content)
      tempfile.close

      image = MiniMagick::Image.open(tempfile.path)
      image.valid?
    ensure
      tempfile&.unlink
    end

    private_class_method :ico_content_type?, :ico_magic_bytes?, :valid_ico?, :valid_image_via_magick?
  end
end
