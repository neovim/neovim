-- Tests for 'lispwords' setting being global-local

local helpers = require('test.functional.helpers')
local source = helpers.source
local clear, expect = helpers.clear, helpers.expect

describe('lispwords', function()
  setup(clear)

  it('global-local', function()
    source([[
      setglobal lispwords=foo,bar,baz
      setlocal lispwords-=foo 
      setlocal lispwords+=quux
      redir @A
        echo "Testing 'lispwords' local value" 
        setglobal lispwords? 
        setlocal lispwords? 
        echo &lispwords 
        echo ''
      redir end
      setlocal lispwords<
      redir @A
        echo "Testing 'lispwords' value reset" 
        setglobal lispwords? 
        setlocal lispwords? 
        echo &lispwords
      redir end

      0put a
      $d
    ]])

    -- Assert buffer contents.
    expect([[
      
      Testing 'lispwords' local value
        lispwords=foo,bar,baz
        lispwords=bar,baz,quux
      bar,baz,quux
      
      Testing 'lispwords' value reset
        lispwords=foo,bar,baz
        lispwords=foo,bar,baz
      foo,bar,baz]])
  end)
end)
