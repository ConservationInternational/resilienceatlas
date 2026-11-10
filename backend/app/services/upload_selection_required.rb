class UploadSelectionRequired < StandardError
  attr_reader :metadata

  def initialize(message, metadata = {})
    @metadata = metadata
    super(message)
  end
end
