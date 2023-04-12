# frozen_string_literal: true

module Main
  module Display
    module Track
      class List
        include Names

        def initialize(
          tracks,
          title: nil,
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
            $*#{@title || 'Songs'}$*
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
          columns = []
          if @index
            columns.push(
              {
                title: '#',
                width: 3,
                align: :right
              }
            )
          end
          columns.push(
            {
              title: 'Title',
              width: { fraction: 4, min: 10 },
              overflow: :tripple_dot
            }
          )
          if @artists
            columns.push(
              {
                title: 'Artists',
                width: { fraction: 2 },
                overflow: :tripple_dot
              }
            )
          end
          if @album
            columns.push(
              {
                title: 'Album',
                width: { fraction: 3 },
                overflow: :tripple_dot
              }
            )
          end
          table = Display::Table.new(*columns, gap: 2)
          @tracks.each_with_index do |track, i|
            row = []
            row.push((i + 1).to_s) if @index == :index
            row.push(track[:track_number].to_s) if @index == :track_number
            row.push(track(track))
            row.push(artists(track[:artists])) if @artists
            row.push(album(track[:album])) if @album
            table.add_row(*row)
          end
          table
        end
      end
    end
  end
end
