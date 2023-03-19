require "curses"

include Curses
init_screen
start_color
noecho
cbreak
nl

win = stdscr
win.keypad true
win.nodelay = true
win.scrollok true

win.addstr "0x#{mousemask(REPORT_MOUSE_POSITION).to_s 16}\n"

loop do
    win.refresh
    x = win.get_char
    # x = win.getch
    break if x == "q"
    scrl -1 if x == KEY_UP
    scrl 1 if x == KEY_DOWN
    if x
        case x
        when String
            addstr x.dump
            # x.each_byte { |b| win.addstr b.to_s 16 }
        else
            if x == KEY_MOUSE
                m = getmouse
                win.addstr " Mouse(buttons: 0x#{m.bstate.to_s 16}, pos: #{m.x}, #{m.y}, #{m.z})  "
            else
                win.addstr " #{keyname x}(0x#{x.to_s 16}) "
            end
        end
    end
end

close_screen
