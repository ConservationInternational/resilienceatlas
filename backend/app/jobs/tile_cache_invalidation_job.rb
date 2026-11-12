class TileCacheInvalidationJob
  include Sidekiq::Job
  sidekiq_options retry: 5

  def perform(id)
    invalidation = TileCacheInvalidation.find(id)
    invalidation.submit!
    self.class.perform_in(30.seconds, id) if invalidation.reload.status == "submitted"
  end
end
