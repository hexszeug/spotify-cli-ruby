# frozen_string_literal: true

module Main
  module Display
    module Album
      class List
        include Names

        def initialize(
          albums,
          title: '$*Albums$*',
          index: true,
          group: true,
          artists: true,
          songs: true,
          released: true,
          &update
        )
          @title = title
          @albums = albums
          @index = index
          @group = group
          @artists = artists
          @songs = songs
          @released = released
          @update = update
          register_albums
        end

        def context_updated
          @table = nil
          @update&.call
        end

        def delete
          Context.unhook(self)
        end

        def generate(max_width)
          @table ||= generate_table
          <<~TEXT
            #{@title}
            #{@table.generate(max_width)}
          TEXT
        end

        private

        def register_albums
          Context.register(@albums.map { |album| album[:uri] })
          Context.register(
            @albums.flat_map do |album|
              album[:artists].map { |artist| artist[:uri] }
            end
          )
        end

        def generate_table
          table = Display::Table.new(gap: 2)
          if @index
            table.add_column(
              {
                title: '#',
                width: 3,
                align: :right
              },
              *1.upto(@albums.length).map(&:to_s)
            )
          end
          if @group
            table.add_column(
              {
                title: 'Type',
                width: 11,
                align: :center
              },
              *@albums.map { |album| album[:album_group].upcase }
            )
          end
          table.add_column(
            {
              title: 'Album',
              width: { fraction: 4, min: 10 },
              overflow: :tripple_dot
            },
            *@albums.map { |album| album(album) }
          )
          if @artists
            table.add_column(
              {
                title: 'Artists',
                width: { fraction: 2 },
                overflow: :tripple_dot
              },
              *@albums.map { |album| artists(album[:artists]) }
            )
          end
          if @songs
            table.add_column(
              {
                title: 'Songs',
                align: :right
              },
              *@albums.map { |album| "#{album[:total_tracks]} song(s)" }
            )
          end
          if @released
            table.add_column(
              {
                title: 'Released',
                align: :right
              },
              *@albums.map do |album|
                Date.parse(album[:release_date]).year.to_s
              rescue Date::Error
                ''
              end
            )
          end
          table
        end
      end
    end
  end
end
