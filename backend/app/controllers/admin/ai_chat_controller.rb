class Admin::AiChatController < ApplicationController
  # Skip CSRF verification for the JSON fetch endpoints in this controller.
  # Security is provided by authenticate_admin_user! (Devise session auth) below.
  # CSRF token mismatch caused InvalidAuthenticityToken because form_authenticity_token
  # is rendered at page load but the session state can diverge between page load and
  # the async fetch, especially with SameSite=Lax cookie_store sessions.
  skip_before_action :verify_authenticity_token

  before_action :authenticate_admin_user!
  before_action :check_rate_limit, only: [:message]

  BEDROCK_REGION = ENV.fetch("AWS_REGION", "us-east-1")
  BEDROCK_AGENT_ID = ENV["BEDROCK_AGENT_ID"]
  BEDROCK_AGENT_ALIAS_ID = ENV["BEDROCK_AGENT_ALIAS_ID"]
  # Max messages per admin user per minute
  RATE_LIMIT_MAX = 20
  RATE_LIMIT_WINDOW = 60 # seconds

  MAX_MESSAGE_LENGTH = 4_000

  def message
    user_message = params.require(:message).to_s
    if user_message.length > MAX_MESSAGE_LENGTH
      return render json: {success: false, message: "Message too long (max #{MAX_MESSAGE_LENGTH} characters)."}, status: :unprocessable_entity
    end
    session_id = current_session_id

    bedrock = Aws::BedrockAgentRuntime::Client.new(region: BEDROCK_REGION)

    response_text = []
    tool_calls = []
    started_at = Time.current
    bedrock.invoke_agent(
      agent_id: BEDROCK_AGENT_ID,
      agent_alias_id: BEDROCK_AGENT_ALIAS_ID,
      session_id: session_id,
      enable_trace: true,
      input_text: user_message,
      session_state: {
        session_attributes: agent_session_attributes
      }
    ) do |stream|
      stream.on_chunk_event do |chunk|
        response_text << chunk.bytes.force_encoding("UTF-8")
      end
      stream.on_trace_event do |trace|
        orch = trace.to_h.dig(:trace, :orchestration_trace)
        next unless orch
        if (input = orch.dig(:invocation_input, :action_group_invocation_input))
          entry = "#{input[:api_path] || input[:function]} #{input.dig(:request_body, :content, :"application/json")&.map { |p| "#{p[:name]}=#{p[:value].to_s[0..80]}" }&.join(", ")}"
          tool_calls << entry
          Rails.logger.info "AiChat tool_call: #{entry}"
        end
        if (obs = orch.dig(:observation, :action_group_invocation_output, :text))
          Rails.logger.info "AiChat tool_result[#{tool_calls.size}]: #{obs[0..300]}"
        end
        if (rationale = orch.dig(:model_invocation_output, :raw_response, :content))
          Rails.logger.debug "AiChat rationale: #{rationale.to_s[0..300]}"
        end
      end
    end

    elapsed = Time.current - started_at
    response_body = response_text.join

    if response_body.blank?
      Rails.logger.warn "AiChat: Bedrock returned empty response after #{elapsed.round(1)}s " \
                        "(session=#{session_id} user=#{current_admin_user.id}) " \
                        "tool_calls=#{tool_calls.inspect}"
      Rollbar.warning("AI chat: Bedrock returned empty response",
        session_id: session_id,
        admin_user_id: current_admin_user.id,
        elapsed_seconds: elapsed.round(1),
        tool_calls: tool_calls)
      return render json: {
        success: false,
        message: "The agent didn't return a response. This can happen when it gets " \
                 "confused during multi-step tasks — please try rephrasing or resetting the conversation."
      }, status: :service_unavailable
    end

    Rails.logger.info "AiChat: Bedrock response received in #{elapsed.round(1)}s " \
                      "(#{response_body.length} chars, session=#{session_id})"

    persist_messages(session_id, user_message, response_body)

    render json: {success: true, message: response_body, session_id: session_id}
  rescue Aws::BedrockAgentRuntime::Errors::ServiceError => e
    Rails.logger.error "AiChat: Bedrock service error: #{e.class}: #{e.message}"
    Rollbar.error(e, session_id: session_id, admin_user_id: current_admin_user&.id)
    render json: {success: false, message: "Agent error: #{e.message}"}, status: :service_unavailable
  rescue => e
    Rails.logger.error "Admin AI chat error: #{e.class}: #{e.message}"
    render json: {success: false, message: "Unexpected error. Please try again."}, status: :internal_server_error
  end

  def history
    messages = AiChatMessage
      .where(admin_user: current_admin_user)
      .order(created_at: :asc)
      .last(50)
    render json: {
      success: true,
      data: messages.map { |m|
        {role: m.role, content: m.content,
         session_id: m.bedrock_session_id,
         created_at: m.created_at.iso8601}
      }
    }
  end

  def reset
    session.delete(:bedrock_session_id)
    render json: {success: true}
  end

  private

  def current_session_id
    session[:bedrock_session_id] ||= SecureRandom.uuid
  end

  # Saves the user prompt and agent response to the database for UI history.
  # Wrapped in rescue so a DB error never breaks the chat response.
  def persist_messages(session_id, user_text, agent_text)
    user = current_admin_user
    AiChatMessage.create!(
      admin_user: user,
      bedrock_session_id: session_id,
      role: "user",
      content: user_text
    )
    AiChatMessage.create!(
      admin_user: user,
      bedrock_session_id: session_id,
      role: "agent",
      content: agent_text
    )
  rescue => e
    Rails.logger.warn "AI chat: failed to persist messages: #{e.message}"
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
      "allowed_site_scope_ids" => (scope_ids == "*") ? "*" : scope_ids.join(",")
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
