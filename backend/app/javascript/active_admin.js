// Import and start Rails UJS for ActiveAdmin
import Rails from "@rails/ujs"
Rails.start()

// Load ActiveAdmin core assets using Sprockets (these are not available as ES6 modules)
//= require active_admin/base
//= require active_admin/sortable
//= require trix
//= require activeadmin_addons/all
//= require active_admin/active_admin_globalize
//= require_tree ./utils
//= require_tree ./admin