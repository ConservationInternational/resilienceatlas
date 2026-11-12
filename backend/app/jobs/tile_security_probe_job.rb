class TileSecurityProbeJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(id)
    TileSecurityProbe.new(TileSecurityVerification.find(id)).call
  end
end
