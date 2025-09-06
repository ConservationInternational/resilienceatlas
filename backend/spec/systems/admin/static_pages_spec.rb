require "system_helper"

RSpec.describe "Admin: Static Pages", type: :system do
  include ActionText::SystemTestHelper

  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:sources) { create_list :static_page, 3 }

    before { visit admin_static_page_bases_path }

    it "shows all resources" do
      StaticPage::Base.all.each do |static_page|
        expect(page).to have_text(static_page.id)
        expect(page).to have_text(static_page.slug)
        expect(page).to have_text(static_page.title)
      end
    end
  end

  describe "#show" do
    let!(:static_page) { create :static_page }
    let!(:static_page_section_paragraph) do
      create :static_page_section_paragraph, section: create(:static_page_section, section_type: :paragraph, static_page: static_page)
    end
    let!(:static_page_section_item) do
      create :static_page_section_item, section: create(:static_page_section, section_type: :items, static_page: static_page)
    end
    let!(:static_page_section_reference) do
      create :static_page_section_reference, section: create(:static_page_section, section_type: :references, static_page: static_page)
    end

    before do
      visit admin_static_page_bases_path
      find("a[href='/admin/static_page_bases/#{static_page.id}']", text: "View").click
    end

    it "shows Static Page detail" do
      expect(page).to have_text(static_page.id)
      expect(page).to have_text(static_page.slug)
      expect(page).to have_text(static_page.title)
      expect(page).to have_text(static_page.image_credits)
      expect(page).to have_text(static_page.image_credits_url)
    end

    it "shows Paragraph section detail" do
      expect(page).to have_text(static_page_section_paragraph.section.id)
      expect(page).to have_text(static_page_section_paragraph.section.title)
      expect(page).to have_text(static_page_section_paragraph.section.title_size)
      expect(page).to have_text(static_page_section_paragraph.section.slug)
      expect(page).to have_text(ActionText::Content.new(static_page_section_paragraph.text).to_plain_text)
      expect(page).to have_text(static_page_section_paragraph.image_position)
      expect(page).to have_text(static_page_section_paragraph.image_credits)
      expect(page).to have_text(static_page_section_paragraph.image_credits_url)
    end

    it "shows Item section detail" do
      expect(page).to have_text(static_page_section_item.section.id)
      expect(page).to have_text(static_page_section_item.section.title)
      expect(page).to have_text(static_page_section_item.section.title_size)
      expect(page).to have_text(static_page_section_item.section.slug)
      expect(page).to have_text(static_page_section_item.title)
      expect(page).to have_text(ActionText::Content.new(static_page_section_item.description).to_plain_text)
    end

    it "shows Reference section detail" do
      expect(page).to have_text(static_page_section_reference.section.id)
      expect(page).to have_text(static_page_section_reference.section.title)
      expect(page).to have_text(static_page_section_reference.section.title_size)
      expect(page).to have_text(static_page_section_reference.section.slug)
      expect(page).to have_text(static_page_section_reference.slug)
      expect(page).to have_text(ActionText::Content.new(static_page_section_reference.text).to_plain_text)
    end
  end

  describe "#create" do
    let(:new_static_page) { StaticPage::Base.last }

    before do
      visit admin_static_page_bases_path
      click_on "New Static Page"
    end

    it "allows to create new static page" do
      # base static page
      fill_in "static_page_base[translations_attributes][0][title]", with: "New title"
      fill_in "static_page_base[translations_attributes][0][image_credits]", with: "New image credits"
      fill_in "static_page_base[slug]", with: "New slug"
      attach_file "static_page_base[image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      fill_in "static_page_base[image_credits_url]", with: "https://image-credits.com"
      # paragraph static page section
      click_on "Add New Section"
      fill_in "static_page_base[sections_attributes][0][translations_attributes][0][title]", with: "New Paragraph title"
      fill_in "static_page_base[sections_attributes][0][slug]", with: "New Paragraph slug"
      fill_in "static_page_base[sections_attributes][0][title_size]", with: "2"
      select "paragraph", from: "static_page_base[sections_attributes][0][section_type]"
      fill_in "static_page_base[sections_attributes][0][section_paragraph_attributes][translations_attributes][0][image_credits]", with: "New Paragraph image credits"
      fill_in_rich_text_area "static_page_base[sections_attributes][0][section_paragraph_attributes][translations_attributes][0][text]", with: "New Paragraph text"
      select "left", from: "static_page_base[sections_attributes][0][section_paragraph_attributes][image_position]"
      fill_in "static_page_base[sections_attributes][0][section_paragraph_attributes][image_credits_url]", with: "https://paragraph-image-credits.com"
      # items static page section
      click_on "Add New Section"
      fill_in "static_page_base[sections_attributes][1][translations_attributes][0][title]", with: "New Items title"
      fill_in "static_page_base[sections_attributes][1][slug]", with: "New Items slug"
      fill_in "static_page_base[sections_attributes][1][title_size]", with: "2"
      select "items", from: "static_page_base[sections_attributes][1][section_type]"
      click_on "Add New Section item"
      fill_in "static_page_base[sections_attributes][1][section_items_attributes][0][translations_attributes][0][title]", with: "New Item title"
      fill_in_rich_text_area "static_page_base[sections_attributes][1][section_items_attributes][0][translations_attributes][0][description]", with: "New Item description"
      attach_file "static_page_base[sections_attributes][1][section_items_attributes][0][image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      # references static page section
      click_on "Add New Section"
      fill_in "static_page_base[sections_attributes][2][translations_attributes][0][title]", with: "New References title"
      fill_in "static_page_base[sections_attributes][2][slug]", with: "New References slug"
      fill_in "static_page_base[sections_attributes][2][title_size]", with: "2"
      select "references", from: "static_page_base[sections_attributes][2][section_type]"
      click_on "Add New Section reference"
      fill_in "static_page_base[sections_attributes][2][section_references_attributes][0][slug]", with: "New Reference slug"
      fill_in_rich_text_area "static_page_base[sections_attributes][2][section_references_attributes][0][translations_attributes][0][text]", with: "New Reference text"

      click_on "Create Static Page"

      expect(page).to have_current_path(admin_static_page_base_path(new_static_page))
      expect(page).to have_text("Static Page was successfully created.")
      # base static page
      expect(page).to have_text("New slug")
      expect(page).to have_text("New title")
      expect(page).to have_text("New image credits")
      expect(page).to have_text("https://image-credits.com")
      # paragraph static page section
      expect(page).to have_text("New Paragraph title")
      expect(page).to have_text("New Paragraph slug")
      expect(page).to have_text("left")
      expect(page).to have_text("New Paragraph image credits")
      expect(page).to have_text("New Paragraph text")
      expect(page).to have_text("https://paragraph-image-credits.com")
      # items static page section
      expect(page).to have_text("New Items title")
      expect(page).to have_text("New Items slug")
      expect(page).to have_text("New Item title")
      expect(page).to have_text("New Item description")
      # references static page section
      expect(page).to have_text("New References title")
      expect(page).to have_text("New References slug")
      expect(page).to have_text("New Reference slug")
      expect(page).to have_text("New Reference text")
    end

    it "shows error when validation fails" do
      fill_in "static_page_base[translations_attributes][0][title]", with: ""

      click_on "Create Static Page"

      expect(page).to have_current_path(admin_static_page_bases_path)
      expect(page).to have_text("can't be blank")
    end
  end

  describe "#update" do
    let!(:static_page) { create :static_page }
    let!(:static_page_section_paragraph) do
      create :static_page_section_paragraph, section: create(:static_page_section, section_type: :paragraph, position: 1, static_page: static_page)
    end
    let!(:static_page_section_item) do
      create :static_page_section_item, section: create(:static_page_section, section_type: :items, position: 2, static_page: static_page)
    end
    let!(:static_page_section_reference) do
      create :static_page_section_reference, section: create(:static_page_section, section_type: :references, position: 3, static_page: static_page)
    end

    before do
      visit admin_static_page_bases_path
      find("a[href='/admin/static_page_bases/#{static_page.id}/edit']").click
    end

    it "allows to update existing static page" do
      # base static page
      all("fieldset.has-many-toggle-collapse").each { |element| element.click }
      fill_in "static_page_base[translations_attributes][0][title]", with: "Updated title"
      fill_in "static_page_base[translations_attributes][0][image_credits]", with: "Updated image credits"
      fill_in "static_page_base[slug]", with: "Updated slug"
      attach_file "static_page_base[image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      fill_in "static_page_base[image_credits_url]", with: "https://updated-image-credits.com"
      # paragraph static page section
      fill_in "static_page_base[sections_attributes][0][translations_attributes][0][title]", with: "Updated Paragraph title"
      fill_in "static_page_base[sections_attributes][0][slug]", with: "Updated Paragraph slug"
      fill_in "static_page_base[sections_attributes][0][section_paragraph_attributes][translations_attributes][0][image_credits]", with: "Updated Paragraph image credits"
      fill_in_rich_text_area "static_page_base[sections_attributes][0][section_paragraph_attributes][translations_attributes][0][text]", with: "Updated Paragraph text"
      select "left", from: "static_page_base[sections_attributes][0][section_paragraph_attributes][image_position]"
      fill_in "static_page_base[sections_attributes][0][section_paragraph_attributes][image_credits_url]", with: "https://updated-paragraph-image-credits.com"
      # items static page section
      all("fieldset.has-many-toggle-collapse").each { |element| element.click }
      fill_in "static_page_base[sections_attributes][1][translations_attributes][0][title]", with: "Updated Items title"
      fill_in "static_page_base[sections_attributes][1][slug]", with: "Updated Items slug"
      fill_in "static_page_base[sections_attributes][1][section_items_attributes][0][translations_attributes][0][title]", with: "Updated Item title"
      fill_in_rich_text_area "static_page_base[sections_attributes][1][section_items_attributes][0][translations_attributes][0][description]", with: "Updated Item description"
      attach_file "static_page_base[sections_attributes][1][section_items_attributes][0][image]", Rails.root.join("spec/fixtures/files/picture.jpg")
      # references static page section
      all("fieldset.has-many-toggle-collapse").each { |element| element.click }
      fill_in "static_page_base[sections_attributes][2][translations_attributes][0][title]", with: "Updated References title"
      fill_in "static_page_base[sections_attributes][2][slug]", with: "Updated References slug"
      fill_in "static_page_base[sections_attributes][2][section_references_attributes][0][slug]", with: "Updated Reference slug"
      fill_in_rich_text_area "static_page_base[sections_attributes][2][section_references_attributes][0][translations_attributes][0][text]", with: "Updated Reference text"

      click_on "Update Static Page"

      expect(page).to have_current_path(admin_static_page_base_path(static_page))
      expect(page).to have_text("Static Page was successfully updated.")
      # base static page
      expect(page).to have_text("Updated slug")
      expect(page).to have_text("Updated title")
      expect(page).to have_text("Updated image credits")
      expect(page).to have_text("https://updated-image-credits.com")
      # paragraph static page section
      expect(page).to have_text("Updated Paragraph title")
      expect(page).to have_text("Updated Paragraph slug")
      expect(page).to have_text("left")
      expect(page).to have_text("Updated Paragraph image credits")
      expect(page).to have_text("Updated Paragraph text")
      expect(page).to have_text("https://updated-paragraph-image-credits.com")
      # items static page section
      expect(page).to have_text("Updated Items title")
      expect(page).to have_text("Updated Items slug")
      expect(page).to have_text("Updated Item title")
      expect(page).to have_text("Updated Item description")
      # references static page section
      expect(page).to have_text("Updated References title")
      expect(page).to have_text("Updated References slug")
      expect(page).to have_text("Updated Reference slug")
      expect(page).to have_text("Updated Reference text")
    end
  end

  describe "#delete" do
    let!(:static_page) { create :static_page }

    before do
      visit admin_static_page_bases_path
    end

    it "deletes existing static_page" do
      expect(page).to have_text(static_page.slug)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/static_page_bases/#{static_page.id}']").click
      end

      expect(page).not_to have_text(static_page.slug)
    end
  end
end
