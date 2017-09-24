-- Tests for 'listchars' display with 'list' and :list.

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, feed_command, expect = helpers.clear, helpers.feed_command, helpers.expect

-- luacheck: ignore 621 (Indentation)
describe("'listchars'", function()
  before_each(function()
    clear()
    feed_command('set listchars&vi')
  end)

  -- luacheck: ignore 613 (Trailing whitespace in a string)
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

    feed_command('let g:lines = []')

    -- Set up 'listchars', switch on 'list', and use the "GG" mapping to record
    -- what the buffer lines look like.
    feed_command('set listchars+=tab:>-,space:.,trail:<')
    feed_command('set list')
    feed_command('/^start:/')
    feed_command('normal! jzt')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GGH')

    -- Repeat without displaying "trail" spaces.
    feed_command('set listchars-=trail:<')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG')

    -- Delete the buffer contents and :put the collected lines.
    feed_command('%d')
    feed_command('put =g:lines', '1d')

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
    feed_command('set listchars+=tab:>-,space:.,trail:<')
    feed_command('set nolist')
    feed_command('/^start:/')
    feed_command('redir! => g:lines')
    feed_command('+1,$list')
    feed_command('redir END')

    -- Delete the buffer contents and :put the collected lines.
    feed_command('%d')
    feed_command('put =g:lines', '1d')

    -- Assert buffer contents.
    expect([[


      ..fff>--<<$
      >-------gg>-----$
      .....h>-$
      iii<<<<><<$]])
  end)
end)
