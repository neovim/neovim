local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local clear = n.clear
local command = n.command

describe('env', function()
  before_each(function()
    clear()
  end)

  it('vim.uv.os_setenv(), vim.uv.os_unsetenv() consistency #32550', function()
    eq('', n.eval('$FOO'))
    command('lua vim.uv.os_setenv("FOO", "bar")')
    eq('bar', n.eval('$FOO'))
    command('lua vim.uv.os_setenv("FOO", "fizz")')
    eq('fizz', n.eval('$FOO'))
    command('lua vim.uv.os_unsetenv("FOO")')
    eq('', n.eval('$FOO'))
    command('lua vim.uv.os_setenv("FOO", "buzz")')
    eq('buzz', n.eval('$FOO'))
  end)
end)
