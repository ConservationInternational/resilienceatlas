# == Schema Information
#
# Table name: feedback_fields
#
#  id                  :bigint           not null, primary key
#  feedback_id         :bigint           not null
#  parent_id           :bigint
#  feedback_field_type :string           not null
#  question            :string
#  answer              :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
FactoryBot.define do
  factory :feedback_field do
    feedback
    parent { nil }

    trait :boolean_choice do
      feedback_field_type { :boolean_choice }
      question { "Do you like summer?" }
      answer { {value: true, slug: "true"} }
    end

    trait :single_choice do
      feedback_field_type { :single_choice }
      question { "What is your favorite color?" }
      answer { {value: "Red", slug: "red"} }
    end

    trait :multiple_choice do
      feedback_field_type { :multiple_choice }
      question { "What is your favorite color?" }
      answer { {value: ["Red", "Blue"], slug: ["red", "blue"]} }
    end

    trait :free_answer do
      feedback_field_type { :free_answer }
      question { "What is your favorite color?" }
      answer { {value: "Red", slug: nil} }
    end

    trait :rating do
      feedback_field_type { :rating }
      question { "Color preferences" }
      answer { nil }

      after_build do |feedback_field|
        build :feedback_field, :single_choice, parent: feedback_field, question: "Do you like red color?", answer: {value: 3, slug: "3"}
      end
    end
  end
end
