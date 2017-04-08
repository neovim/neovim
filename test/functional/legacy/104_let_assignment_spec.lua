-- Tests for :let.

local helpers = require('test.functional.helpers')(after_each)
local clear, source = helpers.clear, helpers.source
local command, expect = helpers.command, helpers.expect

describe(':let', function()
  setup(clear)

  it('is working', function()
    command('set runtimepath+=test/functional/fixtures')

    -- Test to not autoload when assigning.  It causes internal error.
    source([[
      try
        let Test104#numvar = function('tr')
        $put ='OK: ' . string(Test104#numvar)
      catch
        $put ='FAIL: ' . v:exception
      endtry
      let a = 1
      let b = 2
      for letargs in ['a b', '{0 == 1 ? "a" : "b"}', '{0 == 1 ? "a" : "b"} a', 'a {0 == 1 ? "a" : "b"}']
        try
          redir => messages
          execute 'let' letargs
          redir END
          $put ='OK:'
          $put =split(substitute(messages, '\n', '\0  ', 'g'), '\n')
        catch
          $put ='FAIL: ' . v:exception
          redir END
        endtry
      endfor]])

    -- Remove empty line
    command('1d')

    -- Assert buffer contents.
    expect([[
      OK: function('tr')
      OK:
        a                     #1
        b                     #2
      OK:
        b                     #2
      OK:
        b                     #2
        a                     #1
      OK:
        a                     #1
        b                     #2]])
  end)
end)
