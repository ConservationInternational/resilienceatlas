# Lightweight serializer for site_scope when embedded in scope_dataset responses
class ScopeDatasetSiteScopeSerializer < ActiveModel::Serializer
  attributes :id, :name, :subdomain
end
