module TileSecurityImportTask
  def self.wrap(*names)
    names.each do |name|
      task = Rake::Task[name]
      actions = task.actions.dup
      task.clear_actions
      task.enhance do |current, arguments|
        if ENV["TILE_IMPORT_RUN_ID"].present?
          TileSourceLifecycle.authorize_enclosing_import!
          actions.each { |action| action.call(current, arguments) }
        else
          TileSourceLifecycle.run_task!(name) do
            actions.each { |action| action.call(current, arguments) }
          end
        end
      end
    end
  end
end
