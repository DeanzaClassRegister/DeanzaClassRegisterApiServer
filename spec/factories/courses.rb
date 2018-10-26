FactoryBot.define do
  factory :course do
    crn { Faker::Number.number(4) }
    course 'PHYS 4A'
    department 'CIS'
    quarter Rails.application.credentials.quarter
    status :Full

    transient do
      courses_count 2
    end

    after(:create) do |course, evaluator|
      create_list(:lecture, evaluator.courses_count, course: course)
    end
  end
end
