class Admin::AiChatController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :check_rate_limit, only: [:message]

  BEDROCK_REGION = ENV.fetch("AWS_REGION", "us-east-1")
  BEDROCK_AGENT_ID = ENV["BEDROCK_AGENT_ID"]
  BEDROCK_AGENT_ALIAS_ID = ENV["BEDROCK_AGENT_ALIAS_ID"]
  # Max messages per admin user per minute
  RATE_LIMIT_MAX = 20
  RATE_LIMIT_WINDOW = 60 # seconds

  def message
    user_message = params.require(:message)
    session_id = current_session_id

    bedrock = Aws::BedrockAgentRuntime::Client.new(region: BEDROCK_REGION)

    response_text = []
    bedrock.invoke_agent(
      agent_id: BEDROCK_AGENT_ID,
      agent_alias_id: BEDROCK_AGENT_ALIAS_ID,
      session_id: session_id,
      input_text: user_message,
      session_state: {
        session_attributes: agent_session_attributes
      }
    ) do |stream|
      stream.on_chunk_event do |chunk|
        response_text << chunk.bytes.force_encoding("UTF-8")
      end
    end

    render json: {success: true, message: response_text.join, session_id: session_id}
  rescue Aws::BedrockAgentRuntime::Errors::ServiceError => e
    render json: {success: false, message: "Agent error: #{e.message}"}, status: :service_unavailable
  rescue => e
    Rails.logger.error "Admin AI chat error: #{e.class}: #{e.message}"
    render json: {success: false, message: "Unexpected error. Please try again."}, status: :internal_server_error
  end

  def reset
    session.delete(:bedrock_session_id)
    render json: {success: true}
  end

  private

  def current_session_id
    session[:bedrock_session_id] ||= SecureRandom.uuid
  end

  # Encodes the current admin's role and allowed site scopes as Bedrock session
  # attributes so the action groups Lambda can enforce authorization without a
  # separate API call.
  def agent_session_attributes
    user = current_admin_user
    scope_ids = user.allowed_site_scope_ids_for_agent  # "*" or ["1","2",...]
    {
      "admin_user_id" => user.id.to_s,
      "admin_role" => user.role.to_s,
      "allowed_site_scope_ids" => scope_ids == "*" ? "*" : scope_ids.join(",")
    }
  end

  def check_rate_limit
    key = "ai_chat_rate:#{current_admin_user.id}"
    count = Rails.cache.increment(key, 1, expires_in: RATE_LIMIT_WINDOW)
    if count > RATE_LIMIT_MAX
      render json: {success: false, message: "Too many requests. Please wait before sending another message."}, status: :too_many_requests
    end
  end
end
