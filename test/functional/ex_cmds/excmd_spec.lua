local helpers = require("test.functional.helpers")(after_each)
local command = helpers.command
local eq = helpers.eq
local clear = helpers.clear
local pcall_err = helpers.pcall_err
local assert_alive = helpers.assert_alive

describe('Ex cmds', function()
  before_each(function()
    clear()
  end)

  it('handle integer overflow from user-input #5555', function()
    command(':9999999999999999999999999999999999999999')
    command(':later 9999999999999999999999999999999999999999')
    command(':echo expand("#<9999999999999999999999999999999999999999")')
    command(':lockvar 9999999999999999999999999999999999999999')
    command(':winsize 9999999999999999999999999999999999999999 9999999999999999999999999999999999999999')
    eq('Vim(tabnext):E474: Invalid argument',
      pcall_err(command, ':tabnext 9999999999999999999999999999999999999999'))
    eq('Vim(Next):E939: Positive count required',
      pcall_err(command, ':N 9999999999999999999999999999999999999999'))
    eq('Vim(menu):E329: No menu "9999999999999999999999999999999999999999"',
      pcall_err(command, ':menu 9999999999999999999999999999999999999999'))
    eq('Vim(bdelete):E939: Positive count required',
      pcall_err(command, ':bdelete 9999999999999999999999999999999999999999'))
    eq('Vim(retab):E487: Argument must be positive',
      pcall_err(command, ':retab 9999999999999999999999999999999999999999'))
    assert_alive()
  end)
end)

