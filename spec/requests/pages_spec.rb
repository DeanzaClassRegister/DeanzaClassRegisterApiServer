require 'rails_helper'

RSpec.describe 'Pages Controller', type: :request do
  describe 'GET #index' do
    it 'should redirct to enrollment.plus' do
      get '/'

      expect(response).to have_http_status(302)
      expect(response).to redirect_to('https://www.enrollment.plus/')
    end
  end
end

