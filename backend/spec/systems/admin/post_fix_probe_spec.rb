require "system_helper"

RSpec.describe "Admin post-fix probes", type: :system do
  let(:admin_user) { create :admin_user }
  let!(:site_scope) { create :site_scope }

  before { login_as admin_user }

  it "shows created site page body text" do
    visit "/admin/site_pages/new"

    fill_in "site_page[translations_attributes][0][title]", with: "Probe title"
    select site_scope.name, from: "site_page[site_scope_id]"
    find(".locale-en trix-editor, .locale.active trix-editor", wait: 10)

    deadline = Time.now + 10
    loop do
      ready = page.evaluate_script(
        "(function() { " \
        "var el = document.querySelector(\".locale-en trix-editor, .locale.active trix-editor\"); " \
        "return !!(el && el.editor); " \
        "})()"
      )
      break if ready
      raise "Trix editor not initialised after 10 seconds" if Time.now > deadline

      sleep 0.2
    end

    page.execute_script(<<~JS, "<p>Probe body</p>")
      var editor = document.querySelector(".locale-en trix-editor, .locale.active trix-editor");
      editor.editor.loadHTML(arguments[0]);
    JS
    fill_in "site_page[priority]", with: "100"
    fill_in "site_page[slug]", with: "probe-site-page"

    click_on "Create Site page"

    expect(page).to have_text("Site page was successfully created.")
    expect(page).to have_text("Probe body")
  end

  it "renders unique homepage site scope options" do
    visit "/admin/homepages/new"

    option_values = page.evaluate_script(
      "Array.from(document.querySelectorAll('select[name=\"homepage[site_scope_id]\"] option')).map(function(option) { return option.textContent.trim(); }).filter(Boolean)"
    )

    puts "\n=== HOMEPAGE SITE SCOPE OPTIONS ==="
    puts option_values.inspect

    expect(option_values.count(site_scope.name)).to eq(1)
  end

  it "reports journey trix readiness" do
    visit "/admin/journeys/new"

    click_on "Add New Journey step"
    click_on "Add New Journey step"
    sleep 1

    readiness = page.evaluate_script(<<~JS)
      ({
        stepTypes: Array.from(document.querySelectorAll('select[name*="[step_type]"]')).map(function(input) {
          return input.name
        }),
        trixInputs: Array.from(document.querySelectorAll('trix-editor')).map(function(editor) {
          return {
            input: editor.getAttribute('input'),
            hasEditor: !!editor.editor,
            hidden: editor.offsetParent === null
          }
        })
      })
    JS

    puts "\n=== JOURNEY TRIX READINESS ==="
    puts readiness.inspect

    expect(readiness.fetch("stepTypes").size).to eq(2)
  end

  it "reports static page trix readiness" do
    visit "/admin/static_page_bases/new"

    click_on "Add New Section"
    click_on "Add New Section"
    sleep 1

    readiness = page.evaluate_script(<<~JS)
      ({
        sectionTitles: Array.from(document.querySelectorAll('input[name*="[sections_attributes]"][name$="[title]"]')).map(function(input) {
          return input.name
        }),
        trixInputs: Array.from(document.querySelectorAll('trix-editor')).map(function(editor) {
          return {
            input: editor.getAttribute('input'),
            hasEditor: !!editor.editor,
            hidden: editor.offsetParent === null
          }
        })
      })
    JS

    puts "\n=== STATIC PAGE TRIX READINESS ==="
    puts readiness.inspect

    expect(readiness.fetch("sectionTitles").size).to be >= 2
  end

  it "reports static page section item button visibility" do
    visit "/admin/static_page_bases/new"

    click_on "Add New Section"
    click_on "Add New Section"
    page.execute_script("document.querySelectorAll('.section-hidden').forEach(function(el){ el.classList.remove('section-hidden') })")
    select "items", from: "static_page_base[sections_attributes][1][section_type]"
    sleep 1

    visibility = page.evaluate_script(<<~JS)
      ({
        sectionTypes: Array.from(document.querySelectorAll('select[name*="[section_type]"]')).map(function(select) {
          return {
            name: select.name,
            value: select.value
          }
        }),
        itemButtons: Array.from(document.querySelectorAll('a.button.has_many_add')).filter(function(button) {
          return button.textContent.indexOf('Add New Section item') !== -1
        }).map(function(button) {
          return {
            hidden: button.offsetParent === null,
            sectionIndex: button.closest('fieldset.has_many_fields') && button.closest('fieldset.has_many_fields').querySelector('select[name*="[section_type]"]') && button.closest('fieldset.has_many_fields').querySelector('select[name*="[section_type]"]').name
          }
        }),
        visibleDependencyFields: Array.from(document.querySelectorAll('.select-dependency-field')).map(function(field) {
          return {
            availableFor: field.getAttribute('data-available-for'),
            hidden: field.offsetParent === null,
            sectionIndex: field.closest('fieldset.has_many_fields') && field.closest('fieldset.has_many_fields').querySelector('select[name*="[section_type]"]') && field.closest('fieldset.has_many_fields').querySelector('select[name*="[section_type]"]').name
          }
        })
      })
    JS

    puts "\n=== STATIC PAGE ITEM BUTTON VISIBILITY ==="
    puts visibility.inspect

    expect(visibility.fetch("itemButtons").count { |button| !button.fetch("hidden") }).to eq(1)
  end
end