require 'rails_helper'

RSpec.describe Lecture, type: :model do
  # Association Test
  it { should belong_to(:course) }

  # Validation Test
  it { should validate_presence_of(:title) }
end