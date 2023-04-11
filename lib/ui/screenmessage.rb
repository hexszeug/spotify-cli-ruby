# frozen_string_literal: true

module UI
  class ScreenMessage
    attr_reader :content, :decorator

    def changed?
      @changed
    end

    def initialize(content, type: nil)
      @mutex = Mutex.new
      replace(content, type:)
      UI.print(self)
    end

    def touch
      @buf = {}
      @changed = true
    end

    def replace(content, type: nil)
      @mutex.lock
      touch
      @content = content || ''
      @decorator&.delete
      @decorator = type&.new(self)
      self
    ensure
      @mutex.unlock
    end

    def generate(max_width)
      @mutex.lock
      @changed = false
      @buf[max_width] ||=
        Markup.new(@decorator&.generate(max_width) || @content).scale(max_width)
    ensure
      @mutex.unlock
    end
  end
end
