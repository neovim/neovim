local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed = n.clear, n.feed
local expect = n.expect
local eq = t.eq
local poke_eventloop = n.poke_eventloop
local exc_exec = n.exc_exec
local feed_command = n.feed_command
local exec = n.exec

before_each(clear)

describe(':highlight', function()
  it('is working', function()
    local screen = Screen.new(35, 10)
    -- Basic test if ":highlight" doesn't crash
    feed_command('set more')
    feed(':highlight<CR>')
    -- FIXME(tarruda): We need to be sure the prompt is displayed before
    -- continuing, or risk a race condition where some of the following input
    -- is discarded resulting in test failure
    screen:expect([[
      :highlight                         |
      SpecialKey     {18:xxx} {18:ctermfg=}4       |
                         {18:guifg=}Blue      |
      EndOfBuffer    {1:xxx} {18:links to} NonText|
                                         |
      TermCursor     {2:xxx} {18:cterm=}reverse   |
                         {18:gui=}reverse     |
      TermCursorNC   xxx cleared         |
      NonText        {1:xxx} {18:ctermfg=}12      |
      {6:-- More --}^                         |
    ]])
    feed('q')
    poke_eventloop() -- wait until we're back to normal
    feed_command('hi Search')
    feed_command('hi Normal')

    -- Test setting colors.
    -- Test clearing one color and all doesn't generate error or warning
    feed_command(
      'hi NewGroup cterm=italic ctermfg=DarkBlue ctermbg=Grey gui=NONE guifg=#00ff00 guibg=Cyan'
    )
    feed_command('hi Group2 cterm=NONE')
    feed_command('hi Group3 cterm=bold')
    feed_command('redir! @a')
    feed_command('hi NewGroup')
    feed_command('hi Group2')
    feed_command('hi Group3')
    feed_command('hi clear NewGroup')
    feed_command('hi NewGroup')
    feed_command('hi Group2')
    feed_command('hi Group2 NONE')
    feed_command('hi Group2')
    feed_command('hi clear')
    feed_command('hi Group3')
    feed('<cr>')
    eq("Vim(highlight):E475: Invalid argument: cterm='asdf", exc_exec([[hi Crash cterm='asdf]]))
    feed_command('redir END')

    -- Filter ctermfg and ctermbg, the numbers depend on the terminal
    feed_command('0put a')
    feed_command([[%s/ctermfg=\d*/ctermfg=2/]])
    feed_command([[%s/ctermbg=\d*/ctermbg=3/]])

    -- Fix the fileformat
    feed_command('set ff&')
    feed_command('$d')

    -- Assert buffer contents.
    expect([[


      NewGroup       xxx cterm=italic
                         ctermfg=2
                         ctermbg=3
                         guifg=#00ff00
                         guibg=Cyan

      Group2         xxx cleared

      Group3         xxx cterm=bold


      NewGroup       xxx cleared

      Group2         xxx cleared


      Group2         xxx cleared


      Group3         xxx cleared]])
  end)
end)

describe('Visual selection highlight', function()
  -- oldtest: Test_visual_sbr()
  it("when 'showbreak' is set", function()
    local screen = Screen.new(60, 6)
    exec([[
      set showbreak=>
      call setline(1, 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.')
      exe "normal! z1\<CR>"
    ]])
    feed('v$')
    screen:expect([[
      {1:>}{17:n, no sea takimata sanctus est Lorem ipsum dolor sit amet.}^ |
                                                                  |*4
      {5:-- VISUAL --}                                                |
    ]])
  end)
end)
