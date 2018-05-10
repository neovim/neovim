local helpers = require('test.functional.helpers')(after_each)

local NIL = helpers.NIL
local clear = helpers.clear
local command = helpers.command
local curbufmeths = helpers.curbufmeths
local eq = helpers.eq
local expect_err = helpers.expect_err
local meths = helpers.meths
local source = helpers.source

describe('nvim_get_commands', function()
  local cmd_dict = {
    addr=NIL,
    complete=NIL,
    complete_arg=NIL,
    count=NIL,
    definition='echo "Hello World"',
    name='Hello',
    nargs='1',
    range=NIL,
    script_id=0,
  }
  local cmd_dict2 = {
    addr=NIL,
    complete=NIL,
    complete_arg=NIL,
    count=NIL,
    definition='pwd',
    name='Pwd',
    nargs='?',
    range=NIL,
    script_id=0,
  }
  before_each(clear)
  it('gets empty list if no commands were defined', function()
    eq({}, meths.get_commands({builtin=false}))
  end)
  it('validates input', function()
    expect_err('builtin commands not supported yet', meths.get_commands,
               {builtin=true})
    expect_err('unexpected key: foo', meths.get_commands,
               {foo='blah'})
  end)
  it('gets global user-defined commands', function()
    -- Define a command.
    command('command -nargs=1 Hello echo "Hello World"')
    eq({cmd_dict}, meths.get_commands({builtin=false}))
    -- Define another command.
    command('command -nargs=? Pwd pwd');
    eq({cmd_dict, cmd_dict2}, meths.get_commands({builtin=false}))
    -- Delete a command.
    command('delcommand Pwd')
    eq({cmd_dict}, meths.get_commands({builtin=false}))
  end)
  it('gets buffer-local user-defined commands', function()
    -- Define a buffer-local command.
    command('command -buffer -nargs=1 Hello echo "Hello World"')
    eq({cmd_dict}, curbufmeths.get_commands({builtin=false}))
    -- Define another buffer-local command.
    command('command -buffer -nargs=? Pwd pwd')
    eq({cmd_dict, cmd_dict2}, curbufmeths.get_commands({builtin=false}))
    -- Delete a command.
    command('delcommand Pwd')
    eq({cmd_dict}, curbufmeths.get_commands({builtin=false}))
  end)
  it('gets different attributes of different commands', function()
    local cmd1 = {
      addr=NIL,
      complete='custom',
      complete_arg='ListUsers',
      count=NIL,
      definition='!finger <args>',
      name='Finger',
      nargs='+',
      range=NIL,
      script_id=1,
    }
    local cmd2 = {
      addr='arguments',
      complete='dir',
      complete_arg=NIL,
      count='10',
      definition='pwd <args>',
      name='TestCmd',
      nargs='0',
      range='10',
      script_id=0,
    }
    source([[
      command -complete=custom,ListUsers -nargs=+ Finger !finger <args>
    ]])
    eq({cmd1}, meths.get_commands({builtin=false}))
    command('command -complete=dir -addr=arguments -count=10 TestCmd pwd <args>')
    eq({cmd1, cmd2}, meths.get_commands({builtin=false}))
  end)
end)
