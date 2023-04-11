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
        end

        def context_updated
          @list = nil
          @screen_message.touch
        end

        def delete
          @list.delete
        end

        def generate(width)
          tracks = @album[:tracks][:items]
          date = Date.parse(@album[:release_date])
          title = <<~TEXT
            #{@album[:album_type].upcase}
            $*#{album(@album)}$*
            #{artists(@album[:artists])}
            #{date.year} - #{@album[:genres].join(', ')} - #{@album[:total_tracks]} songs
          TEXT
          @list ||= Display::Track::List.new(
            tracks,
            title:,
            context: @album,
            album: false
          )
          @list.generate(width)
        end
      end
    end
  end
end
