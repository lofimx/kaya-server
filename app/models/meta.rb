class Meta < ApplicationRecord
  before_create :generate_uuid
  before_save :link_to_anga

  belongs_to :user
  belongs_to :anga, optional: true
  has_one_attached :file

  validates :filename, presence: true
  validates :filename, uniqueness: { scope: :user_id }
  validates :filename, format: {
    with: /\A\d{4}-\d{2}-\d{2}T\d{6}(_\d{9})?.*\.toml\z/,
    message: "must start with YYYY-mm-ddTHHMMSS format and end with .toml"
  }
  validates :anga_filename, presence: true

  scope :orphaned, -> { where(orphan: true) }
  scope :linked, -> { where(orphan: false) }

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end

  # Look up the associated Anga by the anga_filename and link them.
  # If the Anga cannot be found, mark this Meta as orphan.
  def link_to_anga
    found_anga = user.angas.find_by(filename: anga_filename)

    if found_anga
      self.anga = found_anga
      self.orphan = false
    else
      self.anga = nil
      self.orphan = true
    end
  end
end
