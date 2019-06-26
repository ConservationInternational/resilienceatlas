class SessionsController < Devise::SessionsController
  respond_to :html, :json
end
