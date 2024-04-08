-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Test for script-local function.

local t = require('test.functional.testutil')(after_each)
local clear, feed, insert = t.clear, t.feed, t.insert
local expect = t.expect

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
