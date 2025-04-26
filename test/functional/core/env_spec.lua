local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local clear = n.clear
local exec_capture = n.exec_capture
local command = n.command

describe('vim.uv', function()
  before_each(function()
    clear()
  end)

  -- Subsequential env var assignment consistency
  -- see: issue 32550
  it('vim.uv.os_setenv(), vim.uv.os_unsetenv() consistency', function()
    eq('', exec_capture('echo $FOO'))
    command('lua vim.uv.os_setenv("FOO", "bar")')
    eq('bar', exec_capture('echo $FOO'))
    command('lua vim.uv.os_setenv("FOO", "fizz")')
    eq('fizz', exec_capture('echo $FOO'))
    command('lua vim.uv.os_unsetenv("FOO")')
    eq('', exec_capture('echo $FOO'))
    command('lua vim.uv.os_setenv("FOO", "buzz")')
    eq('buzz', exec_capture('echo $FOO'))
  end)
end)
