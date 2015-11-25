-- Test that groups and patterns are tested correctly when calling exists() for
-- autocommands.

local helpers = require('test.functional.helpers')
local clear = helpers.clear
local execute, expect = helpers.execute, helpers.expect

describe('augroup when calling exists()', function()
  setup(clear)

  it('is working', function()
    execute('let results=[]')
    execute('call add(results, "##BufEnter: " . exists("##BufEnter"))')
    execute('call add(results, "#BufEnter: " . exists("#BufEnter"))')
    execute('au BufEnter * let g:entered=1')
    execute('call add(results, "#BufEnter: " . exists("#BufEnter"))')
    execute('call add(results, "#auexists#BufEnter: " . exists("#auexists#BufEnter"))')
    execute('augroup auexists', 'au BufEnter * let g:entered=1', 'augroup END')
    execute('call add(results, "#auexists#BufEnter: " . exists("#auexists#BufEnter"))')
    execute('call add(results, "#BufEnter#*.test: " . exists("#BufEnter#*.test"))')
    execute('au BufEnter *.test let g:entered=1')
    execute('call add(results, "#BufEnter#*.test: " . exists("#BufEnter#*.test"))')
    execute('edit testfile.test')
    execute('call add(results, "#BufEnter#<buffer>: " . exists("#BufEnter#<buffer>"))')
    execute('au BufEnter <buffer> let g:entered=1')
    execute('call add(results, "#BufEnter#<buffer>: " . exists("#BufEnter#<buffer>"))')
    execute('edit testfile2.test')
    execute('call add(results, "#BufEnter#<buffer>: " . exists("#BufEnter#<buffer>"))')
    execute('bf')
    execute('call append(0, results)')
    execute('$d')

    -- Assert buffer contents.
    expect([[
      ##BufEnter: 1
      #BufEnter: 0
      #BufEnter: 1
      #auexists#BufEnter: 0
      #auexists#BufEnter: 1
      #BufEnter#*.test: 0
      #BufEnter#*.test: 1
      #BufEnter#<buffer>: 0
      #BufEnter#<buffer>: 1
      #BufEnter#<buffer>: 0]])
  end)
end)
