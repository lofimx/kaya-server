require "test_helper"

class MetaTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "meta is linked to anga when anga exists" do
    anga = create(:anga, user: @user, filename: "2025-06-28T120000-my-bookmark.url")

    meta = @user.metas.new(
      filename: "2025-06-28T120001-meta.toml",
      anga_filename: "2025-06-28T120000-my-bookmark.url"
    )
    meta.file.attach(
      io: StringIO.new("[anga]\nfilename = \"2025-06-28T120000-my-bookmark.url\"\n"),
      filename: meta.filename,
      content_type: "application/toml"
    )
    meta.save!

    assert_equal anga, meta.anga
    assert_not meta.orphan
  end

  test "meta is marked as orphan when anga does not exist" do
    meta = @user.metas.new(
      filename: "2025-06-28T120001-meta.toml",
      anga_filename: "2025-06-28T120000-nonexistent.url"
    )
    meta.file.attach(
      io: StringIO.new("[anga]\nfilename = \"2025-06-28T120000-nonexistent.url\"\n"),
      filename: meta.filename,
      content_type: "application/toml"
    )
    meta.save!

    assert_nil meta.anga
    assert meta.orphan
  end

  test "anga.metas returns associated metas" do
    anga = create(:anga, user: @user, filename: "2025-06-28T120000-test.url")

    meta1 = @user.metas.create!(
      filename: "2025-06-28T120001-meta1.toml",
      anga_filename: "2025-06-28T120000-test.url",
      file: fixture_file_blob("[anga]\nfilename = \"2025-06-28T120000-test.url\"\n", "2025-06-28T120001-meta1.toml")
    )
    meta2 = @user.metas.create!(
      filename: "2025-06-28T120002-meta2.toml",
      anga_filename: "2025-06-28T120000-test.url",
      file: fixture_file_blob("[anga]\nfilename = \"2025-06-28T120000-test.url\"\n", "2025-06-28T120002-meta2.toml")
    )

    assert_equal 2, anga.metas.count
    assert_includes anga.metas, meta1
    assert_includes anga.metas, meta2
  end

  test "orphaned scope returns only orphan metas" do
    anga = create(:anga, user: @user, filename: "2025-06-28T120000-test.url")

    linked_meta = @user.metas.create!(
      filename: "2025-06-28T120001-linked.toml",
      anga_filename: "2025-06-28T120000-test.url",
      file: fixture_file_blob("[anga]\nfilename = \"2025-06-28T120000-test.url\"\n", "2025-06-28T120001-linked.toml")
    )
    orphan_meta = @user.metas.create!(
      filename: "2025-06-28T120002-orphan.toml",
      anga_filename: "2025-06-28T120000-nonexistent.url",
      file: fixture_file_blob("[anga]\nfilename = \"2025-06-28T120000-nonexistent.url\"\n", "2025-06-28T120002-orphan.toml")
    )

    assert_equal [ orphan_meta ], @user.metas.orphaned.to_a
    assert_equal [ linked_meta ], @user.metas.linked.to_a
  end

  private

  def fixture_file_blob(content, filename)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: filename,
      content_type: "application/toml"
    )
  end
end
