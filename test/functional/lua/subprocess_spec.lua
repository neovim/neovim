local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq

local function subprocess(spec)
  return exec_lua([[
    test_stdout = nil

    vim.subprocess(
      ...,
      function(code, signal, stdout)
        test_stdout = stdout
      end
    )

    vim.wait(1000, function()
      return test_stdout ~= nil
    end, 10)

    return test_stdout
  ]], spec)
end

describe('subprocess', function()
  before_each(function()
    clear()
  end)

  it('can run simple commands', function()
    eq('hello\n',
      subprocess { command = 'echo', args = {'hello'} })

    eq('hello\n',
      subprocess('echo hello'))
  end)

  it('handle input', function()
    eq('hellocat',
      subprocess {
        command = 'cat',
        input = 'hellocat'
      })

    eq('hello\ncat\n',
      subprocess {
        command = 'cat',
        input = {'hello', 'cat'}
      })
  end)
end)
