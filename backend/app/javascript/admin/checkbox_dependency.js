function initCheckboxDependentFields() {
    $('*[data-if="checked"]').each((index, value) => {
        let $this = $(value);
        attachCheckboxDependentFieldListener($this);
        runDependentFieldAction($this, $this.is(":checked"));
    });
}

function attachCheckboxDependentFieldListener(element) {
    element.change((event) => {
        runDependentFieldAction(element, element.is(":checked"));
    });
}

function runDependentFieldAction(element, status) {
    if(status) {
        if(element.data("action") === "show") {
            $(element.data("target")).show();
        } else {
            $(element.data("target")).hide();
        }
    } else {
        if(element.data("action") === "hide") {
            $(element.data("target")).show();
        } else {
            $(element.data("target")).hide();
        }
    }
}

$(document).ready(initCheckboxDependentFields);
