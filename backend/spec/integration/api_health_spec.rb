require 'rails_helper'

RSpec.describe 'API Health Integration', type: :request do
  describe 'GET /api/health' do
    it 'returns success status' do
      get '/api/health'
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'API availability' do
    it 'responds to basic API endpoints' do
      get '/api/v1/'
      expect(response).to have_http_status(:success)
    end
  end
end