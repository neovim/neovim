local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local funcs = helpers.funcs

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
      feed('<C-N>')
      screen:expect([[
          2 these           |
          3 {inc:the}             |
        /the^                |
      ]])
      feed('<C-N>')
      screen:expect([[
          3 the             |
          4 {inc:the}ir           |
        /the^                |
      ]])
      feed('<C-N>')
      screen:expect([[
          4 their           |
          5 {inc:the}re           |
        /the^                |
      ]])
      feed('<C-N>')
      screen:expect([[
          5 there           |
          6 {inc:the}ir           |
        /the^                |
      ]])
      feed('<C-N>')
      screen:expect([[
          6 their           |
          7 {inc:the}             |
        /the^                |
      ]])
      feed('<C-N>')
      screen:expect([[
          7 the             |
          8 {inc:the}m            |
        /the^                |
      ]])
      feed('<C-N>')
      screen:expect([[
          8 them            |
          9 {inc:the}se           |
        /the^                |
      ]])
      feed('<C-N>')
      if wrapscan == 'wrapscan' then
        screen:expect([[
            2 {inc:the}se           |
            3 the             |
          /the^                |
        ]])
      else
        screen:expect([[
            8 them            |
            9 {inc:the}se           |
          /the^                |
        ]])
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
      if wrapscan == 'wrapscan' then
        feed('<C-N>')
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
        feed('<C-N>')
        screen:expect([[
            9 {inc:the}se           |
           10 foobar          |
          ?the^                |
        ]])
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
      feed('<C-P>')
      screen:expect([[
          8 {inc:the}m            |
          9 these           |
        ?the^                |
      ]])
      for i = 1, 6 do
        feed('<C-P>')
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
      feed('<C-P>')
      if wrapscan == 'wrapscan' then
        screen:expect([[
            9 {inc:the}se           |
           10 foobar          |
          ?the^                |
        ]])
      else
        screen:expect([[
            2 {inc:the}se           |
            3 the             |
          ?the^                |
        ]])
      end
    end

    it("using <C-N> and 'nowrapscan'", function()
      forwarditer('nowrapscan')
    end)

    it("using <C-N> and 'wrapscan'", function()
      forwarditer('wrapscan')
    end)

    it("using <C-P> and 'nowrapscan'", function()
      backiter('nowrapscan')
    end)

    it("using <C-P> and 'wrapscan'", function()
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
    feed('<C-N>')
    screen:expect([[
        9 {inc:thes}e           |
       10 foobar          |
      /thes^               |
    ]])
    feed('<C-N>')
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
    feed('<C-N>')
    screen:expect([[
        9 {inc:thes}e           |
       10 foobar          |
      /thes^               |
    ]])
    feed('<C-N><CR>')
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
    -- Stay on this match when deleting a character
    feed('<BS>')
    screen:expect([[
        4 {inc:the}ir           |
        5 there           |
      /the^                |
    ]])
    -- New text advances to next match
    feed('s')
    screen:expect([[
        9 {inc:thes}e           |
       10 foobar          |
      /thes^               |
    ]])
    -- Stay on this match when deleting a character
    feed('<BS>')
    screen:expect([[
        9 {inc:the}se           |
       10 foobar          |
      /the^                |
    ]])
    -- Advance to previous match
    feed('<C-P>')
    screen:expect([[
        8 {inc:the}m            |
        9 these           |
      /the^                |
    ]])
    -- Extend search to include next character
    feed('<C-L>')
    screen:expect([[
        8 {inc:them}            |
        9 these           |
      /them^               |
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
        2 {inc:the}se           |
        3 the             |
      /the^                |
    ]])
    feed('\\>')
    screen:expect([[
        3 {inc:the}             |
        4 their           |
      /the\>^              |
    ]])
  end)

  it('can traverse matches in the same line with <C-N>/<C-P>', function()
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
    feed('<C-N>')
    screen:expect([[
        2 these           |
        3 {inc:the} theother    |
      /the^                |
    ]])

    -- Next match, same line
    feed('<C-N>')
    screen:expect([[
        2 these           |
        3 the {inc:the}other    |
      /the^                |
    ]])
    feed('<C-N>')
    screen:expect([[
        2 these           |
        3 the theo{inc:the}r    |
      /the^                |
    ]])

    -- Previous match, same line
    feed('<C-P>')
    screen:expect([[
        2 these           |
        3 the {inc:the}other    |
      /the^                |
    ]])
    feed('<C-P>')
    screen:expect([[
        2 these           |
        3 {inc:the} theother    |
      /the^                |
    ]])

    -- Previous match, different line
    feed('<C-P>')
    screen:expect([[
        2 {inc:the}se           |
        3 the theother    |
      /the^                |
    ]])
  end)
end)
