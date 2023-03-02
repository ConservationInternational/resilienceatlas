module RequestHelpers
  def auth_token_for(user, password: nil)
    "Bearer #{AuthenticateUser.call(user.email, password || user.password).result}"
  end

  def response_json
    JSON.parse(response.body)
  end
end
