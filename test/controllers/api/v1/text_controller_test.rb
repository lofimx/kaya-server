require "test_helper"

class Api::V1::TextControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
  end

  # --- index ---

  test "index lists anga directories with extracted text" do
    anga1 = create(:anga, :bookmark, user: @user, filename: "2024-01-01T120000-example.url")
    create(:text, :bookmark, :extracted, anga: anga1)

    anga2 = create(:anga, :pdf, user: @user, filename: "2024-01-01T120001-document.pdf")
    create(:text, :pdf, :extracted, anga: anga2)

    # This one has no text, should not appear
    create(:anga, :bookmark, user: @user, filename: "2024-01-01T120002-notext.url")

    get api_v1_text_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type

    lines = response.body.strip.split("\n")
    assert_equal 2, lines.length
    assert_includes lines, "2024-01-01T120000-example.url"
    assert_includes lines, "2024-01-01T120001-document.pdf"
  end

  test "index returns empty for user with no extracted text" do
    get api_v1_text_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "", response.body.strip
  end

  test "index URL-escapes filenames with special characters" do
    anga = create(:anga, :bookmark, user: @user, filename: "2024-01-01T120000-example with spaces.url")
    create(:text, :bookmark, :extracted, anga: anga)

    get api_v1_text_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success

    lines = response.body.strip.split("\n")
    assert_includes lines, "2024-01-01T120000-example%20with%20spaces.url"
  end

  test "index excludes pending text records" do
    anga = create(:anga, :bookmark, user: @user, filename: "2024-01-01T120000-pending.url")
    create(:text, :bookmark, anga: anga) # pending, no extracted_at

    get api_v1_text_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "", response.body.strip
  end

  test "index requires authentication" do
    get api_v1_text_url(user_email: @user.email_address)
    assert_response :unauthorized
  end

  test "index forbids access to other user's text" do
    other_user = create(:user)
    get api_v1_text_url(user_email: other_user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :forbidden
  end

  # --- show ---

  test "show lists text files for a given anga" do
    anga = create(:anga, :bookmark, user: @user, filename: "2024-01-01T120000-example.url")
    create(:text, :bookmark, :extracted, anga: anga)

    get api_v1_text_anga_url(user_email: @user.email_address, anga: anga.filename),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "2024-01-01T120000-example.md", response.body.strip
  end

  test "show lists .txt for pdf anga" do
    anga = create(:anga, :pdf, user: @user, filename: "2024-01-01T120000-document.pdf")
    create(:text, :pdf, :extracted, anga: anga)

    get api_v1_text_anga_url(user_email: @user.email_address, anga: anga.filename),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "2024-01-01T120000-document.txt", response.body.strip
  end

  test "show returns 404 for non-existent anga" do
    get api_v1_text_anga_url(user_email: @user.email_address, anga: "nonexistent.url"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  test "show returns 404 when text not extracted" do
    anga = create(:anga, :bookmark, user: @user, filename: "2024-01-01T120000-pending.url")
    create(:text, :bookmark, anga: anga) # pending

    get api_v1_text_anga_url(user_email: @user.email_address, anga: anga.filename),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  # --- file ---

  test "file returns plaintext content for bookmark" do
    anga = create(:anga, :bookmark, user: @user, filename: "2024-01-01T120000-example.url")
    text = create(:text, :bookmark, anga: anga, extracted_at: Time.current)
    text.file.attach(
      io: StringIO.new("# Article Title\n\nSome extracted markdown content."),
      filename: "2024-01-01T120000-example.md",
      content_type: "text/markdown"
    )

    get api_v1_text_file_url(user_email: @user.email_address, anga: anga.filename, filename: "2024-01-01T120000-example.md"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_includes response.body, "Article Title"
  end

  test "file returns plaintext content for pdf" do
    anga = create(:anga, :pdf, user: @user, filename: "2024-01-01T120000-document.pdf")
    text = create(:text, :pdf, anga: anga, extracted_at: Time.current)
    text.file.attach(
      io: StringIO.new("Extracted PDF text content here."),
      filename: "2024-01-01T120000-document.txt",
      content_type: "text/plain"
    )

    get api_v1_text_file_url(user_email: @user.email_address, anga: anga.filename, filename: "2024-01-01T120000-document.txt"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_includes response.body, "Extracted PDF text content"
  end

  test "file returns 404 for non-existent anga" do
    get api_v1_text_file_url(user_email: @user.email_address, anga: "nonexistent.url", filename: "nonexistent.md"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  test "file returns 404 for wrong filename" do
    anga = create(:anga, :bookmark, user: @user, filename: "2024-01-01T120000-example.url")
    create(:text, :bookmark, :extracted, anga: anga)

    get api_v1_text_file_url(user_email: @user.email_address, anga: anga.filename, filename: "wrong-filename.md"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  test "file returns 404 when text not extracted" do
    anga = create(:anga, :bookmark, user: @user, filename: "2024-01-01T120000-pending.url")
    create(:text, :bookmark, anga: anga) # pending

    get api_v1_text_file_url(user_email: @user.email_address, anga: anga.filename, filename: "2024-01-01T120000-pending.md"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  private

  def basic_auth_header(email, password)
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(email, password) }
  end
end
