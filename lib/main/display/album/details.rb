# frozen_string_literal: true

module Main
  module Display
    module Album
      class Details
        include Names

        def initialize(screen_message)
          @screen_message = screen_message
          @album = screen_message.content
          Context.register([@album[:uri]])
          Context.register(@album[:artists].map { |artist| artist[:uri] })

          tracks = @album[:tracks]
          date = Date.parse(@album[:release_date])
          title = <<~TEXT
            #{@album[:album_type].upcase}
            $*#{album(@album)}$*
            #{artists(@album[:artists])}
            #{date.year} - #{@album[:total_tracks]} songs
          TEXT
          @list = Display::Track::List.new(
            tracks,
            title:,
            index: :track_number,
            context: @album,
            album: false
          )
        end

        def context_updated
          @screen_message.touch
        end

        def delete
          @list.delete
        end

        def generate(width)
          @list.generate(width)
        end
      end
    end
  end
end
