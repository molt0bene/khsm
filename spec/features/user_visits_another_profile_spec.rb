require 'rails_helper'

RSpec.feature 'USER visits another profile', type: :feature do
  include ActionView::Helpers::TranslationHelper

  let(:watching_user) { FactoryBot.create :user }
  let(:another_user) { FactoryBot.create :user }

  let!(:games) do
    game1 = FactoryBot.create(
      :game, user_id: another_user.id,
      is_failed: true, current_level: 0, prize: 0
    ),
    game2 = FactoryBot.create(
      :game, user_id: another_user.id,
      is_failed: false, current_level: 12, prize: 100
    ),
    game3 = FactoryBot.create(
      :game, user_id: another_user.id,
      is_failed: false, current_level: 12, prize: 100
    )
  end

  before do
    login_as watching_user
  end

  scenario 'showing games in the profile' do
    # добавляем статусы игр
    games[0].status { :fail }
    games[1].status { :money }
    games[2].status { :in_progress }

    # заходим на главную
    visit '/'

    click_link another_user.name

    # проверка, что есть имя, но нет кнопки смены пароля
    expect(page).to have_content another_user.name
    expect(page).not_to have_content 'Сменить имя и пароль'

    # проверяем дату, время создания и статус каждой игры
    games.each do |game|
      expect(page).to have_content(l game.created_at, format: :short)
      expect(page).to have_content(game.current_level)
      expect(page).to have_content(game.prize)

      case game.status
      when :fail then expect(page).to have_content 'проигрыш'
      when :money then expect(page).to have_content 'деньги'
      when :in_progress then expect(page).to have_content 'в процессе'
      end
    end
  end
end
