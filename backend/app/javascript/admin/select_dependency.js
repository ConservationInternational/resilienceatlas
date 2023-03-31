// Set up fields for already existing sections at has many Admin container
function initSelectDependencyFields() {
    $(".select-dependency-container").each((index, value) => {
        let $this = $(value);
        toggleSelectDependencyFields($this);
        attachSelectDependencyListener($this);
    });
}

// Set up fields for newly added section at has many Admin container
function updateLastHasManyDynamicFields() {
    let $lastContainer = $("a.button.has_many_remove").last().closest("fieldset.has_many_fields").find(".select-dependency-container");
    toggleSelectDependencyFields($lastContainer);
    attachSelectDependencyListener($lastContainer);
}

// Attach listener to selected field which change will trigger setting up visible/hidden fields
function attachSelectDependencyListener(container) {
    container.find(".select-dependency-controller").change((event) => {
        toggleSelectDependencyFields(container);
    });
}

// Check if value from fields controller corresponds to value for appropriate field and show/hide such field
function toggleSelectDependencyFields(container) {
    let selectedOption = container.find(".select-dependency-controller").val();
    container.find(".select-dependency-field").each((index, value) => {
        let $this = $(value);
        if($.inArray(selectedOption, $this.data("availableFor")) === -1) {
            removeRequiredFlagFromInput($this);
            $this.hide();
        } else {
            ($.inArray(selectedOption, $this.data("requiredFor")) !== -1) ? addRequiredFlagToInput($this) : removeRequiredFlagFromInput($this);
            $this.show();
        }
    });
}

$(document).ready(initSelectDependencyFields);
$(document).on("has_many_add:after", ".has_many_container", updateLastHasManyDynamicFields);
