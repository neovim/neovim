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
  local cmd_dict  = { addr=NIL, bang=false, bar=false, complete=NIL, complete_arg=NIL, count=NIL, definition='echo "Hello World"', name='Hello', nargs='1', range=NIL, register=false, script_id=0, }
  local cmd_dict2 = { addr=NIL, bang=false, bar=false, complete=NIL, complete_arg=NIL, count=NIL, definition='pwd',                name='Pwd',   nargs='?', range=NIL, register=false, script_id=0, }
  before_each(clear)

  it('gets empty list if no commands were defined', function()
    eq({}, meths.get_commands({builtin=false}))
  end)

  it('validates input', function()
    expect_err('builtin=true not implemented', meths.get_commands,
               {builtin=true})
    expect_err('unexpected key: foo', meths.get_commands,
               {foo='blah'})
  end)

  it('gets global user-defined commands', function()
    -- Define a command.
    command('command -nargs=1 Hello echo "Hello World"')
    eq({Hello=cmd_dict}, meths.get_commands({builtin=false}))
    -- Define another command.
    command('command -nargs=? Pwd pwd');
    eq({Hello=cmd_dict, Pwd=cmd_dict2}, meths.get_commands({builtin=false}))
    -- Delete a command.
    command('delcommand Pwd')
    eq({Hello=cmd_dict}, meths.get_commands({builtin=false}))
  end)

  it('gets buffer-local user-defined commands', function()
    -- Define a buffer-local command.
    command('command -buffer -nargs=1 Hello echo "Hello World"')
    eq({Hello=cmd_dict}, curbufmeths.get_commands({builtin=false}))
    -- Define another buffer-local command.
    command('command -buffer -nargs=? Pwd pwd')
    eq({Hello=cmd_dict, Pwd=cmd_dict2}, curbufmeths.get_commands({builtin=false}))
    -- Delete a command.
    command('delcommand Pwd')
    eq({Hello=cmd_dict}, curbufmeths.get_commands({builtin=false}))

    -- {builtin=true} always returns empty for buffer-local case.
    eq({}, curbufmeths.get_commands({builtin=true}))
  end)

  it('gets various command attributes', function()
    local cmd0 = { addr='arguments', bang=false, bar=false, complete='dir',    complete_arg=NIL,         count='10', definition='pwd <args>',                    name='TestCmd', nargs='0', range='10', register=false, script_id=0, }
    local cmd1 = { addr=NIL,         bang=false, bar=false, complete='custom', complete_arg='ListUsers', count=NIL,  definition='!finger <args>',                name='Finger',  nargs='+', range=NIL,  register=false, script_id=1, }
    local cmd2 = { addr=NIL,         bang=true,  bar=false, complete=NIL,      complete_arg=NIL,         count=NIL,  definition='call \128\253R2_foo(<q-args>)', name='Cmd2',    nargs='*', range=NIL,  register=false, script_id=2, }
    local cmd3 = { addr=NIL,         bang=false, bar=true,  complete=NIL,      complete_arg=NIL,         count=NIL,  definition='call \128\253R3_ohyeah()',      name='Cmd3',    nargs='0', range=NIL,  register=false, script_id=3, }
    local cmd4 = { addr=NIL,         bang=false, bar=false, complete=NIL,      complete_arg=NIL,         count=NIL,  definition='call \128\253R4_just_great()',  name='Cmd4',    nargs='0', range=NIL,  register=true,  script_id=4, }
    source([[
      command -complete=custom,ListUsers -nargs=+ Finger !finger <args>
    ]])
    eq({Finger=cmd1}, meths.get_commands({builtin=false}))
    command('command -complete=dir -addr=arguments -count=10 TestCmd pwd <args>')
    eq({Finger=cmd1, TestCmd=cmd0}, meths.get_commands({builtin=false}))

    source([[
      command -bang -nargs=* Cmd2 call <SID>foo(<q-args>)
    ]])
    source([[
      command -bar -nargs=0 Cmd3 call <SID>ohyeah()
    ]])
    source([[
      command -register Cmd4 call <SID>just_great()
    ]])
    -- TODO(justinmk): Order is stable but undefined. Sort before return?
    eq({Cmd2=cmd2, Cmd3=cmd3, Cmd4=cmd4, Finger=cmd1, TestCmd=cmd0}, meths.get_commands({builtin=false}))
  end)
end)
