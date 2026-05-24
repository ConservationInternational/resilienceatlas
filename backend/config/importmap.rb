# Pin npm packages by running ./bin/importmap

pin "application"
pin "active_admin"

# Pin all admin JS files for import from active_admin.js
pin_all_from "app/javascript/admin", under: "admin"

pin "@rails/ujs", to: "rails-ujs-esm.js"

pin "@rails/actiontext", to: "actiontext.js"

pin "jquery", to: "jquery-esm.js"
pin "turbolinks", to: "https://ga.jspm.io/npm:turbolinks@5.2.0/dist/turbolinks.js"
pin "trix", to: "trix-esm.js"
