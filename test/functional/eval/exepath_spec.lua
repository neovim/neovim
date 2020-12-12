local helpers = require('test.functional.helpers')(after_each)
local eq, clear, call, iswin =
  helpers.eq, helpers.clear, helpers.call, helpers.iswin
local command = helpers.command
local exc_exec = helpers.exc_exec
local matches = helpers.matches

describe('exepath()', function()
  before_each(clear)

  it('returns 1 for commands in $PATH', function()
    local exe = iswin() and 'ping' or 'ls'
    local ext_pat = iswin() and '%.EXE$' or '$'
    matches(exe .. ext_pat, call('exepath', exe))
    command('let $PATH = fnamemodify("./test/functional/fixtures/bin", ":p")')
    ext_pat = iswin() and '%.CMD$' or '$'
    matches('null' .. ext_pat, call('exepath', 'null'))
    matches('true' .. ext_pat, call('exepath', 'true'))
    matches('false' .. ext_pat, call('exepath', 'false'))
  end)

  it('fails for invalid values', function()
    for _, input in ipairs({'""', 'v:null', 'v:true', 'v:false', '{}', '[]'}) do
      eq('Vim(call):E928: String required', exc_exec('call exepath('..input..')'))
    end
    command('let $PATH = fnamemodify("./test/functional/fixtures/bin", ":p")')
    for _, input in ipairs({'v:null', 'v:true', 'v:false'}) do
      eq('Vim(call):E928: String required', exc_exec('call exepath('..input..')'))
    end
  end)

  if iswin() then
    it('append extension if omitted', function()
      local filename = 'cmd'
      local pathext = '.exe'
      clear({env={PATHEXT=pathext}})
      eq(call('exepath', filename..pathext), call('exepath', filename))
    end)
  end
end)
