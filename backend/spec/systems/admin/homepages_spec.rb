require "system_helper"

RSpec.describe "Admin: Homepages", type: :system do
  let(:admin_user) { create :admin_user }

  before { login_as admin_user }

  describe "#index" do
    let!(:homepages) { create_list :homepage, 3 }

    before { visit admin_homepages_path }

    it "shows homepages" do
      Homepage.all.each do |homepage|
        expect(page).to have_text(homepage.id)
        expect(page).to have_text(homepage.title)
        expect(page).to have_text(homepage.subtitle)
        expect(page).to have_text(homepage.site_scope.name)
      end
    end
  end

  describe "#show" do
    let!(:homepage_journey) { create :homepage_journey }
    let!(:homepage) { create :homepage, show_journeys: true, homepage_journey: homepage_journey }
    let!(:homepage_section) { create :homepage_section, homepage: homepage }

    before do
      visit admin_homepages_path
      find("a[href='/admin/homepages/#{homepage.id}']", text: "View").click
    end

    it "shows homepage detail" do
      expect(page).to have_text(homepage.id)
      expect(page).to have_text(homepage.title)
      expect(page).to have_text(homepage.subtitle)
      expect(page).to have_text(homepage.site_scope.name)
      expect(page).to have_text(homepage.credits)
      expect(page).to have_text(homepage.credits_url)
    end

    it "shows journey information" do
      expect(page).to have_text(homepage_journey.id)
      expect(page).to have_text(homepage_journey.title)
    end

    it "shows homepage section information" do
      expect(page).to have_text(homepage_section.id)
      expect(page).to have_text(homepage_section.title)
      expect(page).to have_text(homepage_section.subtitle)
      expect(page).to have_text(homepage_section.button_text)
      expect(page).to have_text(homepage_section.button_url)
      expect(page).to have_text(homepage_section.image_credits)
      expect(page).to have_text(homepage_section.image_credits_url)
    end
  end

  describe "#create" do
    let!(:site_scope) { create :site_scope }
    let(:new_homepage) { Homepage.last }

    before do
      visit admin_homepages_path
      click_on "New Homepage"
    end

    it "allows to create new homepage" do
      # base homepage
      fill_in "homepage[translations_attributes][0][title]", with: "New title"
      fill_in "homepage[translations_attributes][0][subtitle]", with: "New subtitle"
      fill_in "homepage[translations_attributes][0][credits]", with: "New credits"
      select site_scope.name, from: "homepage[site_scope_id]"
      fill_in "homepage[credits_url]", with: "https://credits-url.com"
      attach_file "homepage[background_image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      # journeys
      check "homepage[show_journeys]"
      fill_in "homepage[homepage_journey_attributes][position]", with: "0"
      fill_in "homepage[homepage_journey_attributes][translations_attributes][0][title]", with: "New journey title"
      # homepage sections
      click_on "Add New Homepage section"
      fill_in "homepage[homepage_sections_attributes][0][translations_attributes][0][title]", with: "New section title"
      fill_in "homepage[homepage_sections_attributes][0][translations_attributes][0][subtitle]", with: "New section subtitle"
      fill_in "homepage[homepage_sections_attributes][0][translations_attributes][0][button_text]", with: "New section button text"
      fill_in "homepage[homepage_sections_attributes][0][translations_attributes][0][image_credits]", with: "New section image credits"
      fill_in "homepage[homepage_sections_attributes][0][button_url]", with: "https://button-url.com"
      attach_file "homepage[homepage_sections_attributes][0][image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      select "cover", from: "homepage[homepage_sections_attributes][0][image_position]"
      fill_in "homepage[homepage_sections_attributes][0][image_credits_url]", with: "https://image-credits-url.com"

      click_on "Create Homepage"

      expect(page).to have_current_path(admin_homepage_path(new_homepage))
      expect(page).to have_text("Homepage was successfully created.")
      expect(page).to have_text("New title")
      expect(page).to have_text("New subtitle")
      expect(page).to have_text("New credits")
      expect(page).to have_text(site_scope.name)
      expect(page).to have_text("https://credits-url.com")
      expect(page).to have_text("New journey title")
      expect(page).to have_text("New section title")
      expect(page).to have_text("New section subtitle")
      expect(page).to have_text("New section button text")
      expect(page).to have_text("New section image credits")
      expect(page).to have_text("https://button-url.com")
      expect(page).to have_text("cover")
      expect(page).to have_text("https://image-credits-url.com")
    end

    it "shows error when validation fails" do
      fill_in "homepage[translations_attributes][0][title]", with: ""

      click_on "Create Homepage"

      expect(page).to have_current_path(admin_homepages_path)
      expect(page).to have_text("can't be blank")
    end
  end

  describe "#update" do
    let!(:site_scope) { create :site_scope }
    let!(:homepage_journey) { create :homepage_journey }
    let!(:homepage) { create :homepage, show_journeys: true, homepage_journey: homepage_journey }
    let!(:homepage_section) { create :homepage_section, homepage: homepage }

    before do
      visit admin_homepages_path
      find("a[href='/admin/homepages/#{homepage.id}/edit']").click
    end

    it "allows to update existing homepage" do
      # base homepage
      fill_in "homepage[translations_attributes][0][title]", with: "Updated title"
      fill_in "homepage[translations_attributes][0][subtitle]", with: "Updated subtitle"
      fill_in "homepage[translations_attributes][0][credits]", with: "Updated credits"
      select site_scope.name, from: "homepage[site_scope_id]"
      fill_in "homepage[credits_url]", with: "https://credits-url.com"
      attach_file "homepage[background_image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      # journeys
      check "homepage[show_journeys]"
      fill_in "homepage[homepage_journey_attributes][position]", with: "0"
      fill_in "homepage[homepage_journey_attributes][translations_attributes][0][title]", with: "Updated journey title"
      # homepage sections
      all("fieldset.has-many-toggle-collapse").last.click
      fill_in "homepage[homepage_sections_attributes][0][translations_attributes][0][title]", with: "Updated section title"
      fill_in "homepage[homepage_sections_attributes][0][translations_attributes][0][subtitle]", with: "Updated section subtitle"
      fill_in "homepage[homepage_sections_attributes][0][translations_attributes][0][button_text]", with: "Updated section button text"
      fill_in "homepage[homepage_sections_attributes][0][translations_attributes][0][image_credits]", with: "Updated section image credits"
      fill_in "homepage[homepage_sections_attributes][0][button_url]", with: "https://button-url.com"
      attach_file "homepage[homepage_sections_attributes][0][image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      select "cover", from: "homepage[homepage_sections_attributes][0][image_position]"
      fill_in "homepage[homepage_sections_attributes][0][image_credits_url]", with: "https://image-credits-url.com"

      click_on "Update Homepage"

      expect(page).to have_current_path(admin_homepage_path(homepage))
      expect(page).to have_text("Homepage was successfully updated.")
      expect(page).to have_text("Updated title")
      expect(page).to have_text("Updated subtitle")
      expect(page).to have_text("Updated credits")
      expect(page).to have_text(site_scope.name)
      expect(page).to have_text("https://credits-url.com")
      expect(page).to have_text("Updated journey title")
      expect(page).to have_text("Updated section title")
      expect(page).to have_text("Updated section subtitle")
      expect(page).to have_text("Updated section button text")
      expect(page).to have_text("Updated section image credits")
      expect(page).to have_text("https://button-url.com")
      expect(page).to have_text("cover")
      expect(page).to have_text("https://image-credits-url.com")
    end
  end

  describe "#delete" do
    let!(:homepage) { create :homepage, title: "Custom title" }

    before do
      visit admin_homepages_path
    end

    it "deletes existing homepage" do
      expect(page).to have_text(homepage.title)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/homepages/#{homepage.id}']").click
      end

      expect(page).not_to have_text(homepage.title)
    end
  end
end
