// Implements ActiveAdmin has-many.js click handler without jQuery dependency.
// The gem's has-many.js is not loaded because active_admin/base is a Sprockets
// directive that is ignored when active_admin.js is served as an ES6 module.

document.addEventListener("click", function (event) {
  const target = event.target.closest("a.button.has_many_add");
  if (!target) return;

  event.preventDefault();

  const parent = target.parentNode;
  const objectCount = parent.querySelectorAll(":scope > fieldset").length;
  const placeholder = target.dataset.placeholder;
  const regex = new RegExp(placeholder, "g");
  const html = target.dataset.html.replace(regex, objectCount);

  const wrapper = document.createElement("div");
  wrapper.innerHTML = html;
  const newFieldset = wrapper.firstElementChild || wrapper.firstChild;
  parent.insertBefore(newFieldset, target);

  parent.dispatchEvent(new CustomEvent("has_many_add:after", { bubbles: true, detail: { fieldset: newFieldset, parent: parent } }));
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
});
