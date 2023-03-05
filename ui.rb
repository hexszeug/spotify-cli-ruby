require "curses"

module UI
    def self.init
        # initialize curses
        Curses.init_screen
        Curses.start_color
        Curses.noecho
        Curses.cbreak
        Curses.nl

        # initialize input window
        @win = Curses::Window.new 0, 0, 0, 0
        @win.timeout = 0
        @win.keypad true
        @win.scrollok true

        # initialize output window
        @wout = Curses::Window.new 0, 0, 0, 0
        @wout.timeout = -1
        @wout.keypad true
        @wout.scrollok true

        # set initial size and spacing
        on_resize
    end

    def UI.tick
        # read curses input buffer
        while ch = @win.get_char
            Input.read ch
        end
        # refresh curses buffer
        o = Output.refresh @wout
        i = Input.refresh @win
        # draw curses buffer if changed
        @wout.noutrefresh if o
        @win.refresh if i || o
    end

    def UI.print_raw(str)
        str = str.to_s unless str.is_a? String
        Output.print ->(width) { str }
    end

    def UI.returns_to(&listener)
        @return_listener = listener
    end

    def self.on_resize
        Utils.resize_window @win, 1, -2, -1, -2
        Utils.resize_window @wout, 1, 1, -1, -4
        Curses.clear
        Curses.refresh
        Input.on_resize @win
        Output.on_resize @wout
    end

    def self.on_return(str)
        return unless @return_listener.is_a? Proc
        @return_listener.call str
    end

    module Utils
        def Utils.resize_window(
            win,
            top_left_x,
            top_left_y,
            bottom_right_x,
            bottom_right_y
        )
            top_left_x = Curses.cols + top_left_x if top_left_x < 0
            top_left_y = Curses.lines + top_left_y if top_left_y < 0
            bottom_right_x = Curses.cols + bottom_right_x if bottom_right_x < 0
            bottom_right_y = Curses.lines + bottom_right_y if bottom_right_y < 0
            win.resize bottom_right_y - top_left_y + 1,
                                  bottom_right_x - top_left_x + 1
            win.move top_left_y, top_left_x
        end
    end

    module Input
        include Curses::Key

        @string = ""
        @cursor = 0
        @display_cursor = 0
        @history = [@string]
        @history_pointer = 0
        @changed = false
        @display_size = 0

        def Input.on_resize(win)
            size = win.maxx - 1
            return if size == @display_size
            @changed = true
            prev_size = @display_size
            @display_size = size
            if @display_cursor >= @display_size
                @display_cursor = @display_size - 1
            elsif @cursor == @string.length && @display_cursor == prev_size - 1
                @display_cursor = [@cursor, @display_size - 1].min
            end
        end

        def Input.refresh(win)
            return false unless @changed
            @changed = false
            s = @cursor - @display_cursor
            e = s + @display_size
            win.deleteln
            win.setpos 0, 0
            win.addstr @string[s...e]
            win.setpos 0, @display_cursor
            return true
        end

        def Input.read(ch)
            #TODO suggestions (TAB Arrow Up/Down, maybe PPAGE, NPAGE)
            #TODO insert-mode
            case ch
            when RESIZE
                UI.on_resize
            when BACKSPACE
                return unless @cursor > 0
                @string.slice! @cursor - 1
                move_cursor @cursor - 1
            when "\b" #CTRL+BACKSPACE (for some random reason)
                return unless @cursor > 0
                c = @cursor - 2
                i = @string.rindex(/ [^ ]/, c < 0 ? 0 : c)
                i = i ? i + 1 : 0
                @string.slice! i...@cursor
                move_cursor i
            when DC
                return if @string.empty?
                @string.slice! @cursor
            when 0x208 #CTRL+DC
                return if @string.empty?
                i = @string.index(/ [^ ]/, @cursor)
                @string.slice! @cursor..i
            when LEFT
                return unless @cursor > 0
                move_cursor @cursor - 1
            when 0x222 #CTRL+LEFT
                return unless @cursor > 0
                c = @cursor - 2
                i = @string.rindex(/ [^ ]/, c < 0 ? 0 : c)
                move_cursor i ? i + 1 : 0
            when HOME
                return unless @cursor > 0
                move_cursor 0
            when RIGHT
                return unless @cursor < @string.length
                move_cursor @cursor + 1
            when 0x231 #CTRL+RIGHT
                return unless @cursor < @string.length
                i = @string.index(/ [^ ]/, @cursor)
                move_cursor i ? i + 1 : @string.length
            when Curses::KEY_END
                return unless @cursor < @string.length
                move_cursor @string.length
            when UP
                return unless @history_pointer > 0
                @history_pointer -= 1
                @string = @history[@history_pointer].clone
                move_cursor @string.length
            when DOWN
                return unless @history_pointer < @history.length - 1
                @history_pointer += 1
                @string = @history[@history_pointer]
                @string = @string.clone if @history_pointer < @history.length - 1
                move_cursor @string.length
            when ENTER, "\n", "\r"
                return if @string.empty?
                UI.on_return @string.clone
                if @history[-2] == @string
                    @history[-1] = @string
                else
                    @history[-1] = @string.clone
                    @history.push @string
                end
                @string.clear
                @history_pointer = @history.length - 1
                move_cursor 0
            when 0x237 #CTRL+UP
                Output.scroll -1
            when PPAGE
                Output.scroll { |h| 1 - h }
            when 0x20e #CTRL+DOWN
                Output.scroll 1
            when NPAGE
                Output.scroll { |h| h - 1 }
            else
                return unless ch.is_a?(String) && ch =~ /^[[:print:]]$/
                @string.insert @cursor, ch
                move_cursor @cursor + 1
            end
            @changed = true
            return
        end

        def self.move_cursor(cursor)
            return if !cursor.between?(0, @string.length) || cursor == @cursor
            d = (@cursor - cursor).abs
            if @cursor > cursor
                @display_cursor -= d
                unless @display_cursor > 0
                    @display_cursor = [cursor, @display_size - 1].min
                end
            else
                @display_cursor = [@display_cursor + d, @display_size - 1].min
            end
            @cursor = cursor
        end
    end

    module Output
        @generators = []
        @old_generators_length = 0
        @display = []
        @scroll = 0
        @old_scroll = 0
        @height = 0
        @width = 0
        @changed_size = false

        def Output.on_resize(win)
            h = win.maxy
            w = win.maxx - 1
            return if @height == h && @width == w
            @changed_size = true
            @height = h
            @width = w
        end

        def Output.refresh(win, force: false)
            #TODO add scroll bar
            changed_output = @generators.length != @old_generators_length
            changed_size = @changed_size
            scrolled = @scroll != @old_scroll
            return false unless changed_output || changed_size || scrolled || force
            if changed_size || force
                scroll = @scroll.clone
                @display = []
                @generators.each do |gen|
                    lines = gen.call
                    next unless lines
                    @display += lines
                end
                @scroll = [[@scroll, @display.length - @height].min, 0].max
                win.clear
                win.setpos [@height - @display.length, 0].max, 0
                s = [@display.length - @height - @scroll, 0].max
                e = @display.length - @scroll - 1
                win.addstr @display[s..e] * "\n"
            elsif changed_output
                @scroll = 0
                new_lines = 0
                @generators[@old_generators_length..nil].each do |gen|
                    lines = gen.call
                    @display += lines
                    new_lines += lines.length
                end
                win.scrl new_lines
                win.setpos [@height - new_lines, 0].max, 0
                s = @display.length - [new_lines, @height].min
                win.addstr @display[s..nil] * "\n"
            elsif scrolled
                amount = @old_scroll - @scroll
                s = [@display.length - @height - @scroll, 0].max
                e = @display.length - @scroll - 1
                c = 0
                if amount > 0
                    s = [e - amount + 1, s].max
                    c = @height - e + s - 1
                else
                    e = [s - amount - 1, e].min
                end
                win.scrl amount
                win.setpos c, 0
                win.addstr @display[s..e] * "\n"
            end
            @old_generators_length = @generators.length
            @changed_size = false
            @old_scroll = @scroll
            return true
        end

        def Output.print(msg)
            return unless msg.is_a?(Proc) && msg.lambda?
            @generators.push(
                -> do
                    lines = msg.call(@width).clone
                    lines = [lines] if lines.is_a? String
                    return nil unless lines.is_a? Array
                    lines = (lines * "\n").split "\n"
                    lines.each.with_index do |line, i|
                        next unless line.length > @width
                        e = line.rindex /\s/, @width
                        e = @width unless e
                        s = line.index(/\S/, e) - e
                        new_line = line.slice! e...line.length
                        next unless s && new_line
                        new_line.slice! 0...s
                        next if new_line.empty?
                        lines.insert i + 1, new_line
                    end
                    return lines
                end,
            )
        end

        def Output.scroll(amount = 0, &provider)
            amount = provider.call @height if provider
            return if amount == 0
            @scroll = [[@scroll - amount, @display.length - @height].min, 0].max
        end
    end

    init
end

require "./command"
include Command
dispatcher = CommandDispatcher.new
dispatcher.register(
    literal("echo")
        .then(
            Arguments::GreedyString
                .new(:str)
                .executes { |ctx| UI.print_raw ctx[:str] },
        )
        .executes { UI.print_raw "" },
)
dispatcher.register(
    literal("exit").executes do
        Curses.close_screen
        exit
    end,
)
UI.returns_to do |str|
    begin
        dispatcher.execute str
    rescue CommandError => e
        UI.print_raw e.msg
    end
end
UI.print_raw "Welcome to the Ruby Spotify CLI"
loop { UI.tick }
