-- Test that groups and patterns are tested correctly when calling exists() for
-- autocommands.

local n = require('test.functional.testnvim')()

local clear = n.clear
local command, expect = n.command, n.expect

describe('augroup when calling exists()', function()
  setup(clear)

  it('is working', function()
    command('let results=[]')
    command('call add(results, "##BufEnter: " . exists("##BufEnter"))')
    command('call add(results, "#BufEnter: " . exists("#BufEnter"))')
    command('au BufEnter * let g:entered=1')
    command('call add(results, "#BufEnter: " . exists("#BufEnter"))')
    command('call add(results, "#auexists#BufEnter: " . exists("#auexists#BufEnter"))')
    command('augroup auexists')
    command('au BufEnter * let g:entered=1')
    command('augroup END')
    command('call add(results, "#auexists#BufEnter: " . exists("#auexists#BufEnter"))')
    command('call add(results, "#BufEnter#*.test: " . exists("#BufEnter#*.test"))')
    command('au BufEnter *.test let g:entered=1')
    command('call add(results, "#BufEnter#*.test: " . exists("#BufEnter#*.test"))')
    command('edit testfile.test')
    command('call add(results, "#BufEnter#<buffer>: " . exists("#BufEnter#<buffer>"))')
    command('au BufEnter <buffer> let g:entered=1')
    command('call add(results, "#BufEnter#<buffer>: " . exists("#BufEnter#<buffer>"))')
    command('edit testfile2.test')
    command('call add(results, "#BufEnter#<buffer>: " . exists("#BufEnter#<buffer>"))')
    command('bf')
    command('call append(0, results)')
    command('$d')

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
