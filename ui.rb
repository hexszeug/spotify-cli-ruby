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
        resize_windows
    end

    def UI.tick
        # read curses input buffer
        while ch = @win.get_char
            line = Input.read ch
            if line
                #TODO exec command
            end
        end
        # if scroll
        if Input.changed?
            @win.setpos 0, 0
            @win.deleteln
            @win.addstr Input.string
            @win.setpos 0, Input.cursor
            @win.refresh
        end
    end

    def self.redraw
        @wout.bkgd "#"
        @wout.noutrefresh
    end

    def self.resize_windows
        @win.resize 1, Curses.cols
        @win.move Curses.lines - @win.maxy, 0
        @wout.resize Curses.lines - @win.maxy, Curses.cols
        @wout.move 0, 0
    end

    module Input
        include Curses::Key

        @string = ""
        @cursor = 0
        @changed = true

        def Input.changed?
            @changed
        end

        def Input.string
            @changed = false
            @string
        end

        def Input.cursor
            @cursor
        end

        def Input.read(ch)
            #TODO horizontal scroll
            #TODO selection and clipboard support
            #TODO CTRL+Arrows, CTRL+BACKSPACE CTRL+DELET HOME, END Support (compatible with selection and hor scroll)
            #TODO suggestions (TAB Arrow Up/Down, maybe PPAGE, NPAGE)
            #TODO insert-mode
            case ch
            when RESIZE
                redraw
            when BACKSPACE, "\b"
                return unless @cursor > 0
                @changed = true
                @cursor -= 1
                @string.slice! @cursor
            when DC
                return if @string.empty?
                @changed = true
                @string.slice! @cursor
            when LEFT
                return unless cursor > 0
                @changed = true
                @cursor -= 1
            when RIGHT
                return unless cursor < @string.length
                @changed = true
                @cursor += 1
            when ENTER, "\n", "\r"
                return if @string.empty?
                @changed = true
                str = @string
                @string = ""
                return str
            else
                return unless ch.is_a?(String) && ch =~ /^[[:print:]]$/
                @changed = true
                @string.insert @cursor, ch
                @cursor += 1
            end
            return
        end
    end

    init
end

loop { UI.tick }
