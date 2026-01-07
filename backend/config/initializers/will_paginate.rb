# WillPaginate compatibility aliases for Kaminari-style methods
# Only apply if WillPaginate is loaded and the method exists
Rails.application.config.after_initialize do
  if defined?(WillPaginate::ActiveRecord::RelationMethods)
    WillPaginate::ActiveRecord::RelationMethods.module_eval do
      alias_method :per, :per_page if method_defined?(:per_page) && !method_defined?(:per)
      alias_method :num_pages, :total_pages if method_defined?(:total_pages) && !method_defined?(:num_pages)
    end
  end

  if defined?(ActiveRecord::Relation)
    ActiveRecord::Relation.class_eval do
      alias_method :total_count, :count unless method_defined?(:total_count)
    end
  end
end
