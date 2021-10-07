# Display

## Main overview:

`update_screen() -> win_update() -> win_line() -> ui_line()` for each row in the 
buffer.

All lines are drawn on a `ScreenGrid` instance. If the user does
not specify ext_multigrid, everything is drawn on `default_grid`
instead of using `wp->w_grid`. However, even though `wp->w_grid`
does not store any text, it is still used to perform bounds
checking, for example to determine if we need to wrap.
This checking is done in`screen_adjust_grid()` - this is where
row and column offsets are calculated.

Whenever window attributes are changed (such as in a resize),
`win_grid_alloc` is called, to ensure that window attributes
such as `w_width_inner` and such are in sync with `grid.Cols`,
`grid.Rows`.

## Cursor Display

`w_wincol` and `w_winrow` specify row and col offsets from the
edge of the window. Not sure where they are used.

`w_wrow` and `w_wcol` are cached values for the position of the
cursor. Note that these represent the visual position: this
might be different from `w_cursor.col/row` in the event that we have
multibyte characters, conceal, when signcolumn/numbercolum
is active, and most importantly, when the line is wrapped.

When the line is concealed, `w_wrow` and `w_wcol` store the visual
cursor positions, instead of the literal cursor positions.
These are updated in `win_line` whenever it is called, and reset
to their literal values by calls to `validate_cursor -> curs_columns`.

## win_line

win_line() iterates over every single char in the line.
For each iteration, we do multiple sweeps, with each sweep focusing on
drawing a different part of the screen. For example, we start off by
drawing the cmdline, then folds/signcolumns, then numberline, then finally
the actual characters in the buffer.

`ptr` and `line` point to the current line to be drawn (but ptr starts at the part
of the line yet to be processed, while `line` is the whole line),
`col` and `vcol` point to the current position and virtual position we are at in 
the line, and `off` points to the offset for the start of the line.
The char to be put into `linebuf` is stored in `c` or `mb_c` if the character
is multibyte.

The char then gets written to `linebuf_char`. At the end
of drawing, `linebuf_char` is compared to `wp->w_grid` (or
`default_grid`) via `grid_put_linebuf()`, and any changes are
copied over. The comparisons between the char in `linebuf_char`
and `wp->w_grid` is done in `grid_char_needs_redraw`.

Before drawing the actual buffer lines, `win_line()` first
checks to see if there are any extra chars to be drawn first - for example,
the numberline, signcolumn, foldtext, etc.
These chars are stored in `p_extra` and `c_extra` (and `c_final` if it exists).
If there is just one extra char, ie we are inserting a bunch of spaces,
we use `c_extra` coupled with `n_extra`; otherwise, we just
use `p_extra`.

Win_line also keeps track of which highlights are active at position `col`.
The highlight of the char `c` (or `mb_c`) is stored in `char_attr`; often,
we will call `hl_combind_attr` to merge together two competing highlights
for the same column.

Syntax matches are tracked by `syntax_seqnr`. Win_line calls `syn_get_flags`
to potentially increment `syntax_seqnr`, and also retrieve any active
highlight information for the current character. It then does a similar
process to retrieve any spell highlighting, listchars highlighting, etc.

Wrapping: todo

Map of win_line:

-- start of win_line

-- definitions of variables

-- set extra_check - this determines whether syntax highlighting or linebreak
highlighting is on. Call `syntax_start()` to begin syntax matching, invoke
any decoration providers for the start of redraw, begin spell checking if
necessary, initialize any visual mode or incsearch highlighting (need to understand
last two more).

-- register any filler lines, if we are in diff mode.

-- do cursorline highlighting.

-- handle wrapping (need to understand)

-- handle highlighting of matches (from `matchadd()`) or incsearch highlighting.
Iterate over all matches and do ??


-- START OF LONG FOR LOOP

--    quickly go through the first few draw states; draw the command line
char, draw the foldcolumn, draw numberline, breakindent, etc.

--    more match highlighting?

--    set `c` or `mb_c`; first use `c_extra`, `p_extra` if available.
If we are drawing a foldline, don't compute `c` at all; otherwise, get
`c` directly from the line, by defererencing `*ptr`. 

The last option is the most important; it takes almost 600 lines to iron out 
any small details. First, after storing `c/mb_c` and handling any quirks
with multibyte chars, start composing highlights for the character.
First, get the syntax attributes and flags. Then, add any spelling attributes.
If there is extmark highlighting, add that on top. Some extra stuff
I don't understand for linebreak and listchars.

Next, we get to conceal. If the computed `syntax_flags` indicate that
the match is to be concealed, we must do the following:

Is this the first time we are at this concealed syntax match?
If so, set `c` to be the concealed char (cchar).

Then, add any offsets to the column - we adjust vcol_off,
boguscols, vcol, and col (haven't completely figured out yet).

--    If not printable character (figure out).

--    If we have been concealing (see prev section), adjust the 
cursor position by recomputing `w_wcol`.


--    If we are at the end of the text, or at the last character
of the line, (another 300 line if statement, figure out later).

--    Highlight cursorcolumn.

--    Put `c/mb_c` into `linebuf_char`, and increment `col/vcol`
(some vodoo done here that I can't figure out).

--    Display the line.


-- End loop.

## UI

`grid_put_linebuf()` is called by `win_line` to put a line (`linebuf_char`)
into the grid used to display the current window. It first computes the offsets
for where to start drawing from in the grid (the offsets are only applicable
if we are not using multigrid, since everything then has to be drawn on
`default_grid`). 

The chars and highlight attributes are copied over to the `grid->chars`
array, and everything after that is cleared (how much to clear until is
set by `clear_width`).

Finally, `grid_put_linebuf` shells out to `ui_line` to actually show the redraw,
and send the ui event for a redrawn line.

If there is no external ui attached, `ui_line` will then redirect through
`ui_bridge.c` into `ui_compositor.c`, and then to `tui.c`.
The main functions of interest in `ui_compositor` are `ui_comp_raw_line`, `compose_area`, and `compose_line` 
- these are the functions that actually compose and send 
the ui events.

`compose_line` is the final stop of this long chain. This is where all of the
literal characters on screen (including `default_grid`, floating windows, etc)
are combined.
The key here is another variable `linebuf`. For each column, we find the grid
with the highest z-axis such that (row, column) lies within this grid, and then
put the char at that position in `linebuf`. For example, suppose that position
(1, 2) is inside a floating window. Then `linebuf[col]` would contain the char
from the floating window, *not* the char from the grid underneath.

Note: the selection of which grid to use depends not only on whether it contains
the (row, col) position, but also on the value of `g->comp_disabled`.

UI screen update events are read and displayed from `loop_poll_events`, which
is called at `os_breakcheck` intervals.

Where is the entire grid redrawn?

## Possible PRs

- TODO edit_and_undo
- TODO Virtual conceal
- TODO Multiline virttext
- TODO General conceal refactor
- TODO Implement \zs for :global commmand
- TODO Lua expr registers
- TODO Better command line completion

Repro:

- go to regexp.c
- substitute `discarded` for `num_escaped`
- go to comment on line 6668
- select one line down, one past the period and press `c`.
