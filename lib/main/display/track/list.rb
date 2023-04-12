# frozen_string_literal: true

module Main
  module Display
    module Track
      class List
        include Names

        def initialize(
          tracks,
          title: '$*Songs$*',
          context: nil,
          index: :index,
          artists: true,
          album: true,
          &update
        )
          @tracks =
            if context.nil?
              tracks
            else
              tracks.map do |track|
                track.merge(uri: "#{context[:uri]}/#{track[:uri]}")
              end
            end
          @title = title
          @index = index
          @artists = artists
          @album = album
          @update = update
          register_tracks
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

        def register_tracks
          if @artists
            Context.register(
              @tracks.flat_map do |track|
                track[:artists].map { |artist| artist[:uri] }
              end
            )
          end
          if @album
            Context.register(
              @tracks.map { |track| track[:album][:uri] }
            )
          end
          Context.register(@tracks.map { |track| track[:uri] })
        end

        def generate_table
          table = Table.new(gap: 2)
          if @index == :index
            table.add_column(
              {
                title: '#',
                width: 3,
                align: :right
              },
              *1.upto(@tracks.length).map(&:to_s)
            )
          end
          if @index == :track_number
            table.add_column(
              {
                title: '#',
                width: 3,
                align: :right
              },
              *@tracks.map { |track| track[:track_number].to_s }
            )
          end
          table.add_column(
            {
              title: 'Title',
              width: { fraction: 4, min: 10 },
              overflow: :tripple_dot
            },
            *@tracks.map { |track| track(track) }
          )
          if @artists
            table.add_column(
              {
                title: 'Artists',
                width: { fraction: 2 },
                overflow: :tripple_dot
              },
              *@tracks.map { |track| artists(track[:artists]) }
            )
          end
          if @album
            table.add_column(
              {
                title: 'Album',
                width: { fraction: 3 },
                overflow: :tripple_dot
              },
              *@tracks.map { |track| album(track[:album]) }
            )
          end
          table
        end
      end
    end
  end
end
