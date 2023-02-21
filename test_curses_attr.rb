require "curses"

include Curses

init_screen
start_color
init_pair 1, COLOR_BLUE, COLOR_RED
cbreak
noecho
nl

attron A_NORMAL
addstr "Normal display (no highlight) (#{A_NORMAL.to_s 2})\n\n"
attroff A_NORMAL
refresh
attron A_STANDOUT
addstr "Best highlighting mode of the terminal. (#{A_STANDOUT.to_s 2})\n\n"
attroff A_STANDOUT
refresh
attron A_UNDERLINE
addstr "Underlining (#{A_UNDERLINE.to_s 2})\n\n"
attroff A_UNDERLINE
refresh
attron A_HORIZONTAL
addstr "Horizontal highlighting (#{A_HORIZONTAL.to_s 2})\n\n"
attroff A_HORIZONTAL
refresh
attron A_VERTICAL
addstr "Vertical highlighting (#{A_VERTICAL.to_s 2})\n\n"
attroff A_VERTICAL
refresh
attron A_LEFT
addstr "Left highlighting (#{A_LEFT.to_s 2})\n\n"
attroff A_LEFT
refresh
attron A_LOW
addstr "Low highlighting (#{A_LOW.to_s 2})\n\n"
attroff A_LOW
refresh
attron A_RIGHT
addstr "Right highlighting (#{A_RIGHT.to_s 2})\n\n"
attroff A_RIGHT
refresh
attron A_TOP
addstr "Top highlighting (#{A_TOP.to_s 2})\n\n"
attroff A_TOP
refresh
attron A_REVERSE
addstr "Reverse video (#{A_REVERSE.to_s 2})\n\n"
attroff A_REVERSE
refresh
attron A_BLINK
addstr "Blinking (#{A_BLINK.to_s 2})\n\n"
attroff A_BLINK
refresh
attron A_DIM
addstr "Half bright (#{A_DIM.to_s 2})\n\n"
attroff A_DIM
refresh
attron A_BOLD
addstr "Extra bright or bold (#{A_BOLD.to_s 2})\n\n"
attroff A_BOLD
refresh
attron A_PROTECT
addstr "Protected mode (#{A_PROTECT.to_s 2})\n\n"
attroff A_PROTECT
refresh
attron A_INVIS
addstr "Invisible or blank mode (#{A_INVIS.to_s 2})\n\n"
attroff A_INVIS
refresh
attron A_ALTCHARSET
addstr "Alternate character set (#{A_ALTCHARSET.to_s 2})\n\n"
attroff A_ALTCHARSET
refresh
refresh
attron color_pair 1
addstr "Color-pair number n (#{color_pair(1).to_s 2})\n\n"
attroff color_pair 1
refresh

getch
close_screen
