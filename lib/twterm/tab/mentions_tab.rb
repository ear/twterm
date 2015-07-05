module Twterm
  module Tab
    class MentionsTab
      include StatusesTab

      def close
        fail NotClosableError
      end

      def fetch
        @client.mentions do |statuses|
          statuses.reverse.each(&method(:prepend))
          sort
          yield if block_given?
        end
      end

      def initialize(client)
        fail ArgumentError, 'argument must be an instance of Client class' unless client.is_a? Client

        super()

        @client = client
        @client.on_mention do |status|
          prepend(status)
          Notifier.instance.show_message "Mentioned by @#{status.user.screen_name}: #{status.text}"
        end

        @title = 'Mentions'

        fetch { scroll_manager.move_to_top }
        @auto_reloader = Scheduler.new(300) { fetch }
      end
    end
  end
end
