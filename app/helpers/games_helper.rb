module GamesHelper
  # Этот метод будет рисовать удобный ярлычок для показа статуса игры
  # Используем стандартные bootstrap-овский класс `label`
  def game_label(game)
    if game.status == :in_progress && current_user == game.user
      link_to content_tag(:span, t("game_statuses.#{game.status}"), class: 'label'), game_path(game)
    else
      content_tag :span, t("game_statuses.#{game.status}"), class: 'label label-danger'
    end
  end
end
