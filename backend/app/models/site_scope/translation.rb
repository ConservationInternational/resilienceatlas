class SiteScope::Translation < Globalize::ActiveRecord::Translation
  def self.ransackable_attributes(auth_object = nil)
    %w[created_at id linkback_text locale name site_scope_id updated_at]
  end
end
