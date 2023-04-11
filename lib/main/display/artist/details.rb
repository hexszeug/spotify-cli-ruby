# frozen_string_literal: true

module Main
  module Display
    module Artist
      class Details
        # @todo implement
        include Names

        attr_reader :content

        def initialize(screen_message)
          @screen_message = screen_message
          album = screen_message.content
          Context.register([album[:uri]])
          Context.register(album[:artists].map { |artist| artist[:uri] })

          @content = {
            title: header(album),
            tracks: album[:tracks][:items]
          }
          @list = Display::Track::List.new(self)
        end

        def context_updated
          @screen_message.touch
        end

        def touch
          @screen_message.touch
        end

        def delete
          @list.delete
        end

        def generate(width)
          @list.generate(width)
        end

        private

        def header(album)
          date = Date.parse(album[:release_date])
          <<~TEXT
            #{album[:album_type].upcase}
            $*#{album(album)}$*
            #{artists(album[:artists])}
            #{date.year} - #{album[:genres].join(', ')} - #{album[:total_tracks]} songs
          TEXT
        end
      end
    end
  end
end
