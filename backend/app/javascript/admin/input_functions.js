export function addRequiredFlagToInput(field) {
    let label = field.find("label");
    field.addClass("required");
    if(label.has("abbr").length === 0) { label.html(label.text() + "<abbr title=\"required\">*</abbr>"); }
}

export function removeRequiredFlagFromInput(field) {
    let label = field.find("label");
    field.removeClass("required");
    label.find("abbr").remove();
}
