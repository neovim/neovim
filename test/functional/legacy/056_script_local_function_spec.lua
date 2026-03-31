-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Test for script-local function.

local n = require('test.functional.testnvim')()

local clear, feed, insert = n.clear, n.feed, n.insert
local expect = n.expect

describe('source function', function()
  setup(clear)

  it('is working', function()
    insert([[
      fun DoLast()
        call append(line('$'), "last line")
      endfun
      fun DoNothing()
        call append(line('$'), "nothing line")
      endfun
      nnoremap <buffer> _x :call DoNothing()<bar>call DoLast()<cr>]])

    feed(':<C-R>=getline(1,3)<cr><cr>')
    feed(':<C-R>=getline(4,6)<cr><cr>')
    feed(':<C-R>=getline(7)<cr><cr>')
    feed('ggdG')
    feed('_xggdd')

    expect([[
      nothing line
      last line]])
  end)
end)
