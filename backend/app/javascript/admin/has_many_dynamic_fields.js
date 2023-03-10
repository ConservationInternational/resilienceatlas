// Set up fields for already existing sections at has many Admin container
function initHasManyDynamicFields() {
    $(".has_many_container fieldset.has_many_fields").each((index, value) => {
        let $this = $(value);
        toggleHasManySectionFields($this);
        attachListenerForFieldsControllerChange($this);
    });
}

// Set up fields for newly added section at has many Admin container
function updateLastHasManyDynamicFields() {
    let $lastContainer = $("a.button.has_many_remove").last().closest("fieldset.has_many_fields");
    toggleHasManySectionFields($lastContainer);
    attachListenerForFieldsControllerChange($lastContainer);
}

// Attach listener to selected field which change will trigger setting up visible/hidden fields
function attachListenerForFieldsControllerChange(container) {
    container.find(".fields-controller").change((event) => {
        toggleHasManySectionFields(container);
    });
}

// Check if value from fields controller corresponds to value for appropriate field and show/hide such field
function toggleHasManySectionFields(container) {
    let selectedOption = container.find(".fields-controller").val();
    container.find("div.field-section").each((index, value) => {
        let $this = $(value);
        if($.inArray(selectedOption, $this.data("availableFor")) === -1) {
            $this.addClass("field-hidden");
        } else {
            $this.removeClass("field-hidden");
        }
    });
}

$(document).ready(initHasManyDynamicFields);
$(document).on("has_many_add:after", ".has_many_container", updateLastHasManyDynamicFields);
