local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local luaeval = helpers.funcs.luaeval
-- local neq = helpers.neq
-- local dedent = helpers.dedent
-- local source = helpers.source

before_each(clear)

describe('Setup and Configuration', function()
  it('should allow you to add clients and commands', function()
    local expected_command =  'cool vim server'
    luaeval(
      "require('lsp.plugin').client.add('vim',"
      .. "{name = 'cool vim server', command = '"..expected_command.."',"
      .. "arguments = 'args'})"
    )

    local result_configuration =
      luaeval("require('lsp.plugin').client.get_configuration('vim')")

    eq(expected_command, result_configuration.command)
  end)
end)
