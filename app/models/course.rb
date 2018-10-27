class Course < ApplicationRecord
  serialize :cached_lecture

  # enums
  enum status: [:Open, :Waitlist, :Full]

  # relations
  has_many :lectures, dependent: :destroy
  has_many :subscriptions
  has_many :subscribers, through: :subscriptions, source: :user
  accepts_nested_attributes_for :lectures

  # validations
  validates_presence_of :crn, :course

  # callbacks
  after_commit :flush_cache

  # use scope because it chains even if
  # hash.first[1].present? is nil
  scope :where_if_present, -> (hash) {
    where(hash) if hash.first[1].present?
  }

  private
  def flush_cache
    Rails.cache.clear
  end
end
