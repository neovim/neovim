local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local command = n.command
local eq = t.eq
local clear = n.clear
local fn = n.fn
local pcall_err = t.pcall_err
local assert_alive = n.assert_alive

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
    command(
      ':winsize 9999999999999999999999999999999999999999 9999999999999999999999999999999999999999'
    )
    check_excmd_err(
      ':tabnext 9999999999999999999999999999999999999999',
      'Vim(tabnext):E475: Invalid argument: 9999999999999999999999999999999999999999'
    )
    check_excmd_err(
      ':N 9999999999999999999999999999999999999999',
      'Vim(Next):E939: Positive count required'
    )
    check_excmd_err(
      ':bdelete 9999999999999999999999999999999999999999',
      'Vim(bdelete):E939: Positive count required'
    )
    eq(
      'Vim(menu):E329: No menu "9999999999999999999999999999999999999999"',
      pcall_err(command, ':menu 9999999999999999999999999999999999999999')
    )
    assert_alive()
  end)

  it('listing long user command does not crash', function()
    command('execute "command" repeat("T", 255) ":"')
    command('command')
  end)

  it(':def is an unknown command #23149', function()
    eq('Vim:E492: Not an editor command: def', pcall_err(command, 'def'))
    eq(1, fn.exists(':d'))
    eq('delete', fn.fullcommand('d'))
    eq(1, fn.exists(':de'))
    eq('delete', fn.fullcommand('de'))
    eq(0, fn.exists(':def'))
    eq('', fn.fullcommand('def'))
    eq(1, fn.exists(':defe'))
    eq('defer', fn.fullcommand('defe'))
    eq(2, fn.exists(':defer'))
    eq('defer', fn.fullcommand('defer'))
  end)
end)
