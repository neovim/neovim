local helpers = require('test.functional.helpers')(after_each)
local assert_alive = helpers.assert_alive
local clear = helpers.clear
local command = helpers.command
local feed = helpers.feed

before_each(clear)

-- oldtest: Test_crash1()
it('no crash when ending Visual mode while editing buffer closes window', function()
  command('new')
  command('autocmd ModeChanged v:n ++once close')
  feed('v')
  command('enew')
  assert_alive()
end)
