-- Tests for 'listchars' display with 'list' and :list.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe("'listchars'", function()
  before_each(function()
    clear()
    execute('set listchars&vi')
  end)

  it("works with 'list'", function()
    source([[
      function GetScreenCharsForLine(lnum)
        return join(map(range(1, virtcol('$')), 'nr2char(screenchar(a:lnum, v:val))'), '')
      endfunction
      nnoremap <expr> GG ":call add(g:lines, GetScreenCharsForLine(".screenrow()."))\<CR>"
    ]])

    insert([[
      start:
      	aa	
        bb	  
         cccc	 
      dd        ee  	
       ]])

    execute('let g:lines = []')

    -- Set up 'listchars', switch on 'list', and use the "GG" mapping to record
    -- what the buffer lines look like.
    execute('set listchars+=tab:>-,space:.,trail:<')
    execute('set list')
    execute('/^start:/')
    execute('normal! jzt')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GGH')

    -- Repeat without displaying "trail" spaces.
    execute('set listchars-=trail:<')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG')

    -- Delete the buffer contents and :put the collected lines.
    execute('%d')
    execute('put =g:lines', '1d')

    -- Assert buffer contents.
    expect([[
      >-------aa>-----$
      ..bb>---<<$
      ...cccc><$
      dd........ee<<>-$
      <$
      >-------aa>-----$
      ..bb>---..$
      ...cccc>.$
      dd........ee..>-$
      .$]])
  end)

  it('works with :list', function()
    insert([[
      start:
        fff	  
      	gg	
           h	
      iii    	  ]])

    -- Set up 'listchars', switch 'list' *off* (:list must show the 'listchars'
    -- even when 'list' is off), then run :list and collect the output.
    execute('set listchars+=tab:>-,space:.,trail:<')
    execute('set nolist')
    execute('/^start:/')
    execute('redir! => g:lines')
    execute('+1,$list')
    execute('redir END')

    -- Delete the buffer contents and :put the collected lines.
    execute('%d')
    execute('put =g:lines', '1d')

    -- Assert buffer contents.
    expect([[
      
      
      ..fff>--<<$
      >-------gg>-----$
      .....h>-$
      iii<<<<><<$]])
  end)
end)
