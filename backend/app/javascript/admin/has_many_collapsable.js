// Enable collapsing for all existing has_many Admin sections
function initHasManySections() {
    $(".has-many-collapsed fieldset.has_many_fields").each((index, value) => {
        attachHasManySectionToggleListener($(value));
    });
}

// Enable collapsing for newly added has_many Admin sections
// Also updates legend of newly added section and automatically uncollapses this one
function updateLastHasManyContainer() {
    let $lastContainer = $("a.button.has_many_remove").last().closest("fieldset.has_many_fields");
    attachHasManySectionToggleListener($lastContainer);
    $lastContainer.find("div.has-many-section").removeClass("section-hidden");
}

// Attach listener which will toggle visibility of section
function attachHasManySectionToggleListener(container) {
    container.find(".has-many-toggle-collapse legend").click((event) => {
        let $target = $(event.target);
        $target.closest("fieldset.has_many_fields").find("div.has-many-section").toggleClass("section-hidden");
    });
}

$(document).ready(initHasManySections);
$(document).on("has_many_add:after", ".has_many_container", updateLastHasManyContainer);
