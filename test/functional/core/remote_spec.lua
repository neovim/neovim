local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local neq = helpers.neq
local funcs = helpers.funcs
local nvim_prog_abs = helpers.nvim_prog_abs
local merge_args = helpers.merge_args
local spawn = helpers.spawn
local set_session = helpers.set_session
local expect = helpers.expect

describe("remote --server client", function()
  local server, client, address, pid
  before_each(function()
    local nvim_argv = merge_args(helpers.nvim_argv, {'--headless'})
    server = spawn(nvim_argv)
    set_session(server)
    address = funcs.serverlist()[1]
    pid = funcs.getpid()

    client = spawn(nvim_argv)
    set_session(client, true)
    neq(funcs.getpid(), pid)
  end)

  it('--remote-expr', function()
    eq(pid..'\r\n',
       funcs.system({nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE',
                    '--server', address, '--remote-expr', 'getpid()'}))
  end)

  it('--remote-lua', function()
    eq('{ "a", "", "b" }\r\n',
       funcs.system({nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE',
                     '--server', address, '--remote-lua', 'vim.split("a::b", ":")'}))

    eq('3\r\n',
       funcs.system({nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE',
                     '--server', address, '--remote-lua', 'return 3'}))

    eq("[string \"remote\"]:1: '=' expected near 'error'\r\n",
       funcs.system({nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE',
                     '--server', address, '--remote-lua', 'syntax error'}))
  end)

  it('--remote-send', function()
    eq('',
       funcs.system({nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE',
                    '--server', address, '--remote-send', 'iwords'}))
    set_session(server)
    expect([[words]])
    eq('i', funcs.mode())
  end)

  it('error handling', function()
    -- TODO: wrong address
    -- invalid subcommand
  end)

end)
