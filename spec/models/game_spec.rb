# (c) goodprogrammer.ru

# Стандартный rspec-овский помощник для rails-проекта
require 'rails_helper'

# Наш собственный класс с вспомогательными методами
require 'support/my_spec_helper'

# Тестовый сценарий для модели Игры
#
# В идеале — все методы должны быть покрыты тестами, в этом классе содержится
# ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # Пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # Игра с прописанными игровыми вопросами
  let(:game_w_questions) do
    FactoryBot.create(:game_with_questions, user: user)
  end

  # Группа тестов на работу фабрики создания новых игр
  describe 'Game Factory' do
    describe '.create_game!' do
      it 'creates new correct game' do
        # Генерим 60 вопросов с 4х запасом по полю level, чтобы проверить работу
        # RANDOM при создании игры.
        generate_questions(60)

        game = nil

        # Создaли игру, обернули в блок, на который накладываем проверки
        expect {
          game = Game.create_game_for_user!(user)
          # Проверка: Game.count изменился на 1 (создали в базе 1 игру)
        }.to change(Game, :count).by(1).and(
          # GameQuestion.count +15
          change(GameQuestion, :count).by(15).and(
            # Game.count не должен измениться
            change(Question, :count).by(0)
          )
        )

        # Проверяем статус и поля
        expect(game.user).to eq(user)
        expect(game.status).to eq(:in_progress)

        # Проверяем корректность массива игровых вопросов
        expect(game.game_questions.size).to eq(15)
        expect(game.game_questions.map(&:level)).to eq (0..14).to_a
      end
    end
  end

  describe '#current_game_question' do
    it 'shows current question' do
      question = game_w_questions.current_game_question
      expect(question).to be
      expect(question).to eq(game_w_questions.game_questions.first) # поскольку игра в фабрике создается с level = 0,
                                                                    # значит берем первый вопрос
    end
  end

  describe '#previous_level' do
    it 'shows valid previous level' do
      expect(game_w_questions.previous_level).to eq(game_w_questions.current_level - 1)
    end
  end

  describe '#answer_current_question!' do
    context 'answer is correct' do
      context 'question is not the last' do
        let! (:level) { game_w_questions.current_level }
        let (:question) { game_w_questions.current_game_question }

        before do
          game_w_questions.answer_current_question!(question.correct_answer_key)
        end

        it 'should go to next level' do
          expect(game_w_questions.current_level).to eq(level + 1)
        end

        it 'should show next question' do
          expect(game_w_questions.current_game_question).not_to eq(question)
        end

        it 'should not change game status' do
          expect(game_w_questions.status).to eq(:in_progress)
          expect(game_w_questions.finished?).to eq false
        end
      end

      context 'question is the last' do
        let (:question) { game_w_questions.current_game_question }

        before do
          game_w_questions.current_level = Question::QUESTION_LEVELS.max
          game_w_questions.answer_current_question!(question.correct_answer_key)
        end

        it 'should finish game' do
          expect(game_w_questions.status).to eq(:won)
          expect(game_w_questions.finished?).to eq true
        end
      end
    end

    context 'answer is incorrect' do
      let (:level) { game_w_questions.current_level }
      let (:question) { game_w_questions.current_game_question }

      before do
        game_w_questions.answer_current_question!('c') # incorrect key
      end

      it 'should finish game' do
        expect(game_w_questions.status).to eq(:fail)
        expect(game_w_questions.finished?).to eq true
      end

      it 'should give away fireproof money' do
        expect(user.balance).to eq(game_w_questions.prize)
      end
    end

    context 'answer was given after time was out' do
      before(:each) do
        game_w_questions.created_at = 36.minutes.ago
      end

      it 'should return false' do
        expect(game_w_questions.answer_current_question!('a')).to eq false
      end

      it 'should finish with status :timeout' do
        game_w_questions.answer_current_question!('a')
        
        expect(game_w_questions.status).to eq(:timeout)
        expect(game_w_questions.finished?).to eq true
      end
    end
  end
end
