# frozen_string_literal: true

module UI
  module PrintUtils
    private

    def print(content = nil, type: nil)
      @print ||= Print.new
      if content.nil?
        @print
      else
        @print.create(content, type:)
      end
    end

    private_constant(
      class Print
        def initialize
          @prints = {}
        end

        def [](key)
          @key = key
          self
        end

        def replace(content, type: nil)
          if @prints[@key].nil?
            create(content, type:)
          else
            screen_message = @prints[@key]
            screen_message.update(content, type:)
            @key = nil
            screen_message
          end
        end

        def create(content, type: nil)
          screen_message = ScreenMessage.new(content, type:)
          @prints[@key] = screen_message
          @key = nil
          screen_message
        end
      end
    )
  end
end
