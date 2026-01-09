require "system_helper"

RSpec.describe "Admin: Feedbacks", type: :system do
  let(:admin_user) { create :admin_user }

  before { login_as admin_user }

  describe "#index" do
    let!(:feedbacks) { create_list :feedback, 3 }

    before { visit admin_feedbacks_path }

    it "shows feedbacks" do
      Feedback.all.each do |feedback|
        expect(page).to have_text(feedback.id)
        expect(page).to have_text(feedback.language)
      end
    end
  end

  describe "#show" do
    let(:feedback_field_boolean_choice) { build :feedback_field, :boolean_choice }
    let(:feedback_field_single_choice) { build :feedback_field, :single_choice }
    let(:feedback_field_multiple_choice) { build :feedback_field, :multiple_choice }
    let(:feedback_field_free_answer) { build :feedback_field, :free_answer }
    let(:feedback_field_rating) { build :feedback_field, :rating }
    let!(:feedback) do
      create :feedback, feedback_fields: [
        feedback_field_boolean_choice,
        feedback_field_single_choice,
        feedback_field_multiple_choice,
        feedback_field_free_answer,
        feedback_field_rating
      ]
    end

    before do
      visit admin_feedbacks_path
      find("a[href='/admin/feedbacks/#{feedback.id}']", text: "View").click
    end

    it "shows feedback detail" do
      expect(page).to have_text(feedback.id)
      expect(page).to have_text(feedback.language)
    end

    it "shows feedback fields data" do
      expect(page).to have_text(feedback_field_boolean_choice.question.upcase)
      expect(page).to have_text(feedback_field_boolean_choice.answer["value"])
      expect(page).to have_text(feedback_field_single_choice.question.upcase)
      expect(page).to have_text(feedback_field_single_choice.answer["value"])
      expect(page).to have_text(feedback_field_multiple_choice.question.upcase)
      expect(page).to have_text(feedback_field_multiple_choice.answer["value"].join(", "))
      expect(page).to have_text(feedback_field_free_answer.question.upcase)
      expect(page).to have_text(feedback_field_free_answer.answer["value"])
      expect(page).to have_text(feedback_field_rating.question)
      expect(page).to have_text(feedback_field_rating.children.first.question.upcase)
      expect(page).to have_text(feedback_field_rating.children.first.answer.dig("value"))
      expect(page).to have_text(feedback_field_rating.children.second.question.upcase)
      expect(page).to have_text(feedback_field_rating.children.second.answer.dig("value"))
    end
  end

  describe "#delete" do
    let!(:feedback) { create :feedback }

    before do
      visit admin_feedbacks_path
    end

    it "deletes existing feedback" do
      expect(page).to have_text(feedback.id)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/feedbacks/#{feedback.id}']").click
      end

      expect(page).not_to have_text(feedback.id)
    end
  end
end
