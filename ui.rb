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
        # if scroll
        Input.refresh @win
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
            return unless @changed
            @changed = false
            s = @cursor - @display_cursor
            e = s + @display_size
            win.deleteln
            win.setpos 0, 0
            win.addstr @string[s...e]
            win.setpos 0, @display_cursor
            win.refresh
        end

        def Input.read(ch)
            #TODO suggestions (TAB Arrow Up/Down, maybe PPAGE, NPAGE)
            #TODO insert-mode
            #TODO history
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
                @history[-1] = @string.clone
                @history.push @string
                @string.clear
                @history_pointer = @history.length - 1
                move_cursor 0
            when 0x109 #F1 #TODO temporary exit
                Curses.close_screen
                exit
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

    init
end

require "./command"
dispatcher = Command::CommandDispatcher.new
UI.returns_to do |str|
    begin
        dispatcher.execute str
    rescue Command::CommandError => e
        Curses.close_screen #TODO output command error messages
        puts e
    end
end
loop { UI.tick }
