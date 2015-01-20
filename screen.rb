require 'singleton'
require 'bundler'
Bundler.require

class Screen
  include Singleton
  include Curses

  def initialize
    @screen = init_screen
    noecho
    cbreak
    curs_set(0)
    stdscr.keypad(true)

    start_color
  end

  def wait
    App.instance.reset_interruption_handler

    case getch
    when 'f'
      TabManager.instance.current_tab.favorite
    when 'g', Key::HOME
      TabManager.instance.current_tab.move_to_top
    when 'G', Key::END
      TabManager.instance.current_tab.move_to_bottom
    when 'h', 2
      TabManager.instance.previous
    when 'j', 14, Key::DOWN
      TabManager.instance.current_tab.move_down
    when 'k', 16, Key::UP
      TabManager.instance.current_tab.move_up
    when 'l', 4
      TabManager.instance.next
    when 'n'
      Notifier.instance.show_message 'Compose new tweet'
      Tweetbox.instance.compose
      return
    when 'q'
      exit
    when 'r'
      TabManager.instance.current_tab.reply
    when 'R'
      TabManager.instance.current_tab.retweet
    when 'u'
      # show user
    when 4
      TabManager.instance.current_tab.move_down(10)
    when 21
      TabManager.instance.current_tab.move_up(10)
    when '/'
      # filter
    else
    end
  end
end
