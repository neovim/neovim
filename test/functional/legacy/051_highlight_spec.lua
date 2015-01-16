-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Tests for ":highlight".

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe(':highlight', function()
  setup(clear)

  it('is working', function()
    -- Basic test if ":highlight" doesn't crash
    execute('highlight')
    execute('hi Search')

    -- Test setting colors.
    -- Test clearing one color and all doesn't generate error or warning
    execute('hi NewGroup term=bold cterm=italic ctermfg=DarkBlue ctermbg=Grey gui= guifg=#00ff00 guibg=Cyan')
    execute('hi Group2 term= cterm=')
    execute('hi Group3 term=underline cterm=bold')
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
    execute([[hi Crash term='asdf]])
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
      
      
      NewGroup       xxx term=bold cterm=italic ctermfg=2 ctermbg=3
      
      Group2         xxx cleared
      
      Group3         xxx term=underline cterm=bold
      
      
      NewGroup       xxx cleared
      
      Group2         xxx cleared
      
      
      Group2         xxx cleared
      
      
      Group3         xxx cleared
      
      E475: term='asdf]])
  end)
end)
