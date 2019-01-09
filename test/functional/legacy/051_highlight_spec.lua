-- Tests for ":highlight".

local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local clear, feed = helpers.clear, helpers.feed
local expect = helpers.expect
local eq = helpers.eq
local wait = helpers.wait
local exc_exec = helpers.exc_exec
local feed_command = helpers.feed_command

describe(':highlight', function()
  setup(clear)

  it('is working', function()
    local screen = Screen.new(35, 10)
    screen:attach()
    -- Basic test if ":highlight" doesn't crash
    feed_command('set more')
    feed(':highlight<CR>')
    -- FIXME(tarruda): We need to be sure the prompt is displayed before
    -- continuing, or risk a race condition where some of the following input
    -- is discarded resulting in test failure
    screen:expect([[
      :highlight                         |
      SpecialKey     xxx ctermfg=4       |
                         guifg=Blue      |
      EndOfBuffer    xxx links to NonText|
                                         |
      TermCursor     xxx cterm=reverse   |
                         gui=reverse     |
      TermCursorNC   xxx cleared         |
      NonText        xxx ctermfg=12      |
      -- More --^                         |
    ]])
    feed('q')
    wait() -- wait until we're back to normal
    feed_command('hi Search')
    feed_command('hi Normal')

    -- Test setting colors.
    -- Test clearing one color and all doesn't generate error or warning
    feed_command('hi NewGroup cterm=italic ctermfg=DarkBlue ctermbg=Grey gui=NONE guifg=#00ff00 guibg=Cyan')
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
    eq('Vim(highlight):E475: Invalid argument: cterm=\'asdf',
       exc_exec([[hi Crash cterm='asdf]]))
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
