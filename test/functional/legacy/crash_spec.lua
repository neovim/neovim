local n = require('test.functional.testnvim')()

local assert_alive = n.assert_alive
local clear = n.clear
local command = n.command
local feed = n.feed

before_each(clear)

it('no crash when ending Visual mode while editing buffer closes window', function()
  command('new')
  command('autocmd ModeChanged v:n ++once close')
  feed('v')
  command('enew')
  assert_alive()
end)

it('no crash when ending Visual mode close the window to switch to', function()
  command('new')
  command('autocmd ModeChanged v:n ++once only')
  feed('v')
  command('wincmd p')
  assert_alive()
end)

it('no crash when truncating overlong message', function()
  pcall(command, 'source test/old/testdir/crash/vim_msg_trunc_poc')
  assert_alive()
end)

it('no crash with very long option error message', function()
  pcall(command, 'source test/old/testdir/crash/poc_did_set_langmap')
  assert_alive()
end)
