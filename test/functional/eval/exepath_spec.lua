local helpers = require('test.functional.helpers')(after_each)
local eq, clear, call, iswin =
  helpers.eq, helpers.clear, helpers.call, helpers.iswin
local command = helpers.command
local exc_exec = helpers.exc_exec

describe('exepath()', function()
  before_each(clear)

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
