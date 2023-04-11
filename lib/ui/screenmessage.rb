# frozen_string_literal: true

module UI
  class ScreenMessage
    attr_reader :content, :decorator

    def changed?
      @changed
    end

    def initialize(content, type: nil)
      replace(content, type:)
      UI.print(self)
    end

    def touch
      @buf = {}
      @changed = true
    end

    def replace(content, type: nil)
      touch
      @content = content
      @decorator&.delete
      @decorator = type&.new(self)
      self
    end

    def generate(max_width)
      @changed = false
      @buf[max_width] ||=
        Markup.new(@decorator&.generate(max_width) || @content).scale(max_width)
    end
  end
end
