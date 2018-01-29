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
    local root = helpers.pathroot()
    eq(root, fnamemodify([[/]], ':p:h'))
    eq(root, fnamemodify([[/]], ':p'))
    if iswin() then
      eq(root, fnamemodify([[\]], ':p:h'))
      eq(root, fnamemodify([[\]], ':p'))
      command('set shellslash')
      root = string.sub(root, 1, -2)..'/'
      eq(root, fnamemodify([[\]], ':p:h'))
      eq(root, fnamemodify([[\]], ':p'))
      eq(root, fnamemodify([[/]], ':p:h'))
      eq(root, fnamemodify([[/]], ':p'))
    end
  end)

  it(':8 works', function()
    eq('Xtest-fnamemodify.txt', fnamemodify([[Xtest-fnamemodify.txt]], ':8'))
  end)
end)
