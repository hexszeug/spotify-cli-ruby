require "curses"

include Curses

def print(*obj)
    obj = obj * " " if obj.is_a? Array
    addstr obj.to_s
end

def puts(*obj)
    print obj
    addstr "\n"
end

init_screen
start_color
noecho
cbreak
nl

win = stdscr
win.keypad true
win.timeout = 0
win.scrollok true

# win.resize 10, 10
# win.move 10, 10

win.setscrreg 0, win.maxy - 2

# bkgd "#"

loop do
    win.refresh
    x = win.getch
    break if x == "q"
    if x == KEY_UP
        win.scrl -1
    elsif x == KEY_DOWN
        win.scrl 1
    else
        print x
    end

    cx, cy = win.curx, win.cury
    win.setpos win.maxy - 1, 0
    win.deleteln
    puts "C: x: #{cx}, y:#{cy}"
    win.setpos cy, cx
end

# loop do
#     refresh
#     x = getch
#     addstr x.to_s
#     addch x if x == 10
#     break if x == "q"
#     scrl 10 if x == "w"
# end

close_screen
