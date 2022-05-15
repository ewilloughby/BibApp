require 'rails_helper'

RSpec.describe "Statics", type: :request do
  describe "GET /faq" do
    it "returns http success" do
      get "/static/faq"
      expect(response).to have_http_status(:success)
    end
  end

end
