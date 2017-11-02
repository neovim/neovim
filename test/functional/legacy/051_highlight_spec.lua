-- Tests for ":highlight".

local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local clear, feed = helpers.clear, helpers.feed
local command, expect = helpers.command, helpers.expect
local eq = helpers.eq
local wait = helpers.wait
local exc_exec = helpers.exc_exec

describe(':highlight', function()
  setup(clear)

  it('is working', function()
    local screen = Screen.new(35, 10)
    screen:attach()
    -- Basic test if ":highlight" doesn't crash
    command('set more')
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
    command('hi Search')
    command('hi Normal')

    -- Test setting colors.
    -- Test clearing one color and all doesn't generate error or warning
    command('hi NewGroup cterm=italic ctermfg=DarkBlue ctermbg=Grey gui=NONE guifg=#00ff00 guibg=Cyan')
    command('hi Group2 cterm=NONE')
    command('hi Group3 cterm=bold')
    command('redir! @a')
    command('hi NewGroup')
    command('hi Group2')
    command('hi Group3')
    command('hi clear NewGroup')
    command('hi NewGroup')
    command('hi Group2')
    command('hi Group2 NONE')
    command('hi Group2')
    command('hi clear')
    command('hi Group3')
    eq('Vim(highlight):E475: Invalid argument: cterm=\'asdf',
       exc_exec([[hi Crash cterm='asdf]]))
    command('redir END')

    -- Filter ctermfg and ctermbg, the numbers depend on the terminal
    command('0put a')
    command([[%s/ctermfg=\d*/ctermfg=2/]])
    command([[%s/ctermbg=\d*/ctermbg=3/]])

    -- Fix the fileformat
    command('set ff&')
    command('$d')

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
    screen:detach()
  end)
end)
