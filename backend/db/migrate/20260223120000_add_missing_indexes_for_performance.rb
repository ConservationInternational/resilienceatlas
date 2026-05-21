class AddMissingIndexesForPerformance < ActiveRecord::Migration[7.2]
  def change
    # site_scopes.subdomain — queried on every API request via SitesFilters#set_site
    add_index :site_scope_translations, :locale, if_not_exists: true
    unless index_exists?(:site_scopes, :subdomain)
      # Use a non-unique index since production data may legitimately have
      # duplicate subdomains (e.g. multiple "amazonia" site scopes)
      add_index :site_scopes, :subdomain
    end

    # share_urls.uid — used for lookups in ShareUrlsController#show, no index at all
    unless index_exists?(:share_urls, :uid)
      add_index :share_urls, :uid, unique: true
    end

    # layers.slug — used for lookups; non-unique because some rows have empty slugs
    unless index_exists?(:layers, :slug)
      add_index :layers, :slug
    end

    # models_site_scopes join table — no indexes at all
    unless index_exists?(:models_site_scopes, :model_id)
      add_index :models_site_scopes, :model_id
    end
    unless index_exists?(:models_site_scopes, :site_scope_id)
      add_index :models_site_scopes, :site_scope_id
    end
    unless index_exists?(:models_site_scopes, [:model_id, :site_scope_id])
      add_index :models_site_scopes, [:model_id, :site_scope_id], unique: true
    end
  end
end
