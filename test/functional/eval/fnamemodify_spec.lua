local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local iswin = helpers.iswin
local fnamemodify = helpers.funcs.fnamemodify
local command = helpers.command
local write_file = helpers.write_file

describe('fnamemodify()', function()
  setup(function()
    write_file('Xtest-fnamemodify.txt', [[foobar]])
  end)

  before_each(clear)

  teardown(function()
    os.remove('Xtest-fnamemodify.txt')
  end)

  it('works', function()
    if iswin() then
      local drive_f = io.popen('for %P in (%CD%) do @echo %~dP', 'r')
      local drive = string.gsub(drive_f:read('*a'), '[\n\r]', '')
      drive_f:close()
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

  it(':8 works', function()
    eq('Xtest-fnamemodify.txt', fnamemodify([[Xtest-fnamemodify.txt]], ':8'))
  end)
end)
