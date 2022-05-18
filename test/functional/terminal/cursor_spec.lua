local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local thelpers = require('test.functional.terminal.helpers')
local feed, clear, nvim = helpers.feed, helpers.clear, helpers.nvim
local nvim_dir, command = helpers.nvim_dir, helpers.command
local nvim_prog = helpers.nvim_prog
local eq, eval = helpers.eq, helpers.eval
local matches = helpers.matches
local feed_command = helpers.feed_command
local hide_cursor = thelpers.hide_cursor
local show_cursor = thelpers.show_cursor

describe(':terminal cursor', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup()
  end)


  it('moves the screen cursor when focused', function()
    thelpers.feed_data('testing cursor')
    screen:expect([[
      tty ready                                         |
      testing cursor{1: }                                   |
                                                        |
                                                        |
                                                        |
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('is highlighted when not focused', function()
    feed('<c-\\><c-n>')
    screen:expect([[
      tty ready                                         |
      {2:^ }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
                                                        |
    ]])
  end)

  describe('with number column', function()
    before_each(function()
      feed('<c-\\><c-n>:set number<cr>')
    end)

    it('is positioned correctly when unfocused', function()
      screen:expect([[
        {7:  1 }tty ready                                     |
        {7:  2 }^rows: 6, cols: 46                             |
        {7:  3 }{2: }                                             |
        {7:  4 }                                              |
        {7:  5 }                                              |
        {7:  6 }                                              |
        :set number                                       |
      ]])
    end)

    it('is positioned correctly when focused', function()
      screen:expect([[
        {7:  1 }tty ready                                     |
        {7:  2 }^rows: 6, cols: 46                             |
        {7:  3 }{2: }                                             |
        {7:  4 }                                              |
        {7:  5 }                                              |
        {7:  6 }                                              |
        :set number                                       |
      ]])
      feed('i')
      helpers.poke_eventloop()
      screen:expect([[
        {7:  1 }tty ready                                     |
        {7:  2 }rows: 6, cols: 46                             |
        {7:  3 }{1: }                                             |
        {7:  4 }                                              |
        {7:  5 }                                              |
        {7:  6 }                                              |
        {3:-- TERMINAL --}                                    |
      ]])
    end)
  end)

  describe('when invisible', function()
    it('is not highlighted and is detached from screen cursor', function()
      if helpers.pending_win32(pending) then return end
      hide_cursor()
      screen:expect([[
        tty ready                                         |
                                                          |
                                                          |
                                                          |
                                                          |
                                                          |
        {3:-- TERMINAL --}                                    |
      ]])
      show_cursor()
      screen:expect([[
        tty ready                                         |
        {1: }                                                 |
                                                          |
                                                          |
                                                          |
                                                          |
        {3:-- TERMINAL --}                                    |
      ]])
      -- same for when the terminal is unfocused
      feed('<c-\\><c-n>')
      hide_cursor()
      screen:expect([[
        tty ready                                         |
        ^                                                  |
                                                          |
                                                          |
                                                          |
                                                          |
                                                          |
      ]])
      show_cursor()
      screen:expect([[
        tty ready                                         |
        {2:^ }                                                 |
                                                          |
                                                          |
                                                          |
                                                          |
                                                          |
      ]])
    end)
  end)
end)


describe('cursor with customized highlighting', function()
  local screen

  before_each(function()
    clear()
    nvim('command', 'highlight TermCursor ctermfg=45 ctermbg=46 cterm=NONE')
    nvim('command', 'highlight TermCursorNC ctermfg=55 ctermbg=56 cterm=NONE')
    screen = Screen.new(50, 7)
    screen:set_default_attr_ids({
      [1] = {foreground = 45, background = 46},
      [2] = {foreground = 55, background = 56},
      [3] = {bold = true},
    })
    screen:attach({rgb=false})
    command('call termopen(["'..nvim_dir..'/tty-test"])')
    feed_command('startinsert')
  end)

  it('overrides the default highlighting', function()
    screen:expect([[
      tty ready                                         |
      {1: }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed('<c-\\><c-n>')
    screen:expect([[
      tty ready                                         |
      {2:^ }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
                                                        |
    ]])
  end)
end)

describe('buffer cursor position is correct in terminal without number column', function()
  local screen

  local function setup_ex_register(str)
    screen = thelpers.screen_setup(0, '["'..nvim_prog
      ..[[", "-u", "NONE", "-i", "NONE", "-E", "--cmd", "let @r = ']]..str..[['", ]]
      -- <Left> and <Right> don't always work
      ..[["--cmd", "cnoremap <C-X> <Left>", "--cmd", "cnoremap <C-O> <Right>"]]..']', 70)
    screen:expect([[
                                                                            |
                                                                            |
                                                                            |
                                                                            |
      Entering Ex mode.  Type "visual" to go to Normal mode.                |
      :{1: }                                                                    |
      {3:-- TERMINAL --}                                                        |
    ]])
  end

  before_each(clear)

  describe('in a line with no multibyte characters or trailing spaces,', function()
    before_each(function()
      setup_ex_register('aaaaaaaa')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :aaaaaaaa{1: }                                                            |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 9}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :aaaaaaa^a{2: }                                                            |
                                                                              |
      ]])
      eq({6, 8}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :aaaaaa{1:a}a                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 7}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :aaaaa^a{2:a}a                                                             |
                                                                              |
      ]])
      eq({6, 6}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :a{1:a}aaaaaa                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 2}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :^a{2:a}aaaaaa                                                             |
                                                                              |
      ]])
      eq({6, 1}, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with single-cell multibyte characters and no trailing spaces,', function()
    before_each(function()
      setup_ex_register('µµµµµµµµ')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µµµµµµµµ{1: }                                                            |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 17}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µµµµµµµ^µ{2: }                                                            |
                                                                              |
      ]])
      eq({6, 15}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µµµµµµ{1:µ}µ                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 13}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µµµµµ^µ{2:µ}µ                                                             |
                                                                              |
      ]])
      eq({6, 11}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ{1:µ}µµµµµµ                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 3}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :^µ{2:µ}µµµµµµ                                                             |
                                                                              |
      ]])
      eq({6, 1}, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with single-cell composed multibyte characters and no trailing spaces,', function()
    if helpers.pending_win32(pending) then return end  -- These tests fail on Windows. Encoding problem?

    before_each(function()
      setup_ex_register('µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳{1: }                                                            |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 33}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳µ̳µ̳µ̳µ̳µ̳µ̳^µ̳{2: }                                                            |
                                                                              |
      ]])
      eq({6, 29}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳µ̳µ̳µ̳µ̳µ̳{1:µ̳}µ̳                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 25}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳µ̳µ̳µ̳µ̳^µ̳{2:µ̳}µ̳                                                             |
                                                                              |
      ]])
      eq({6, 21}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳{1:µ̳}µ̳µ̳µ̳µ̳µ̳µ̳                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 5}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :^µ̳{2:µ̳}µ̳µ̳µ̳µ̳µ̳µ̳                                                             |
                                                                              |
      ]])
      eq({6, 1}, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with double-cell multibyte characters and no trailing spaces,', function()
    if helpers.pending_win32(pending) then return end  -- These tests fail on Windows. Encoding problem?

    before_each(function()
      setup_ex_register('哦哦哦哦哦哦哦哦')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦哦哦哦哦哦哦哦{1: }                                                    |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 25}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦哦哦哦哦哦哦^哦{2: }                                                    |
                                                                              |
      ]])
      eq({6, 22}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦哦哦哦哦哦{1:哦}哦                                                     |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 19}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦哦哦哦哦^哦{2:哦}哦                                                     |
                                                                              |
      ]])
      eq({6, 16}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦{1:哦}哦哦哦哦哦哦                                                     |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 4}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |
                                                                              |
                                                                              |
                                                                              |
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :^哦{2:哦}哦哦哦哦哦哦                                                     |
                                                                              |
      ]])
      eq({6, 1}, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  it('at the end of a line with trailing spaces #16234', function()
    setup_ex_register('aaaaaaaa    ')
    feed('<C-R>r')
    screen:expect([[
                                                                            |
                                                                            |
                                                                            |
                                                                            |
      Entering Ex mode.  Type "visual" to go to Normal mode.                |
      :aaaaaaaa    {1: }                                                        |
      {3:-- TERMINAL --}                                                        |
    ]])
    matches('^:aaaaaaaa    [ ]*$', eval('nvim_get_current_line()'))
    eq({6, 13}, eval('nvim_win_get_cursor(0)'))
    feed([[<C-\><C-N>]])
    screen:expect([[
                                                                            |
                                                                            |
                                                                            |
                                                                            |
      Entering Ex mode.  Type "visual" to go to Normal mode.                |
      :aaaaaaaa   ^ {2: }                                                        |
                                                                            |
    ]])
    eq({6, 12}, eval('nvim_win_get_cursor(0)'))
  end)
end)

describe('buffer cursor position is correct in terminal with number column', function()
  local screen

  local function setup_ex_register(str)
    screen = thelpers.screen_setup(0, '["'..nvim_prog
      ..[[", "-u", "NONE", "-i", "NONE", "-E", "--cmd", "let @r = ']]..str..[['", ]]
      -- <Left> and <Right> don't always work
      ..[["--cmd", "cnoremap <C-X> <Left>", "--cmd", "cnoremap <C-O> <Right>"]]..']', 70)
    screen:expect([[
      {7:  1 }                                                                  |
      {7:  2 }                                                                  |
      {7:  3 }                                                                  |
      {7:  4 }                                                                  |
      {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
      {7:  6 }:{1: }                                                                |
      {3:-- TERMINAL --}                                                        |
    ]])
  end

  before_each(function()
    clear()
    command('set number')
  end)

  describe('in a line with no multibyte characters or trailing spaces,', function()
    before_each(function()
      setup_ex_register('aaaaaaaa')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:aaaaaaaa{1: }                                                        |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 9}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:aaaaaaa^a{2: }                                                        |
                                                                              |
      ]])
      eq({6, 8}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:aaaaaa{1:a}a                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 7}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:aaaaa^a{2:a}a                                                         |
                                                                              |
      ]])
      eq({6, 6}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:a{1:a}aaaaaa                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 2}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:^a{2:a}aaaaaa                                                         |
                                                                              |
      ]])
      eq({6, 1}, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with single-cell multibyte characters and no trailing spaces,', function()
    before_each(function()
      setup_ex_register('µµµµµµµµ')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µµµµµµµµ{1: }                                                        |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 17}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µµµµµµµ^µ{2: }                                                        |
                                                                              |
      ]])
      eq({6, 15}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µµµµµµ{1:µ}µ                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 13}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µµµµµ^µ{2:µ}µ                                                         |
                                                                              |
      ]])
      eq({6, 11}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ{1:µ}µµµµµµ                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 3}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:^µ{2:µ}µµµµµµ                                                         |
                                                                              |
      ]])
      eq({6, 1}, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with single-cell composed multibyte characters and no trailing spaces,', function()
    if helpers.pending_win32(pending) then return end  -- These tests fail on Windows. Encoding problem?

    before_each(function()
      setup_ex_register('µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳{1: }                                                        |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 33}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳µ̳µ̳µ̳µ̳µ̳µ̳^µ̳{2: }                                                        |
                                                                              |
      ]])
      eq({6, 29}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳µ̳µ̳µ̳µ̳µ̳{1:µ̳}µ̳                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 25}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳µ̳µ̳µ̳µ̳^µ̳{2:µ̳}µ̳                                                         |
                                                                              |
      ]])
      eq({6, 21}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳{1:µ̳}µ̳µ̳µ̳µ̳µ̳µ̳                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 5}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:^µ̳{2:µ̳}µ̳µ̳µ̳µ̳µ̳µ̳                                                         |
                                                                              |
      ]])
      eq({6, 1}, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with double-cell multibyte characters and no trailing spaces,', function()
    if helpers.pending_win32(pending) then return end  -- These tests fail on Windows. Encoding problem?

    before_each(function()
      setup_ex_register('哦哦哦哦哦哦哦哦')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦哦哦哦哦哦哦哦{1: }                                                |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 25}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦哦哦哦哦哦哦^哦{2: }                                                |
                                                                              |
      ]])
      eq({6, 22}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦哦哦哦哦哦{1:哦}哦                                                 |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 19}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦哦哦哦哦^哦{2:哦}哦                                                 |
                                                                              |
      ]])
      eq({6, 16}, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦{1:哦}哦哦哦哦哦哦                                                 |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({6, 4}, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:^哦{2:哦}哦哦哦哦哦哦                                                 |
                                                                              |
      ]])
      eq({6, 1}, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  it('at the end of a line with trailing spaces #16234', function()
    setup_ex_register('aaaaaaaa    ')
    feed('<C-R>r')
    screen:expect([[
      {7:  1 }                                                                  |
      {7:  2 }                                                                  |
      {7:  3 }                                                                  |
      {7:  4 }                                                                  |
      {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
      {7:  6 }:aaaaaaaa    {1: }                                                    |
      {3:-- TERMINAL --}                                                        |
    ]])
    matches('^:aaaaaaaa    [ ]*$', eval('nvim_get_current_line()'))
    eq({6, 13}, eval('nvim_win_get_cursor(0)'))
    feed([[<C-\><C-N>]])
    screen:expect([[
      {7:  1 }                                                                  |
      {7:  2 }                                                                  |
      {7:  3 }                                                                  |
      {7:  4 }                                                                  |
      {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
      {7:  6 }:aaaaaaaa   ^ {2: }                                                    |
                                                                            |
    ]])
    eq({6, 12}, eval('nvim_win_get_cursor(0)'))
  end)
end)
