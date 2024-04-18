-- Test for visual mode not being reset causing E315 error.

local t = require('test.functional.testutil')()
local feed, source = t.feed, t.source
local clear, expect = t.clear, t.expect

describe('E315 error', function()
  setup(clear)

  it('is working', function()
    -- At this point there is no visual selection because :call reset it.
    -- Let's restore the selection:
    source([[
      let g:msg="Everything's fine."
      function! TriggerTheProblem()
          normal gv
          '<,'>del _
          try
              exe "normal \<Esc>"
          catch /^Vim\%((\a\+)\)\=:E315/
              echom 'Snap! E315 error!'
              let g:msg='Snap! E315 error!'
          endtry
      endfunction
      enew
      enew
      setl buftype=nofile
      call append(line('$'), 'Delete this line.')
    ]])

    -- NOTE: this has to be done by a call to a function because executing
    -- :del the ex-way will require the colon operator which resets the
    -- visual mode thus preventing the problem:
    feed('GV:call TriggerTheProblem()<cr>')

    source([[
      %del _
      call append(line('$'), g:msg)
      brewind
    ]])

    -- Assert buffer contents.
    expect([[

      Everything's fine.]])
  end)
end)
