require 'curses'

require 'twterm/completion_mamanger'
require 'twterm/direct_message_composer'
require 'twterm/event/screen/resize'
require 'twterm/repository/direct_message_repository'
require 'twterm/repository/friendship_repository'
require 'twterm/repository/hashtag_repository'
require 'twterm/repository/list_repository'
require 'twterm/repository/status_repository'
require 'twterm/repository/user_repository'
require 'twterm/tab_manager'
require 'twterm/tweetbox'
require 'twterm/uri_opener'

module Twterm
  class App
    include Publisher

    attr_reader :screen

    DATA_DIR = "#{ENV['HOME']}/.twterm".freeze

    def completion_manager
      @completion_mamanger ||= CompletionManager.new(self)
    end

    def direct_message_composer
      @direct_message_composer ||= DirectMessageComposer.new(self, client)
    end

    def direct_message_repository
      @direct_messages_repository ||= Repository::DirectMessageRepository.new
    end

    def friendship_repository
      @friendship_repository ||= Repository::FriendshipRepository.new
    end

    def hashtag_repository
      @hashtag_repository ||= Repository::HashtagRepository.new
    end

    def list_repository
      @list_repository ||= Repository::ListRepository.new
    end

    def run
      Dir.mkdir(DATA_DIR, 0700) unless File.directory?(DATA_DIR)

      Auth.authenticate_user(config) if config[:user_id].nil?

      KeyMapper.instance

      @screen = Screen.new(self, client)

      SearchQueryWindow.instance

      timeline = Tab::Statuses::Home.new(self, client)
      tab_manager.add_and_show(timeline)

      mentions_tab = Tab::Statuses::Mentions.new(self, client)

      tab_manager.add(mentions_tab)
      tab_manager.recover_tabs

      screen.refresh

      client.connect_user_stream

      reset_interruption_handler

      URIOpener.instance

      Scheduler.new(300) do
        status_repository.expire(3600)

        _ = status_repository.all.map { |user_id| user_repository.find(user_id) }
        user_repository.expire(3600)
      end

      direct_message_repository.before_create do |dm|
        user_repository.create(dm.recipient)
        user_repository.create(dm.sender)
      end

      user_repository.before_create do |user|
        client_id = client.user_id

        if user.following?
          friendship_repository.follow(client_id, user.id)
        else
          friendship_repository.unfollow(client_id, user.id)
        end

        if user.follow_request_sent?
          friendship_repository.following_requested(client_id, user.id)
        else
          friendship_repository.following_not_requested(client_id, user.id)
        end
      end

      status_repository.before_create do |tweet|
        user_repository.create(tweet.user)
      end

      status_repository.before_create do |tweet|
        tweet.hashtags.each do |hashtag|
          hashtag_repository.create(hashtag.text)
        end
      end

      screen.wait
      screen.refresh
    end

    def register_interruption_handler(&block)
      fail ArgumentError, 'no block given' unless block_given?
      Signal.trap(:INT) { block.call }
    end

    def reset_interruption_handler
      Signal.trap(:INT) { quit }
    end

    def quit
      Curses.close_screen
      tab_manager.dump_tabs
      exit
    end

    def status_repository
      @status_repository ||= Repository::StatusRepository.new
    end

    def tab_manager
      @tab_manager ||= TabManager.new(self, client)
    end

    def tweetbox
      @tweetbox = Tweetbox.new(self, client)
    end

    def user_repository
      @user_repository ||= Repository::UserRepository.new
    end

    private

    def client
      @client ||= Client.new(
        config[:user_id].to_i,
        config[:screen_name],
        config[:access_token],
        config[:access_token_secret],
        {
          friendship: friendship_repository,
          direct_message: direct_message_repository,
          hashtag: hashtag_repository,
          list: list_repository,
          status: status_repository,
          user: user_repository,
        }
      )
    end

    def config
      @config ||= Config.new
    end
  end
end
