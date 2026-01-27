#!/usr/bin/env ruby
# frozen_string_literal: true

# Kaya Sync Script
# Synchronizes local ~/.kaya/ directory with the Kaya server API

require "net/http"
require "uri"
require "json"
require "fileutils"
require "optparse"
require "io/console"

class KayaSync
  DEFAULT_URL = "https://kaya.town"
  LOCAL_DIR = File.expand_path("~/.kaya")

  def initialize(options)
    @email = options[:email]
    @password = options[:password]
    @base_url = options[:url] || DEFAULT_URL
    @verbose = options[:verbose]

    @downloaded = []
    @uploaded = []
    @errors = []
  end

  def run
    prompt_credentials
    ensure_local_dir

    log "Connecting to #{@base_url}..."
    log "Syncing files for #{@email}"
    log ""

    server_files = fetch_server_files
    local_files = fetch_local_files

    files_to_download = server_files - local_files
    files_to_upload = local_files - server_files

    log "Server has #{server_files.size} files"
    log "Local has #{local_files.size} files"
    log "To download: #{files_to_download.size}"
    log "To upload: #{files_to_upload.size}"
    log ""

    download_files(files_to_download)
    upload_files(files_to_upload)

    print_summary
  end

  private

  def prompt_credentials
    unless @email
      print "Email: "
      @email = $stdin.gets.chomp
    end

    unless @password
      print "Password: "
      @password = $stdin.noecho(&:gets).chomp
      puts
    end
  end

  def ensure_local_dir
    FileUtils.mkdir_p(LOCAL_DIR)
  end

  def fetch_server_files
    uri = URI("#{@base_url}/api/v1/#{URI.encode_www_form_component(@email)}/anga")

    response = make_request(:get, uri)

    if response.is_a?(Net::HTTPSuccess)
      response.body.split("\n").map(&:strip).reject(&:empty?)
    else
      log_error "Failed to fetch server file list: #{response.code} #{response.message}"
      exit 1
    end
  end

  def fetch_local_files
    return [] unless Dir.exist?(LOCAL_DIR)

    Dir.entries(LOCAL_DIR)
       .reject { |f| f.start_with?(".") }
       .select { |f| File.file?(File.join(LOCAL_DIR, f)) }
  end

  def download_files(files)
    files.each do |filename|
      download_file(filename)
    end
  end

  def download_file(filename)
    uri = URI("#{@base_url}/api/v1/#{URI.encode_www_form_component(@email)}/anga/#{URI.encode_www_form_component(filename)}")

    response = make_request(:get, uri)

    if response.is_a?(Net::HTTPSuccess)
      local_path = File.join(LOCAL_DIR, filename)
      File.binwrite(local_path, response.body)
      log "[DOWNLOAD] #{filename}"
      @downloaded << filename
    else
      log_error "[DOWNLOAD FAILED] #{filename}: #{response.code} #{response.message}"
      @errors << { file: filename, operation: :download, error: "#{response.code} #{response.message}" }
    end
  end

  def upload_files(files)
    files.each do |filename|
      upload_file(filename)
    end
  end

  def upload_file(filename)
    local_path = File.join(LOCAL_DIR, filename)
    uri = URI("#{@base_url}/api/v1/#{URI.encode_www_form_component(@email)}/anga/#{URI.encode_www_form_component(filename)}")

    file_content = File.binread(local_path)
    content_type = mime_type_for(filename)

    response = make_request(:post, uri, file_content, content_type, filename)

    case response
    when Net::HTTPCreated, Net::HTTPSuccess
      log "[UPLOAD] #{filename}"
      @uploaded << filename
    when Net::HTTPConflict
      log "[SKIP] #{filename} (already exists on server)"
    when Net::HTTPExpectationFailed
      log_error "[UPLOAD FAILED] #{filename}: Filename mismatch"
      @errors << { file: filename, operation: :upload, error: "Filename mismatch" }
    else
      log_error "[UPLOAD FAILED] #{filename}: #{response.code} #{response.message}"
      @errors << { file: filename, operation: :upload, error: "#{response.code} #{response.message}" }
    end
  end

  def make_request(method, uri, body = nil, content_type = nil, filename = nil)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 30

    request = case method
    when :get
      Net::HTTP::Get.new(uri)
    when :post
      req = Net::HTTP::Post.new(uri)
      if body
        boundary = "----KayaSyncBoundary#{SecureRandom.hex(16)}"
        req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        req.body = build_multipart_body(boundary, filename, body, content_type)
      end
      req
    end

    request.basic_auth(@email, @password)

    http.request(request)
  rescue StandardError => e
    log_error "Network error: #{e.message}"
    exit 1
  end

  def build_multipart_body(boundary, filename, content, content_type)
    body = []
    body << "--#{boundary}"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\""
    body << "Content-Type: #{content_type}"
    body << ""
    body << content
    body << "--#{boundary}--"
    body.join("\r\n")
  end

  def mime_type_for(filename)
    ext = File.extname(filename).downcase
    case ext
    when ".md" then "text/markdown"
    when ".url" then "text/plain"
    when ".txt" then "text/plain"
    when ".json" then "application/json"
    when ".pdf" then "application/pdf"
    when ".png" then "image/png"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".gif" then "image/gif"
    when ".webp" then "image/webp"
    when ".svg" then "image/svg+xml"
    when ".html", ".htm" then "text/html"
    else "application/octet-stream"
    end
  end

  def log(message)
    puts message
  end

  def log_error(message)
    $stderr.puts message
  end

  def print_summary
    log ""
    log "=" * 50
    log "SYNC COMPLETE"
    log "=" * 50
    log "Downloaded: #{@downloaded.size} files"
    log "Uploaded:   #{@uploaded.size} files"
    log "Errors:     #{@errors.size}"

    if @errors.any?
      log ""
      log "Errors:"
      @errors.each do |error|
        log "  - #{error[:operation].upcase} #{error[:file]}: #{error[:error]}"
      end
    end

    log ""
  end
end

# Parse command line options
options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-e", "--email EMAIL", "Your Kaya account email") do |email|
    options[:email] = email
  end

  opts.on("-p", "--password PASSWORD", "Your Kaya account password") do |password|
    options[:password] = password
  end

  opts.on("-u", "--url URL", "Kaya server URL (default: #{KayaSync::DEFAULT_URL})") do |url|
    options[:url] = url.chomp("/")
  end

  opts.on("-v", "--verbose", "Enable verbose output") do
    options[:verbose] = true
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Run sync
KayaSync.new(options).run
