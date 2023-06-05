local helpers = require("test.functional.helpers")(after_each)
local command = helpers.command
local eq = helpers.eq
local clear = helpers.clear
local funcs = helpers.funcs
local pcall_err = helpers.pcall_err
local assert_alive = helpers.assert_alive

describe('Ex cmds', function()
  before_each(function()
    clear()
  end)

  local function check_excmd_err(cmd, err)
    eq(err .. ': ' .. cmd, pcall_err(command, cmd))
  end

  it('handle integer overflow from user-input #5555', function()
    command(':9999999999999999999999999999999999999999')
    command(':later 9999999999999999999999999999999999999999')
    command(':echo expand("#<9999999999999999999999999999999999999999")')
    command(':lockvar 9999999999999999999999999999999999999999')
    command(':winsize 9999999999999999999999999999999999999999 9999999999999999999999999999999999999999')
    check_excmd_err(':tabnext 9999999999999999999999999999999999999999',
                    'Vim(tabnext):E475: Invalid argument: 9999999999999999999999999999999999999999')
    check_excmd_err(':N 9999999999999999999999999999999999999999',
                    'Vim(Next):E939: Positive count required')
    check_excmd_err(':bdelete 9999999999999999999999999999999999999999',
                    'Vim(bdelete):E939: Positive count required')
    eq('Vim(menu):E329: No menu "9999999999999999999999999999999999999999"',
      pcall_err(command, ':menu 9999999999999999999999999999999999999999'))
    assert_alive()
  end)

  it('listing long user command does not crash', function()
    command('execute "command" repeat("T", 255) ":"')
    command('command')
  end)

  it(':def is an unknown command #23149', function()
    eq('Vim:E492: Not an editor command: def', pcall_err(command, 'def'))
    eq(1, funcs.exists(':d'))
    eq('delete', funcs.fullcommand('d'))
    eq(1, funcs.exists(':de'))
    eq('delete', funcs.fullcommand('de'))
    eq(0, funcs.exists(':def'))
    eq('', funcs.fullcommand('def'))
    eq(1, funcs.exists(':defe'))
    eq('defer', funcs.fullcommand('defe'))
    eq(2, funcs.exists(':defer'))
    eq('defer', funcs.fullcommand('defer'))
  end)
end)
