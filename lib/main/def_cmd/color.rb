# frozen_string_literal: true

module Main
  module DefCmd
    class Color
      include Command

      def initialize(dispatcher)
        dispatcher.register(
          literal('color').executes do
            if @th
              @th.kill
              @th = nil
            else
              @th = Thread.new do
                state = 0
                r = 1000
                g = 0
                b = 0
                loop do
                  case state
                  when 0
                    r -= 10
                    g += 10
                    state = 1 if r.zero?
                  when 1
                    g -= 10
                    b += 10
                    state = 2 if g.zero?
                  when 2
                    b -= 10
                    r += 10
                    state = 0 if b.zero?
                  end
                  Curses.init_color(0, r, g, b)
                  UI.input.touch
                  sleep 0.05
                end
              end
            end
          end
        )
      end
    end
  end
end
