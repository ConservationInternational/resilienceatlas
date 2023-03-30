require "system_helper"

RSpec.describe "Admin: Journeys", type: :system do
  include ActionText::SystemTestHelper

  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:journeys) { create_list :journey, 3 }

    before { visit admin_journeys_path }

    it "shows all resources" do
      Journey.all.each do |journey|
        expect(page).to have_text(journey.id)
        expect(page).to have_text(journey.title)
        expect(page).to have_text(journey.subtitle)
      end
    end
  end

  describe "#show" do
    let(:journey_step_landing) { create :journey_step, step_type: :landing }
    let(:journey_step_conclusion) { create :journey_step, step_type: :conclusion }
    let(:journey_step_chapter) { create :journey_step, step_type: :chapter }
    let(:journey_step_embed) { create :journey_step, step_type: :embed }
    let!(:journey) do
      create :journey, journey_steps: [journey_step_landing, journey_step_conclusion, journey_step_chapter, journey_step_embed]
    end

    before do
      visit admin_journeys_path
      find("a[href='/admin/journeys/#{journey.id}']", text: "View").click
    end

    it "shows journey detail" do
      expect(page).to have_text(journey.title)
      expect(page).to have_text(journey.subtitle)
      expect(page).to have_text(journey.theme)
      expect(page).to have_text(journey.credits)
      expect(page).to have_text(journey.credits_url)
      expect(page).to have_text("#{ENV["FRONTEND_URL"]}/journeys/#{journey.id}")
    end

    it "shows landing journey step detail" do
      expect(page).to have_text(journey_step_landing.id)
      expect(page).to have_text(journey_step_landing.title)
      expect(page).to have_text(journey_step_landing.description)
      expect(page).to have_text(journey_step_landing.credits)
      expect(page).to have_text(journey_step_landing.credits_url)
      expect(page).to have_text(journey_step_landing.position)
    end

    it "shows conclusion journey step detail" do
      expect(page).to have_text(journey_step_conclusion.id)
      expect(page).to have_text(journey_step_conclusion.title)
      expect(page).to have_text(journey_step_conclusion.subtitle)
      expect(page).to have_text(ActionText::Content.new(journey_step_conclusion.content).to_plain_text)
      expect(page).to have_text(journey_step_conclusion.credits)
      expect(page).to have_text(journey_step_conclusion.credits_url)
      expect(page).to have_text(journey_step_conclusion.position)
    end

    it "shows chapter journey step detail" do
      expect(page).to have_text(journey_step_chapter.id)
      expect(page).to have_text(journey_step_chapter.title)
      expect(page).to have_text(journey_step_chapter.description)
      expect(page).to have_text(journey_step_chapter.chapter_number)
      expect(page).to have_text(journey_step_chapter.credits)
      expect(page).to have_text(journey_step_chapter.credits_url)
      expect(page).to have_text(journey_step_chapter.position)
    end

    it "shows embed journey step detail" do
      expect(page).to have_text(journey_step_embed.id)
      expect(page).to have_text(journey_step_embed.title)
      expect(page).to have_text(journey_step_embed.subtitle)
      expect(page).to have_text(ActionText::Content.new(journey_step_embed.content).to_plain_text)
      expect(page).to have_text(journey_step_embed.source)
      expect(page).to have_text(journey_step_embed.mask_sql)
      expect(page).to have_text(journey_step_embed.map_url)
      expect(page).to have_text(journey_step_embed.embedded_map_url)
      expect(page).to have_text(journey_step_embed.position)
    end

    it "shows only required properties of appropriate step types" do
      expect(page).to have_text("EMBEDDED MAP URL", count: 1) # there is only one embedded journey step for this record
    end
  end

  describe "#create" do
    let(:new_journey) { Journey.last }

    before do
      visit admin_journeys_path
      click_on "New Journey"
    end

    it "allows to create new journey" do
      # base journey
      fill_in "journey[translations_attributes][0][title]", with: "New title"
      fill_in "journey[translations_attributes][0][subtitle]", with: "New subtitle"
      fill_in "journey[translations_attributes][0][theme]", with: "New theme"
      fill_in "journey[translations_attributes][0][credits]", with: "New credits"
      fill_in "journey[credits_url]", with: "http://test.test"
      attach_file "journey[background_image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      # landing journey step
      click_on "Add New Journey step"
      all("fieldset.has-many-toggle-collapse").last.click
      fill_in "journey[journey_steps_attributes][0][translations_attributes][0][title]", with: "New step title"
      fill_in "journey[journey_steps_attributes][0][translations_attributes][0][description]", with: "New step description"
      fill_in "journey[journey_steps_attributes][0][translations_attributes][0][credits]", with: "New step credits"
      fill_in "journey[journey_steps_attributes][0][credits_url]", with: "http://step-test.test"
      attach_file "journey[journey_steps_attributes][0][background_image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      # embed journey step
      click_on "Add New Journey step"
      all("fieldset.has-many-toggle-collapse").last.click
      select "embed", from: "journey[journey_steps_attributes][1][step_type]"
      fill_in "journey[journey_steps_attributes][1][translations_attributes][0][title]", with: "New embed step title"
      fill_in "journey[journey_steps_attributes][1][translations_attributes][0][subtitle]", with: "New embed step subtitle"
      fill_in_rich_text_area "journey[journey_steps_attributes][1][translations_attributes][0][content]", with: "New step content"
      fill_in "journey[journey_steps_attributes][1][translations_attributes][0][source]", with: "New step source"
      fill_in "journey[journey_steps_attributes][1][mask_sql]", with: "New step mask_sql"
      fill_in "journey[journey_steps_attributes][1][map_url]", with: "http://map-test.test"
      fill_in "journey[journey_steps_attributes][1][embedded_map_url]", with: "http://embedded-map-test.test"

      click_on "Create Journey"

      expect(page).to have_current_path(admin_journey_path(new_journey))
      expect(page).to have_text("Journey was successfully created.")
      expect(page).to have_text("New title")
      expect(page).to have_text("New subtitle")
      expect(page).to have_text("New theme")
      expect(page).to have_text("New credits")
      expect(page).to have_text("http://test.test")
      expect(page).to have_text("New step title")
      expect(page).to have_text("New step description")
      expect(page).to have_text("New step credits")
      expect(page).to have_text("New credits")
      expect(page).to have_text("http://step-test.test")
      expect(page).to have_text("New embed step title")
      expect(page).to have_text("New embed step subtitle")
      expect(page).to have_text("New step content")
      expect(page).to have_text("New step source")
      expect(page).to have_text("New step mask_sql")
      expect(page).to have_text("http://map-test.test")
      expect(page).to have_text("http://embedded-map-test.test")
    end

    it "shows error when validation fails" do
      fill_in "journey[credits_url]", with: "WRONG URL"

      click_on "Create Journey"

      expect(page).to have_current_path(admin_journeys_path)
      expect(page).to have_text("must be a valid URL")
    end
  end

  describe "#update" do
    let!(:journey_step) { create :journey_step, step_type: :embed }
    let!(:journey) { create :journey, journey_steps: [journey_step] }

    before do
      visit admin_journeys_path
      find("a[href='/admin/journeys/#{journey.id}/edit']").click
    end

    it "allows to update existing journey" do
      fill_in "journey[translations_attributes][0][title]", with: "Update title"
      fill_in "journey[translations_attributes][0][subtitle]", with: "Update subtitle"
      fill_in "journey[translations_attributes][0][theme]", with: "Update theme"
      fill_in "journey[translations_attributes][0][credits]", with: "Update credits"
      fill_in "journey[credits_url]", with: "http://test.test"
      attach_file "journey[background_image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      # embed journey step
      all("fieldset.has-many-toggle-collapse").last.click
      fill_in_rich_text_area "journey[journey_steps_attributes][0][translations_attributes][0][content]", with: "Update step content"
      fill_in "journey[journey_steps_attributes][0][translations_attributes][0][source]", with: "Update step source"
      fill_in "journey[journey_steps_attributes][0][mask_sql]", with: "Update step mask_sql"
      fill_in "journey[journey_steps_attributes][0][map_url]", with: "http://map-test.test"
      fill_in "journey[journey_steps_attributes][0][embedded_map_url]", with: "http://embedded-map-test.test"

      click_on "Update Journey"

      expect(page).to have_current_path(admin_journey_path(journey))
      expect(page).to have_text("Journey was successfully updated.")
      expect(page).to have_text("Update title")
      expect(page).to have_text("Update subtitle")
      expect(page).to have_text("Update theme")
      expect(page).to have_text("Update credits")
      expect(page).to have_text("http://test.test")
      expect(page).to have_text("Update step content")
      expect(page).to have_text("Update step source")
      expect(page).to have_text("Update step mask_sql")
      expect(page).to have_text("http://map-test.test")
      expect(page).to have_text("http://embedded-map-test.test")
    end
  end

  describe "#delete" do
    let!(:journey) { create :journey, title: "Custom title" }

    before do
      visit admin_journeys_path
    end

    it "deletes existing journey" do
      expect(page).to have_text(journey.title)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/journeys/#{journey.id}']").click
      end

      expect(page).not_to have_text(journey.title)
    end
  end

  describe "#publish" do
    let!(:journey) { create :journey, published: false }

    before do
      visit admin_journey_path(journey)
    end

    it "allows to change journey to published" do
      click_on "Publish Journey"

      expect(page).to have_text("Journey was published!")
      expect(journey.reload).to be_published
    end
  end

  describe "#unpublish" do
    let!(:journey) { create :journey, published: true }

    before do
      visit admin_journey_path(journey)
    end

    it "allows to change journey to published" do
      click_on "Unpublish Journey"

      expect(page).to have_text("Journey was marked as not published!")
      expect(journey.reload).not_to be_published
    end
  end
end
