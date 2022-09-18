require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  include Devise::Test::ControllerHelpers
  user = FactoryBot.build_stubbed(:user, name: 'Rick Astley', balance: 42)

  before(:each) do
    assign(:user, user)
  end

  it 'renders name' do
    render
    expect(rendered).to match 'Rick Astley'
  end

  it 'renders own passwd' do
    allow(controller).to receive(:current_user).and_return(user)
    render
    expect(rendered).to have_link('Сменить имя и пароль')
  end

  it 'not renders others passwd' do
    allow(controller).to receive(:current_user).and_return(nil)
    render
    expect(rendered).to match('Сменить имя и пароль')
  end

  it 'renders games' do

  end
end
