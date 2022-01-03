# frozen_string_literal: true

module Api
  module Pagination
    extend ActiveSupport::Concern

    def meta_attributes(collection, extra_meta = {})
      {
        current_page: collection.current_page,
        next_page: collection.next_page,
        prev_page: collection.previous_page,
        total_pages: collection.total_pages,
        total_count: collection.total_entries
      }.merge(extra_meta)
    end
  end
end
