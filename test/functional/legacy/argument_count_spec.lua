-- Tests for :[count]argument! and :[count]argdelete

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('argument_count', function()
  setup(clear)

  it('is working', function()
    execute('%argd')
    execute('argadd a b c d')
    execute('set hidden')
    execute('let buffers = []')
    execute('augroup TEST')
    execute([[au BufEnter * call add(buffers, expand('%:t'))]])
    execute('augroup END')
    execute('$argu')
    execute('$-argu')
    execute('-argu')
    execute('1argu')
    execute('+2argu')
    execute('augroup TEST')
    execute('au!')
    execute('augroup END')
    execute('let arglists = []')
    execute('.argd')
    execute('call add(arglists, argv())')
    execute('-argd')
    execute('call add(arglists, argv())')
    execute('$argd')
    execute('call add(arglists, argv())')
    execute('1arga c')
    execute('1arga b')
    execute('$argu')
    execute('$arga x')
    execute('call add(arglists, argv())')
    execute('0arga Y')
    execute('call add(arglists, argv())')
    execute('%argd')
    execute('call add(arglists, argv())')
    execute('arga a b c d e f')
    execute('2,$-argd')
    execute('call add(arglists, argv())')
    execute('call append(0, buffers)')
    execute([[let lnr = line('$')]])
    execute([[call append(lnr, map(copy(arglists), 'join(v:val, " ")'))]])
    -- Assert buffer contents.
    expect([=[
      d
      c
      b
      a
      c
      
      a b d
      a d
      a
      a b c x
      Y a b c x
      
      a f]=])
  end)
end)
