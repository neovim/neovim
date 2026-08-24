local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local api = n.api
local clear = n.clear
local eq = t.eq
local exec_capture = n.exec_capture

describe(':delete', function()
  before_each(clear)

  it('reports all deleted lines when it empties the buffer #41306', function()
    api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three', 'four' })
    eq('4 fewer lines', exec_capture('1,$delete'))
  end)
end)
