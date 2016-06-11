-- Tests for errorformat.

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local execute, expect = helpers.execute, helpers.expect

describe('errorformat', function()
  setup(clear)

  it('is working', function()
    execute("set efm=%EEEE%m,%WWWW%m,%+CCCC%.%#,%-GGGG%.%#")
    execute("cgetexpr ['WWWW', 'EEEE', 'CCCC']")
    execute("$put =strtrans(string(map(getqflist(), '[v:val.text, v:val.valid]')))")
    execute("cgetexpr ['WWWW', 'GGGG', 'EEEE', 'CCCC']")
    execute("$put =strtrans(string(map(getqflist(), '[v:val.text, v:val.valid]')))")
    execute("cgetexpr ['WWWW', 'GGGG', 'ZZZZ', 'EEEE', 'CCCC', 'YYYY']")
    execute("$put =strtrans(string(map(getqflist(), '[v:val.text, v:val.valid]')))")
    
    expect([=[
      
      [['W', 1], ['E^@CCCC', 1]]
      [['W', 1], ['E^@CCCC', 1]]
      [['W', 1], ['ZZZZ', 0], ['E^@CCCC', 1], ['YYYY', 0]]]=])
  end)
end)
