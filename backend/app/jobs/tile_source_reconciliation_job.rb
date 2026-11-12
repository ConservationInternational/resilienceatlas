class TileSourceReconciliationJob
  include Sidekiq::Job
  sidekiq_options queue: :imports, retry: false

  def perform(id)
    record = TileSourceImport.find(id)
    return if record.status == "completed"
    TileSourceLifecycle.resume(record).reconcile!
  end
end
