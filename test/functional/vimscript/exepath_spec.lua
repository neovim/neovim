local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, clear, call = t.eq, n.clear, n.call
local command = n.command
local exc_exec = n.exc_exec
local matches = t.matches
local is_os = t.is_os
local set_shell_powershell = n.set_shell_powershell
local eval = n.eval

local find_dummies = function(ext_pat)
  local tmp_path = eval('$PATH')
  command('let $PATH = fnamemodify("./test/functional/fixtures/bin", ":p")')
  matches('null' .. ext_pat, call('exepath', 'null'))
  matches('true' .. ext_pat, call('exepath', 'true'))
  matches('false' .. ext_pat, call('exepath', 'false'))
  command("let $PATH = '" .. tmp_path .. "'")
end

describe('exepath()', function()
  before_each(clear)

  it('fails for invalid values', function()
    for _, input in ipairs({ 'v:null', 'v:true', 'v:false', '{}', '[]' }) do
      eq(
        'Vim(call):E1174: String required for argument 1',
        exc_exec('call exepath(' .. input .. ')')
      )
    end
    eq('Vim(call):E1175: Non-empty string required for argument 1', exc_exec('call exepath("")'))
    command('let $PATH = fnamemodify("./test/functional/fixtures/bin", ":p")')
    for _, input in ipairs({ 'v:null', 'v:true', 'v:false' }) do
      eq(
        'Vim(call):E1174: String required for argument 1',
        exc_exec('call exepath(' .. input .. ')')
      )
    end
  end)

  if is_os('win') then
    it('returns 1 for commands in $PATH (Windows)', function()
      local exe = 'ping'
      matches(exe .. '%.EXE$', call('exepath', exe))
    end)

    it('append extension if omitted', function()
      local filename = 'cmd'
      local pathext = '.exe'
      clear({ env = { PATHEXT = pathext } })
      eq(call('exepath', filename .. pathext), call('exepath', filename))
    end)

    it(
      'returns file WITH extension if files both with and without extension exist in $PATH',
      function()
        local ext_pat = '%.CMD$'
        find_dummies(ext_pat)
        set_shell_powershell()
        find_dummies(ext_pat)
      end
    )
  else
    it('returns 1 for commands in $PATH (not Windows)', function()
      local exe = 'ls'
      matches(exe .. '$', call('exepath', exe))
    end)

    it(
      'returns file WITHOUT extension if files both with and without extension exist in $PATH',
      function()
        find_dummies('$')
      end
    )
  end
end)
