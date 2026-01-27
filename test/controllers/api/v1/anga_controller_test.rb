require "test_helper"

class Api::V1::AngaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
  end

  test "should return 401 without authentication" do
    get api_v1_user_anga_index_url(user_email: @user.email_address)
    assert_response :unauthorized
  end

  test "should return 403 when accessing another user's anga" do
    other_user = create(:user)
    get api_v1_user_anga_index_url(user_email: other_user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :forbidden
  end

  test "index should return empty list when no files" do
    get api_v1_user_anga_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "", response.body.strip
  end

  test "index should return list of filenames" do
    create(:anga, user: @user, filename: "2025-06-28T120000-note.md")
    create(:anga, :bookmark, user: @user, filename: "2025-06-29T130000-bookmark.url")

    get api_v1_user_anga_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type

    lines = response.body.strip.split("\n")
    assert_includes lines, "2025-06-28T120000-note.md"
    assert_includes lines, "2025-06-29T130000-bookmark.url"
  end

  test "show should return 404 for non-existent file" do
    get api_v1_user_anga_file_url(user_email: @user.email_address, filename: "2025-06-28T120000-missing.md"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  test "show should return file content" do
    content = "# My Note\n\nThis is a test note."
    anga = @user.angas.new(filename: "2025-06-28T120000-test.md")
    anga.file.attach(io: StringIO.new(content), filename: "2025-06-28T120000-test.md", content_type: "text/markdown")
    anga.save!

    get api_v1_user_anga_file_url(user_email: @user.email_address, filename: "2025-06-28T120000-test.md"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal content, response.body
  end

  test "create should reject mismatched filename with 417" do
    post "/api/v1/#{@user.email_address}/anga/2025-06-28T120000-url-name.md",
         params: { file: fixture_file_upload("test_file.md", "text/markdown") },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :expectation_failed
  end

  test "create should reject duplicate filename with 409" do
    create(:anga, user: @user, filename: "2025-06-28T120000-existing.md")

    file = Tempfile.new([ "2025-06-28T120000-existing", ".md" ])
    file.write("# New content")
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "2025-06-28T120000-existing.md")

    post "/api/v1/#{@user.email_address}/anga/2025-06-28T120000-existing.md",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :conflict

    file.close
    file.unlink
  end

  test "create should successfully upload a new file" do
    file = Tempfile.new([ "2025-06-28T140000-new", ".md" ])
    file.write("# New Note")
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "2025-06-28T140000-new.md")

    assert_difference -> { @user.angas.count }, 1 do
      post "/api/v1/#{@user.email_address}/anga/2025-06-28T140000-new.md",
           params: { file: uploaded },
           headers: basic_auth_header(@user.email_address, "password")
    end
    assert_response :created

    file.close
    file.unlink
  end

  private

  def basic_auth_header(email, password)
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(email, password) }
  end
end
