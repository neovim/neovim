local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local iswin = helpers.iswin
local fnamemodify = helpers.funcs.fnamemodify
local command = helpers.command

describe('fnamemodify()', function()
  before_each(clear)

  it('works', function()
    if iswin() then
      eq([[C:\]], fnamemodify([[\]], ':p:h'))
      eq([[C:\]], fnamemodify([[\]], ':p'))
      eq([[C:\]], fnamemodify([[/]], ':p:h'))
      eq([[C:\]], fnamemodify([[/]], ':p'))
      command('set shellslash')
      eq([[C:/]], fnamemodify([[\]], ':p:h'))
      eq([[C:/]], fnamemodify([[\]], ':p'))
      eq([[C:/]], fnamemodify([[/]], ':p:h'))
      eq([[C:/]], fnamemodify([[/]], ':p'))
    else
      eq('/', fnamemodify([[/]], ':p:h'))
      eq('/', fnamemodify([[/]], ':p'))
    end
  end)
end)
