// Implements ActiveAdmin has-many.js click handler without jQuery dependency.
// The gem's has-many.js is not loaded because active_admin/base is a Sprockets
// directive that is ignored when active_admin.js is served as an ES6 module.

import $ from "jquery";

function recomputePositions(parent) {
  const inputName = parent.getAttribute("data-sortable");
  if (!inputName) return;

  let position = parseInt(parent.getAttribute("data-sortable-start") || "0", 10);

  parent.querySelectorAll(":scope > fieldset").forEach(function (fieldset) {
    const destroyInput = fieldset.querySelector(":scope > ol > .input > [name$='[_destroy]']");
    const sortableInput = fieldset.querySelector(`:scope > ol > .input > [name$='[${inputName}]']`);

    if (!sortableInput) return;

    sortableInput.value = destroyInput && destroyInput.checked ? "" : String(position);
    if (!(destroyInput && destroyInput.checked)) {
      position += 1;
    }
  });
}

function triggerHasManyEvent(parent, eventName, detail, jQueryArgs) {
  const nativeEvent = new CustomEvent(eventName, {
    bubbles: true,
    cancelable: true,
    detail: detail,
  });
  parent.dispatchEvent(nativeEvent);

  let jqueryEvent = null;
  jqueryEvent = $.Event(eventName);
  $(parent).trigger(jqueryEvent, jQueryArgs);

  return {
    nativeEvent: nativeEvent,
    jqueryEvent: jqueryEvent,
  };
}

document.addEventListener("click", function (event) {
  const target = event.target.closest("a.button.has_many_add");
  if (!target) return;

  event.preventDefault();

  const parent = target.closest(".has_many_container");
  if (!parent) return;

  const beforeAdd = triggerHasManyEvent(parent, "has_many_add:before", { parent: parent }, [parent]);
  if (beforeAdd.nativeEvent.defaultPrevented || (beforeAdd.jqueryEvent && beforeAdd.jqueryEvent.isDefaultPrevented())) return;

  const existingIndex = parent.getAttribute("data-has_many_index");
  let objectCount = existingIndex === null ? parent.querySelectorAll(":scope > fieldset").length - 1 : parseInt(existingIndex, 10);
  objectCount += 1;
  parent.setAttribute("data-has_many_index", String(objectCount));

  const placeholder = target.dataset.placeholder;
  const regex = new RegExp(placeholder, "g");
  const html = target.dataset.html.replace(regex, objectCount);

  const wrapper = document.createElement("template");
  wrapper.innerHTML = html.trim();
  const newFieldset = wrapper.content.firstElementChild;
  parent.insertBefore(newFieldset, target);

  recomputePositions(parent);
  triggerHasManyEvent(parent, "has_many_add:after", { fieldset: newFieldset, parent: parent }, [newFieldset, parent]);
});

document.addEventListener("click", function (event) {
  const target = event.target.closest("a.button.has_many_remove");
  if (!target) return;

  event.preventDefault();

  const fieldset = target.closest("fieldset.inputs");
  if (!fieldset) return;

  const destroyInput = fieldset.querySelector("input[name$='[_destroy]']");
  if (destroyInput) {
    destroyInput.value = "1";
    fieldset.style.display = "none";
  } else {
    fieldset.remove();
  }

  const parent = target.closest(".has_many_container");
  if (parent) {
    recomputePositions(parent);
  }
});

document.addEventListener("change", function (event) {
  const target = event.target;
  if (!(target instanceof Element) || !target.matches(".has_many_container[data-sortable] [name$='[_destroy]']")) return;

  const parent = target.closest(".has_many_container");
  if (parent) {
    recomputePositions(parent);
  }
});
