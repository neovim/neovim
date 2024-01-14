-- Tests for errorformat.

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command, expect = helpers.command, helpers.expect

describe('errorformat', function()
  setup(clear)

  it('is working', function()
    command("set efm=%EEEE%m,%WWWW%m,%+CCCC%.%#,%-GGGG%.%#")
    command("cgetexpr ['WWWW', 'EEEE', 'CCCC']")
    command("$put =strtrans(string(map(getqflist(), '[v:val.text, v:val.valid]')))")
    command("cgetexpr ['WWWW', 'GGGG', 'EEEE', 'CCCC']")
    command("$put =strtrans(string(map(getqflist(), '[v:val.text, v:val.valid]')))")
    command("cgetexpr ['WWWW', 'GGGG', 'ZZZZ', 'EEEE', 'CCCC', 'YYYY']")
    command("$put =strtrans(string(map(getqflist(), '[v:val.text, v:val.valid]')))")

    expect([=[

      [['W', 1], ['E^@CCCC', 1]]
      [['W', 1], ['E^@CCCC', 1]]
      [['W', 1], ['ZZZZ', 0], ['E^@CCCC', 1], ['YYYY', 0]]]=])
  end)
end)
