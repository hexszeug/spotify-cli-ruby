# frozen_string_literal: true

module UI
  module PrintUtils
    # @todo print[]+= creates, print[]-= removes and print[]= updates
    def print(content = nil, type: UI::ScreenMessage)
      if !content.nil? && type <= UI::ScreenMessage
        UI.print(type.new(content))
        return
      end

      @print ||= Printer.new
    end

    class Printer
      def initialize
        @prints = {}
      end

      def [](key)
        @prints[key]
      end

      def []=(key, content, type: UI::ScreenMessage)
        if content.is_a?(String) && type <= UI::ScreenMessage
          content = type.new(content)
          class << content
            alias_method :+, :update
          end
          UI.print(content)
        end
        @prints[key] = content if content.is_a?(UI::ScreenMessage)
      end
    end
    private_constant :Printer
  end
end
