local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local funcs = helpers.funcs
local wait = helpers.wait

describe('search cmdline', function()
  local screen

  before_each(function()
    clear()
    command('set nohlsearch')
    screen = Screen.new(20, 3)
    screen:attach()
    screen:set_default_attr_ids({
      inc = {reverse = true}
    })
  end)

  local function tenlines()
    funcs.setline(1, {
      '  1', '  2 these', '  3 the', '  4 their', '  5 there',
      '  6 their', '  7 the', '  8 them', '  9 these', ' 10 foobar'
    })
    command('1')
  end

  it('history can be navigated with <C-N>/<C-P>', function()
    tenlines()
    command('set noincsearch')
    feed('/foobar<CR>')
    feed('/the<CR>')
    eq('the', eval('@/'))
    feed('/thes<C-P><C-P><CR>')
    eq('foobar', eval('@/'))
  end)

  describe('can traverse matches', function()
    before_each(tenlines)
    local function forwarditer(wrapscan)
      command('set incsearch '..wrapscan)
      feed('/the')
      screen:expect([[
          1                 |
          2 {inc:the}se           |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          2 these           |
          3 {inc:the}             |
        /the^                |
      ]])
      eq({0, 0, 0, 0}, funcs.getpos('"'))
      feed('<C-G>')
      screen:expect([[
          3 the             |
          4 {inc:the}ir           |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          4 their           |
          5 {inc:the}re           |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          5 there           |
          6 {inc:the}ir           |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          6 their           |
          7 {inc:the}             |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          7 the             |
          8 {inc:the}m            |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          8 them            |
          9 {inc:the}se           |
        /the^                |
      ]])
      screen.bell = false
      feed('<C-G>')
      if wrapscan == 'wrapscan' then
        screen:expect([[
            2 {inc:the}se           |
            3 the             |
          /the^                |
        ]])
      else
        screen:expect{grid=[[
            8 them            |
            9 {inc:the}se           |
          /the^                |
        ]], condition=function()
          eq(true, screen.bell)
        end}
        feed('<CR>')
        eq({0, 0, 0, 0}, funcs.getpos('"'))
      end
    end

    local function backiter(wrapscan)
      command('set incsearch '..wrapscan)
      command('$')

      feed('?the')
      screen:expect([[
          9 {inc:the}se           |
         10 foobar          |
        ?the^                |
      ]])
      screen.bell = false
      if wrapscan == 'wrapscan' then
        feed('<C-G>')
        screen:expect([[
            2 {inc:the}se           |
            3 the             |
          ?the^                |
        ]])
        feed('<CR>')
        screen:expect([[
            2 ^these           |
            3 the             |
          ?the                |
        ]])
      else
        feed('<C-G>')
        screen:expect{grid=[[
            9 {inc:the}se           |
           10 foobar          |
          ?the^                |
        ]], condition=function()
          eq(true, screen.bell)
        end}
        feed('<CR>')
        screen:expect([[
            9 ^these           |
           10 foobar          |
          ?the                |
        ]])
      end
      command('$')
      feed('?the')
      screen:expect([[
          9 {inc:the}se           |
         10 foobar          |
        ?the^                |
      ]])
      feed('<C-T>')
      screen:expect([[
          8 {inc:the}m            |
          9 these           |
        ?the^                |
      ]])
      for i = 1, 6 do
        feed('<C-T>')
        -- Avoid sleep just before expect, otherwise expect will take the full
        -- timeout
        if i ~= 6 then
          screen:sleep(1)
        end
      end
      screen:expect([[
          2 {inc:the}se           |
          3 the             |
        ?the^                |
      ]])
      screen.bell = false
      feed('<C-T>')
      if wrapscan == 'wrapscan' then
        screen:expect([[
            9 {inc:the}se           |
           10 foobar          |
          ?the^                |
        ]])
      else
        screen:expect{grid=[[
            2 {inc:the}se           |
            3 the             |
          ?the^                |
        ]], condition=function()
          eq(true, screen.bell)
        end}
      end
    end

    it("using <C-G> and 'nowrapscan'", function()
      forwarditer('nowrapscan')
    end)

    it("using <C-G> and 'wrapscan'", function()
      forwarditer('wrapscan')
    end)

    it("using <C-T> and 'nowrapscan'", function()
      backiter('nowrapscan')
    end)

    it("using <C-T> and 'wrapscan'", function()
      backiter('wrapscan')
    end)
  end)

  it('expands pattern with <C-L>', function()
    tenlines()
    command('set incsearch wrapscan')

    feed('/the')
    screen:expect([[
        1                 |
        2 {inc:the}se           |
      /the^                |
    ]])
    feed('<C-L>')
    screen:expect([[
        1                 |
        2 {inc:thes}e           |
      /thes^               |
    ]])
    feed('<C-G>')
    screen:expect([[
        9 {inc:thes}e           |
       10 foobar          |
      /thes^               |
    ]])
    feed('<C-G>')
    screen:expect([[
        2 {inc:thes}e           |
        3 the             |
      /thes^               |
    ]])
    feed('<CR>')
    screen:expect([[
        2 ^these           |
        3 the             |
      /thes               |
    ]])

    command('1')
    command('set nowrapscan')
    feed('/the')
    screen:expect([[
        1                 |
        2 {inc:the}se           |
      /the^                |
    ]])
    feed('<C-L>')
    screen:expect([[
        1                 |
        2 {inc:thes}e           |
      /thes^               |
    ]])
    feed('<C-G>')
    screen:expect([[
        9 {inc:thes}e           |
       10 foobar          |
      /thes^               |
    ]])
    feed('<C-G><CR>')
    screen:expect([[
        9 ^these           |
       10 foobar          |
      /thes               |
    ]])
  end)

  it('reduces pattern with <BS> and keeps cursor position', function()
    tenlines()
    command('set incsearch wrapscan')

    -- First match
    feed('/thei')
    screen:expect([[
        4 {inc:thei}r           |
        5 there           |
      /thei^               |
    ]])
    -- Match from initial cursor position when modifying search
    feed('<BS>')
    screen:expect([[
        1                 |
        2 {inc:the}se           |
      /the^                |
    ]])
    -- New text advances to next match
    feed('s')
    screen:expect([[
        1                 |
        2 {inc:thes}e           |
      /thes^               |
    ]])
    -- Stay on this match when deleting a character
    feed('<BS>')
    screen:expect([[
        1                 |
        2 {inc:the}se           |
      /the^                |
    ]])
    -- Advance to previous match
    feed('<C-T>')
    screen:expect([[
        9 {inc:the}se           |
       10 foobar          |
      /the^                |
    ]])
    -- Extend search to include next character
    feed('<C-L>')
    screen:expect([[
        9 {inc:thes}e           |
       10 foobar          |
      /thes^               |
    ]])
    -- Deleting all characters resets the cursor position
    feed('<BS><BS><BS><BS>')
    screen:expect([[
        1                 |
        2 these           |
      /^                   |
    ]])
    feed('the')
    screen:expect([[
        1                 |
        2 {inc:the}se           |
      /the^                |
    ]])
    feed('\\>')
    screen:expect([[
        2 these           |
        3 {inc:the}             |
      /the\>^              |
    ]])
  end)

  it('can traverse matches in the same line with <C-G>/<C-T>', function()
    funcs.setline(1, { '  1', '  2 these', '  3 the theother' })
    command('1')
    command('set incsearch')

    -- First match
    feed('/the')
    screen:expect([[
        1                 |
        2 {inc:the}se           |
      /the^                |
    ]])

    -- Next match, different line
    feed('<C-G>')
    screen:expect([[
        2 these           |
        3 {inc:the} theother    |
      /the^                |
    ]])

    -- Next match, same line
    feed('<C-G>')
    screen:expect([[
        2 these           |
        3 the {inc:the}other    |
      /the^                |
    ]])
    feed('<C-G>')
    screen:expect([[
        2 these           |
        3 the theo{inc:the}r    |
      /the^                |
    ]])

    -- Previous match, same line
    feed('<C-T>')
    screen:expect([[
        2 these           |
        3 the {inc:the}other    |
      /the^                |
    ]])
    feed('<C-T>')
    screen:expect([[
        2 these           |
        3 {inc:the} theother    |
      /the^                |
    ]])

    -- Previous match, different line
    feed('<C-T>')
    screen:expect([[
        2 {inc:the}se           |
        3 the theother    |
      /the^                |
    ]])
  end)

  it('keeps the view after deleting a char from the search', function()
    screen:detach()
    screen = Screen.new(20, 6)
    screen:attach()
    screen:set_default_attr_ids({
      inc = {reverse = true}
    })
    screen:set_default_attr_ignore({
      {bold=true, reverse=true}, {bold=true, foreground=Screen.colors.Blue1}
    })
    tenlines()

    feed('/foo')
    screen:expect([[
        6 their           |
        7 the             |
        8 them            |
        9 these           |
       10 {inc:foo}bar          |
      /foo^                |
    ]])
    feed('<BS>')
    screen:expect([[
        6 their           |
        7 the             |
        8 them            |
        9 these           |
       10 {inc:fo}obar          |
      /fo^                 |
    ]])
    feed('<CR>')
    screen:expect([[
        6 their           |
        7 the             |
        8 them            |
        9 these           |
       10 ^foobar          |
      /fo                 |
    ]])
    eq({lnum = 10, leftcol = 0, col = 4, topfill = 0, topline = 6,
        coladd = 0, skipcol = 0, curswant = 4},
       funcs.winsaveview())
  end)

  it('restores original view after failed search', function()
    screen:detach()
    screen = Screen.new(40, 3)
    screen:attach()
    screen:set_default_attr_ids({
      inc = {reverse = true},
      err = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      more = { bold = true, foreground = Screen.colors.SeaGreen4 },
    })
    tenlines()
    feed('0')
    feed('/foo')
    screen:expect([[
        9 these                               |
       10 {inc:foo}bar                              |
      /foo^                                    |
    ]])
    feed('<C-W>')
    screen:expect([[
        1                                     |
        2 these                               |
      /^                                       |
    ]])
    feed('<CR>')
    screen:expect([[
      /                                       |
      {err:E35: No previous regular expression}     |
      {more:Press ENTER or type command to continue}^ |
    ]])
    feed('<CR>')
    eq({lnum = 1, leftcol = 0, col = 0, topfill = 0, topline = 1,
        coladd = 0, skipcol = 0, curswant = 0},
       funcs.winsaveview())
  end)

  it("CTRL-G with 'incsearch' and ? goes in the right direction", function()
    -- oldtest: Test_search_cmdline4().
    screen:detach()
    screen = Screen.new(40, 4)
    screen:attach()
    screen:set_default_attr_ids({
      inc = {reverse = true},
      err = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      more = { bold = true, foreground = Screen.colors.SeaGreen4 },
      tilde = { bold = true, foreground = Screen.colors.Blue1 },
    })
    command('enew!')
    funcs.setline(1, {'  1 the first', '  2 the second', '  3 the third'})
    command('set laststatus=0 shortmess+=s')
    command('set incsearch')
    command('$')
    -- Send the input in chunks, so the cmdline logic regards it as
    -- "interactive".  This mimics Vim's test_override("char_avail").
    -- (See legacy test: test_search.vim)
    feed('?the')
    wait()
    feed('<c-g>')
    wait()
    feed('<cr>')
    screen:expect([[
        1 the first                           |
        2 the second                          |
        3 ^the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    wait()
    feed('<c-g>')
    wait()
    feed('<c-g>')
    wait()
    feed('<cr>')
    screen:expect([[
        1 ^the first                           |
        2 the second                          |
        3 the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    wait()
    feed('<c-g>')
    wait()
    feed('<c-g>')
    wait()
    feed('<c-g>')
    wait()
    feed('<cr>')
    screen:expect([[
        1 the first                           |
        2 ^the second                          |
        3 the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    wait()
    feed('<c-t>')
    wait()
    feed('<cr>')
    screen:expect([[
        1 ^the first                           |
        2 the second                          |
        3 the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    wait()
    feed('<c-t>')
    wait()
    feed('<c-t>')
    wait()
    feed('<cr>')
    screen:expect([[
        1 the first                           |
        2 the second                          |
        3 ^the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    wait()
    feed('<c-t>')
    wait()
    feed('<c-t>')
    wait()
    feed('<c-t>')
    wait()
    feed('<cr>')
    screen:expect([[
        1 the first                           |
        2 ^the second                          |
        3 the third                           |
      ?the                                    |
    ]])
  end)
end)
