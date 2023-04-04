# frozen_string_literal: true

module Main
  module Display
    module Entities
      class SearchResults
        def initialize(screen_message)
          @screen_message = screen_message
          search = @screen_message.content
          Context.register(search[:items].map { |item| item[:uri] })
        end

        def context_updated
          @screen_message.touch
        end

        def generate(_max_length)
          # @todo display results in table
          search = @screen_message.content
          <<~TEXT
            $*Searched #{search[:type]} for '#{search[:q]}'$*
            #{search[:items].map { |v| "#{v[:name]} $%(#{Context.hook(v[:uri], self)})$%" }.join(' * ')}
          TEXT
        end
      end
    end
  end
end
