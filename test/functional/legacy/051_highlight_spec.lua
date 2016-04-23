-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Tests for ":highlight".

local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local clear, feed = helpers.clear, helpers.feed
local execute, expect = helpers.execute, helpers.expect
local wait = helpers.wait

describe(':highlight', function()
  setup(clear)

  it('is working', function()
    local screen = Screen.new(35, 10)
    screen:attach()
    -- Basic test if ":highlight" doesn't crash
    execute('highlight')
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
    execute('hi Search')

    -- Test setting colors.
    -- Test clearing one color and all doesn't generate error or warning
    execute('hi NewGroup cterm=italic ctermfg=DarkBlue ctermbg=Grey gui=NONE guifg=#00ff00 guibg=Cyan')
    execute('hi Group2 cterm=NONE')
    execute('hi Group3 cterm=bold')
    execute('redir! @a')
    execute('hi NewGroup')
    execute('hi Group2')
    execute('hi Group3')
    execute('hi clear NewGroup')
    execute('hi NewGroup')
    execute('hi Group2')
    execute('hi Group2 NONE')
    execute('hi Group2')
    execute('hi clear')
    execute('hi Group3')
    execute([[hi Crash cterm='asdf]])
    execute('redir END')

    -- Filter ctermfg and ctermbg, the numbers depend on the terminal
    execute('0put a')
    execute([[%s/ctermfg=\d*/ctermfg=2/]])
    execute([[%s/ctermbg=\d*/ctermbg=3/]])

    -- Filter out possibly translated error message
    execute('%s/E475: [^:]*:/E475:/')

    -- Fix the fileformat
    execute('set ff&')
    execute('$d')

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
      
      
      Group3         xxx cleared
      
      E475: cterm='asdf]])
    screen:detach()
  end)
end)
