-- ShaDa buffer list saving/reading support
local helpers = require('test.functional.helpers')
local nvim, nvim_window, nvim_curwin, nvim_command, nvim_feed, nvim_eval, eq =
  helpers.nvim, helpers.window, helpers.curwin, helpers.command, helpers.feed,
  helpers.eval, helpers.eq

local shada_helpers = require('test.functional.shada.helpers')
local reset, set_additional_cmd, clear =
  shada_helpers.reset, shada_helpers.set_additional_cmd,
  shada_helpers.clear

local nvim_current_line = function()
  return nvim_window('get_cursor', nvim_curwin())[1]
end

describe('ShaDa support code', function()
  testfilename = 'Xtestfile-functional-shada-buffers'
  testfilename_2 = 'Xtestfile-functional-shada-buffers-2'
  before_each(reset)
  after_each(clear)

  it('is able to dump and restore buffer list', function()
    set_additional_cmd('set viminfo+=%')
    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('edit ' .. testfilename_2)
    -- nvim_command('redir! > /tmp/vistr | verbose set viminfo? | redir END')
    -- nvim_command('wviminfo /tmp/foo')
    nvim_command('qall')
    reset()
    -- nvim_command('call writefile([&viminfo], "/tmp/vistr")')
    eq(3, nvim_eval('bufnr("$")'))
    eq('', nvim_eval('bufname(1)'))
    eq(testfilename, nvim_eval('bufname(2)'))
    eq(testfilename_2, nvim_eval('bufname(3)'))
  end)

  it('does not restore buffer list without % in &viminfo', function()
    set_additional_cmd('set viminfo+=%')
    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('edit ' .. testfilename_2)
    -- nvim_command('redir! > /tmp/vistr | verbose set viminfo? | redir END')
    -- nvim_command('wviminfo /tmp/foo')
    set_additional_cmd('')
    nvim_command('qall')
    reset()
    -- nvim_command('call writefile([&viminfo], "/tmp/vistr")')
    eq(1, nvim_eval('bufnr("$")'))
    eq('', nvim_eval('bufname(1)'))
  end)

  it('does not dump buffer list without % in &viminfo', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('edit ' .. testfilename_2)
    -- nvim_command('redir! > /tmp/vistr | verbose set viminfo? | redir END')
    -- nvim_command('wviminfo /tmp/foo')
    set_additional_cmd('set viminfo+=%')
    nvim_command('qall')
    reset()
    -- nvim_command('call writefile([&viminfo], "/tmp/vistr")')
    eq(1, nvim_eval('bufnr("$")'))
    eq('', nvim_eval('bufname(1)'))
  end)
end)
