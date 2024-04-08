-- Tests for quickfix window's title

local t = require('test.functional.testutil')(after_each)
local insert, source = t.insert, t.source
local clear, expect = t.clear, t.expect

describe('qf_title', function()
  setup(clear)

  it('is working', function()
    insert([[
      Results of test_qf_title:]])

    source([[
      set efm=%E%f:%l:%c:%m
      cgetexpr ['file:1:1:message']
      let qflist=getqflist()
      call setqflist(qflist, 'r')
      copen
      let g:quickfix_title=w:quickfix_title
      wincmd p
      $put =g:quickfix_title
    ]])

    -- Assert buffer contents.
    expect([[
      Results of test_qf_title:
      :setqflist()]])
  end)
end)
