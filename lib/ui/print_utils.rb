# frozen_string_literal: true

module UI
  module PrintUtils
    # @todo print[]+= creates, print[]-= removes and print[]= updates (or even more logical syntax)
    def print(content = nil, type: nil)
      unless content.nil?
        UI.print(ScreenMessage.new(content, type:))
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

      def []=(key, content, type: nil)
        if content.is_a?(String)
          content = ScreenMessage.new(content, type:)
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
