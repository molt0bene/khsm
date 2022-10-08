# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера (Анонимус)
  describe 'Anonymous user' do
    context 'tries to go to #show' do
      it 'should not be allowed' do
        # вызываем экшен
        get :show, id: game_w_questions.id
        # проверяем ответ
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end

    context 'tries to go to #create' do
      it 'should not be allowed' do
        expect { post :create }.not_to change { Game.count }

        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'tries to go to #answer' do
      it 'should not be allowed' do
        put :answer, id: game_w_questions.id

        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'tries to go to #take_money' do
      it 'should not be allowed' do
        put :take_money, id: game_w_questions.id

        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'tries to go to #help' do
      it 'should not be allowed' do
        put :help, id: game_w_questions.id

        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  describe 'Usual user' do
    # перед каждым тестом в группе
    before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    # юзер может создать новую игру
    describe '#create' do
      # сперва накидаем вопросов, из чего собирать новую игру
      before(:each) do
        generate_questions(15)
        post :create
        @game = assigns(:game) # вытаскиваем из контроллера поле @game
      end

      # проверяем состояние этой игры
      it 'should be created correctly' do
        expect(@game.finished?).to be_falsey
        expect(@game.user).to eq(user)
        # и редирект на страницу этой игры
        expect(response).to redirect_to(game_path(@game))
        expect(flash[:notice]).to be
      end
    end

    describe '#show' do
      # юзер видит свою игру
      context 'own game' do
        before (:each) do
          get :show, id: game_w_questions.id
          @game = assigns(:game) # вытаскиваем из контроллера поле @game
        end

        it 'should display correctly' do
          expect(@game.finished?).to be_falsey
          expect(@game.user).to eq(user)

          expect(response.status).to eq(200) # должен быть ответ HTTP 200
          expect(response).to render_template('show') # и отрендерить шаблон show
        end
      end

      # проверка, что пользователя посылают из чужой игры
      context 'others game' do
        # создаем новую игру, юзер не прописан, будет создан фабрикой новый
        before (:each) do
          alien_game = FactoryBot.create(:game_with_questions)

          # пробуем зайти на эту игру текущий залогиненным user
          get :show, id: alien_game.id
        end

        it 'should not be allowed' do
          expect(response.status).not_to eq(200) # статус не 200 ОК
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to be # во flash должен быть прописана ошибка
        end
      end
    end

    # юзер отвечает на игру корректно - игра продолжается
    describe '#answer' do
      context 'answer is correct' do
        it 'should continue game' do
          put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
          game = assigns(:game)

          expect(game.finished?).to be_falsey
          expect(game.current_level).to be > 0
          expect(response).to redirect_to(game_path(game))
          expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
        end
      end

      context 'answer is incorrect' do
        it 'should finish game' do
          put :answer, id: game_w_questions.id, letter: 'c' # неправильный ответ
          game = assigns(:game)

          expect(game.finished?).to be_truthy
          expect(response).to redirect_to(user_path(user))
          expect(flash[:alert]).to be
        end
      end
    end

    describe 'user takes money' do
      before(:each) do
        # вручную поднимем уровень вопроса до выигрыша 200
        game_w_questions.update_attribute(:current_level, 2)

        put :take_money, id: game_w_questions.id
        @game = assigns(:game)
      end

      it 'should finish game and give money' do
        expect(@game.finished?).to be_truthy
      end

      it 'should give money' do
        expect(@game.prize).to eq(200)

        # пользователь изменился в базе, надо в коде перезагрузить!
        user.reload
        expect(user.balance).to eq(200)

        expect(response).to redirect_to(user_path(user))
        expect(flash[:warning]).to be
      end
    end

    # юзер пытается создать новую игру, не закончив старую
    describe 'user tries to create second game' do
      before (:each) do
        # убедились что есть игра в работе
        expect(game_w_questions.finished?).to be_falsey

        # отправляем запрос на создание, убеждаемся что новых Game не создалось
        expect { post :create }.to change(Game, :count).by(0)
        @game = assigns(:game) # вытаскиваем из контроллера поле @game
      end

      it 'should not create' do
        expect(@game).to be_nil
      end

      it 'should redirect to first game' do
        expect(response).to redirect_to(game_path(game_w_questions))
        expect(flash[:alert]).to be
      end
    end

    # тест на отработку "помощи зала"
    describe 'user uses audience help' do
      it 'checks that help is not used' do
        # сперва проверяем что в подсказках текущего вопроса пусто
        expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
        expect(game_w_questions.audience_help_used).to be_falsey
      end

      # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
      it 'should not finish game and set keys correctly' do
        put :help, id: game_w_questions.id, help_type: :audience_help
        game = assigns(:game)
        expect(game.finished?).to be_falsey

        expect(game.audience_help_used).to be_truthy
        expect(game.current_game_question.help_hash[:audience_help]).to be
        expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
        expect(response).to redirect_to(game_path(game))
      end
    end
  end
end
