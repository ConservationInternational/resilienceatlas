# Pin npm packages by running ./bin/importmap

pin "application"
pin "active_admin"

# Pin all admin JS files for import from active_admin.js
pin_all_from "app/javascript/admin", under: "admin"

pin "@rails/ujs", to: "https://ga.jspm.io/npm:@rails/ujs@7.0.4/lib/assets/compiled/rails-ujs.js"

pin "@rails/actiontext", to: "actiontext.js"

pin "jquery", to: "https://ga.jspm.io/npm:jquery@3.6.3/dist/jquery.js"
pin "turbolinks", to: "https://ga.jspm.io/npm:turbolinks@5.2.0/dist/turbolinks.js"
pin "trix", to: "https://ga.jspm.io/npm:trix@2.0.4/dist/trix.esm.min.js"
