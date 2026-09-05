local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local command = n.command
local feed = n.feed
local insert = n.insert
local api = n.api

-- The cursor position is asserted along with the text: "^" marks the cell the
-- cursor sits in, which is what 'bidi' has to get right.
describe("'bidi'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30, 6)
    command('set bidi=auto')
  end)

  it('leaves a left-to-right line alone', function()
    insert('hello world!')
    feed('0')
    screen:expect([[
      ^hello world!                  |
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('reverses a right-to-left line and starts it at the right margin', function()
    insert('שלום עולם')
    feed('0')
    screen:expect([[
                           םלוע םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('draws trailing punctuation at the end of the sentence', function()
    insert('שלום עולם?')
    feed('0')
    screen:expect([[
                          ?םלוע םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('orders the words of a right-to-left line and keeps Latin readable', function()
    insert('שלום world עולם')
    feed('0')
    -- read right to left: שלום, world, עולם
    screen:expect([[
                     םלוע world םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('keeps a number in logical order', function()
    insert('שלום 123 עולם')
    feed('0')
    screen:expect([[
                       םלוע 123 םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('keeps the separator inside a number', function()
    insert('מחיר 45.90 שקל')
    feed('0')
    screen:expect([[
                      לקש 45.90 ריח^מ|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('mirrors brackets', function()
    insert('(שלום)')
    feed('0')
    screen:expect([[
                              (םולש^)|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('does not move the number column', function()
    command('set number')
    insert('שלום')
    feed('0')
    screen:expect([[
      {8:  1 }                      םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('puts the cursor at the insertion point when appending', function()
    insert('שלום')
    feed('A')
    -- a right-to-left line ends at its left edge, where the next character goes
    screen:expect([[
                                ^םולש|
      {1:~                             }|*4
      {5:-- INSERT --}                  |
    ]])
  end)

  it('takes the direction from the text, not from virtual text', function()
    insert('שלום עולם')
    local ns = api.nvim_create_namespace('bidi')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { 'XX' } }, virt_text_pos = 'inline' })
    feed('gg')
    -- Latin virtual text must not make the line look left-to-right
    screen:expect([[
                         םלוע םול^שXX|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('keeps the columns in place when only they are redrawn', function()
    command('set number relativenumber')
    insert('שלום עולם\nשלום עולם\nשלום עולם')
    feed('ggjk')
    -- moving the cursor redraws only the number column of the other lines
    screen:expect([[
      {8:1   }                 םלוע םול^ש|
      {8:  1 }                 םלוע םולש|
      {8:  2 }                 םלוע םולש|
      {1:~                             }|*2
                                    |
    ]])
  end)

  it('is inert when off', function()
    command('set bidi=')
    insert('שלום עולם')
    feed('0')
    screen:expect([[
      ^שלום עולם                     |
      {1:~                             }|*4
                                    |
    ]])
  end)
end)

describe("'bidi' with a wrapped line", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20, 6)
    command('set bidi=auto')
    insert('אחת שתיים שלוש ארבע חמש שש')
  end)

  it('reorders each screen row and pads only the last', function()
    feed('gg0')
    screen:expect([[
       עברא שולש םייתש תח^א|
                    שש שמח|
      {1:~                   }|*3
                          |
    ]])
  end)

  it('puts the cursor on the row holding the character', function()
    feed('gg$')
    screen:expect([[
       עברא שולש םייתש תחא|
                    ^שש שמח|
      {1:~                   }|*3
                          |
    ]])
  end)
end)

describe("'bidi' embedding levels", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 4)
    command('set bidi=auto')
  end)

  it('resolves Latin nested inside a right-to-left line', function()
    insert('אמרתי he said שלום ואז')
    feed('gg0')
    screen:expect([[
                        זאו םולש he said יתרמ^א|
      {1:~                                       }|*2
                                              |
    ]])
  end)

  it('resolves Hebrew nested inside a left-to-right line', function()
    insert('He said אמרתי שלום to me')
    feed('gg0')
    screen:expect([[
      ^He said םולש יתרמא to me                |
      {1:~                                       }|*2
                                              |
    ]])
  end)

  it('keeps a currency sign with its number', function()
    insert('מחיר 45.90$ בלבד')
    feed('gg0')
    screen:expect([[
                              דבלב 45.90$ ריח^מ|
      {1:~                                       }|*2
                                              |
    ]])
  end)
end)

describe("'bidi' with virtual text", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30, 6)
    command('set bidi=auto')
  end)

  -- Name the cells that hold text instead of counting out the blanks between
  -- them.  Each segment is { column, cell, cell, ... }; "cursor" is the column
  -- the cursor sits in.
  local function expect_row(cursor, ...)
    local cells = {}
    for _, segment in ipairs({ ... }) do
      for i = 2, #segment do
        cells[segment[1] + i - 2] = segment[i]
      end
    end

    local row = {}
    for col = 0, 29 do
      row[#row + 1] = (col == cursor and '^' or '') .. (cells[col] or ' ')
    end

    screen:expect(table.concat({
      table.concat(row) .. '|',
      '{1:~' .. (' '):rep(29) .. '}|*4',
      (' '):rep(30) .. '|',
      '',
    }, '\n'))
  end

  local function set_virt_text(pos, col, text)
    local ns = api.nvim_create_namespace('bidi')
    api.nvim_buf_set_extmark(0, ns, 0, col, { virt_text = { { text } }, virt_text_pos = pos })
  end

  it('covers the characters an overlay is drawn over in a right-to-left run', function()
    insert('a שלום b')
    set_virt_text('overlay', 2, 'XY') -- covers "ש" and "ל"
    feed('gg0')
    -- the run reads "םולש": "ש" and "ל" are its two rightmost cells
    expect_row(0, { 0, 'a', ' ', 'ם', 'ו', 'X', 'Y', ' ', 'b' })
  end)

  it('covers the characters an overlay is drawn over in a right-to-left line', function()
    insert('שלום עולם')
    set_virt_text('overlay', 0, 'XY') -- covers "ש" and "ל"
    feed('gg0')
    expect_row(28, { 21, 'ם', 'ל', 'ו', 'ע', ' ', 'ם', 'ו', 'X', 'Y' })
  end)

  it('reorders right-to-left virtual text on its own', function()
    insert('a שלום')
    set_virt_text('eol', 0, 'אב')
    feed('gg0')
    -- the virtual text reads right to left, but must not join the run before it
    expect_row(0, { 0, 'a', ' ', 'ם', 'ו', 'ל', 'ש', ' ', 'ב', 'א' })
  end)

  it('draws end-of-line virtual text at the end of a right-to-left line', function()
    insert('שלום עולם')
    set_virt_text('eol', 0, 'XY')
    feed('gg0')
    -- a right-to-left line ends at its left edge
    expect_row(29, { 18, 'X', 'Y', ' ', 'ם', 'ל', 'ו', 'ע', ' ', 'ם', 'ו', 'ל', 'ש' })
  end)

  it('draws right-aligned virtual text at the far edge of a right-to-left line', function()
    insert('שלום עולם')
    set_virt_text('right_align', 0, 'XY')
    feed('gg0')
    -- the text has taken the right margin, so the far edge is the left one
    expect_row(29, { 0, 'X', 'Y' }, { 21, 'ם', 'ל', 'ו', 'ע', ' ', 'ם', 'ו', 'ל', 'ש' })
  end)

  it('keeps left-to-right virtual text readable inside a right-to-left line', function()
    insert('שלום עולם')
    set_virt_text('inline', 8, 'XY')
    feed('gg0')
    expect_row(29, { 19, 'ם', 'ל', 'ו', 'ע', ' ', 'X', 'Y', 'ם', 'ו', 'ל', 'ש' })
  end)
end)

describe("'bidi' forced direction", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30, 6)
  end)

  it('starts every line at the right margin with "rtl"', function()
    command('set bidi=rtl')
    insert('hello')
    feed('0')
    screen:expect([[
                               ^hello|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('keeps a Hebrew line at the left margin with "ltr"', function()
    command('set bidi=ltr')
    insert('שלום עולם')
    feed('0')
    screen:expect([[
      םלוע םול^ש                     |
      {1:~                             }|*4
                                    |
    ]])
  end)
end)

describe("'bidi' paragraph direction", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(34, 7)
    command('set bidi=auto')
  end)

  it('aligns every line of a paragraph the same way', function()
    insert(
      'neovim הוא עורך טוב\nאני כותב בו בעברית\n\nשלום עולם\nעוד שורה'
    )
    feed('gg')
    -- the first paragraph opens with a Latin word, so all of it reads
    -- left to right; the second is Hebrew throughout
    screen:expect([[
      ^neovim בוט ךרוע אוה               |
      תירבעב וב בתוכ ינא                |
                                        |
                               םלוע םולש|
                                הרוש דוע|
      {1:~                                 }|
                                        |
    ]])
  end)
end)

describe("'bidi' beside the options it defers to", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30, 6)
    command('set bidi=auto')
  end)

  it("leaves the line to 'rightleft'", function()
    command('set rightleft')
    insert('שלום world')
    feed('0')
    screen:expect([[
                          dlrow םול^ש|
      {1:                             ~}|*4
                                    |
    ]])
  end)

  it("stands down for 'termbidi'", function()
    command('set termbidi')
    insert('שלום עולם')
    feed('0')
    screen:expect([[
      ^שלום עולם                     |
      {1:~                             }|*4
                                    |
    ]])
  end)
end)

describe("'bidi' with the columns and characters beside the text", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30, 6)
    command('set bidi=auto')
  end)

  it('keeps a double-width character with its second cell', function()
    insert('שלום 世界 עולם')
    feed('0')
    screen:expect([[
                      םלוע 世界 םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('reorders the text of a closed fold', function()
    insert('שלום עולם\nעוד שורה')
    command('set foldmethod=manual')
    feed('ggVGzf')
    screen:expect([[
      {13:^+--  2 lines: םלוע םולש·······}|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('does not reorder the sign and number columns', function()
    command('set number signcolumn=yes')
    insert('שלום עולם')
    feed('0')
    screen:expect([[
      {7:  }{8:  1 }               םלוע םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)
end)

describe("'bidi' beside the options that change a line's shape", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30, 6)
    command('set bidi=auto')
  end)

  it("draws the 'list' characters at the end of the line", function()
    command('set list listchars=eol:$,trail:-')
    insert('שלום עולם ')
    feed('0')
    screen:expect([[
                         {1:$-}םלוע םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it("does not reorder a 'statuscolumn'", function()
    command('set number statuscolumn=%l\\ ')
    insert('שלום עולם')
    feed('0')
    screen:expect([[
      {8:  1 }                 םלוע םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it("reorders the visible part of a 'nowrap' line", function()
    command('set nowrap')
    insert('שלום עולם שלום עולם שלום עולם שלום עולם')
    feed('$')
    screen:expect([[
       ^םלוע םולש םלוע םולש םלוע םולש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it("puts 'cursorcolumn' on the cell the cursor is in", function()
    command('set cursorcolumn')
    insert('שלום עולם\nשלום עולם')
    feed('gg0ll')
    screen:expect([[
                           םלוע ם^ולש|
                           םלוע ם{21:ו}לש|
      {1:~                             }|*3
                                    |
    ]])
  end)
end)

describe("'bidi' beside the features that draw over a line", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30, 6)
    command('set bidi=auto')
  end)

  it("shapes Arabic the way 'rightleft' does", function()
    command('set arabicshape')
    insert('سلام دنيا')
    feed('0')
    -- The same glyphs 'rightleft' produces, which is the path that has always
    -- been supported: reordering the cells does not disturb the shaping.
    screen:expect([[
                            ﺎﻴﻧﺩ ﻡﻼ^ﺳ|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('keeps a concealed character in its place', function()
    command('set conceallevel=2 concealcursor=n')
    command('syntax match Hidden /XX/ conceal cchar=@')
    insert('שלום XX עולם')
    feed('0')
    screen:expect([[
                         םלוע {14:@} םול^ש|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('keeps a combining mark with the character it sits on', function()
    insert('שָׁלוֹם עוֹלָם')
    feed('0')
    screen:expect([[
                           םלָוֹע םוֹל^שָׁ|
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('highlights the cells a Visual selection covers', function()
    insert('שלום עולם')
    feed('0vlll')
    screen:expect([[
                           םלוע ^ם{17:ולש}|
      {1:~                             }|*4
      {5:-- VISUAL --}                  |
    ]])
  end)
end)
