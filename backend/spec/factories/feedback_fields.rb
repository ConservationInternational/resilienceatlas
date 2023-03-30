FactoryBot.define do
  factory :feedback_field do
    feedback
    parent { nil }

    trait :boolean_choice do
      feedback_field_type { :boolean_choice }
      question { "Do you like summer?" }
      answers { {value: true, slug: "true"} }
    end

    trait :single_choice do
      feedback_field_type { :single_choice }
      question { "What is your favorite color?" }
      answers { {value: "Red", slug: "red"} }
    end

    trait :multiple_choice do
      feedback_field_type { :multiple_choice }
      question { "What is your favorite color?" }
      answers { {value: ["Red", "Blue"], slug: ["red", "blue"]} }
    end

    trait :free_answer do
      feedback_field_type { :free_answer }
      question { "What is your favorite color?" }
      answers { {value: "Red", slug: nil} }
    end

    trait :rating do
      feedback_field_type { :rating }
      question { "Color preferences" }
      answers { nil }

      after_build do |feedback_field|
        build :feedback_field, :single_choice, parent: feedback_field, question: "Do you like red color?", answers: {value: 3, slug: "3"}
      end
    end
  end
end
