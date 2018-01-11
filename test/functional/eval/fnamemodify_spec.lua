local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local iswin = helpers.iswin
local fnamemodify = helpers.funcs.fnamemodify
local command = helpers.command

describe('fnamemodify()', function()
  before_each(clear)

  it('works', function()
    local drive_f = io.popen('cd', 'r')
    local drive = string.gsub(drive_f:read('*a'), '[\n\r]', '')
    drive_f:close()

    if iswin() then
      local root = drive..[[\]]
      eq(root, fnamemodify([[\]], ':p:h'))
      eq(root, fnamemodify([[\]], ':p'))
      eq(root, fnamemodify([[/]], ':p:h'))
      eq(root, fnamemodify([[/]], ':p'))
      command('set shellslash')
      root = drive..[[/]]
      eq(root, fnamemodify([[\]], ':p:h'))
      eq(root, fnamemodify([[\]], ':p'))
      eq(root, fnamemodify([[/]], ':p:h'))
      eq(root, fnamemodify([[/]], ':p'))
    else
      eq('/', fnamemodify([[/]], ':p:h'))
      eq('/', fnamemodify([[/]], ':p'))
    end
  end)
end)
