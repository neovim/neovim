local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local assert_alive = n.assert_alive
local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval
local exec = n.exec
local feed = n.feed
local pcall_err = t.pcall_err

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

it('no crash when closing window with tag in loclist', function()
  exec([[
    new
    lexpr ['foo']
    lopen
    let g:qf_bufnr = bufnr()
    lclose
    call settagstack(1, #{items: [#{tagname: 'foo', from: [g:qf_bufnr, 1, 1, 0]}]})
  ]])
  eq(1, eval('bufexists(g:qf_bufnr)'))
  command('1close')
  eq(0, eval('bufexists(g:qf_bufnr)'))
  assert_alive()
end)

it('no crash when writing "Untitled" file fails', function()
  t.mkdir('Untitled')
  finally(function()
    vim.uv.fs_rmdir('Untitled')
  end)
  feed('ifoobar')
  command('set bufhidden=unload')
  eq('Vim(enew):E502: "Untitled" is a directory', pcall_err(command, 'confirm enew'))
  assert_alive()
end)
