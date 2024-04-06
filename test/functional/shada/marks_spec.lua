-- ShaDa marks saving/reading support
local helpers = require('test.functional.helpers')(after_each)
local api, nvim_command, fn, eq = helpers.api, helpers.command, helpers.fn, helpers.eq
local feed = helpers.feed
local exc_exec, exec_capture = helpers.exc_exec, helpers.exec_capture
local expect_exit = helpers.expect_exit

local shada_helpers = require('test.functional.shada.helpers')
local reset, clear = shada_helpers.reset, shada_helpers.clear

local nvim_current_line = function()
  return api.nvim_win_get_cursor(0)[1]
end

describe('ShaDa support code', function()
  local testfilename = 'Xtestfile-functional-shada-marks'
  local testfilename_2 = 'Xtestfile-functional-shada-marks-2'
  local non_existent_testfilename = testfilename .. '.nonexistent'
  before_each(function()
    reset()
    os.remove(non_existent_testfilename)
    local fd = io.open(testfilename, 'w')
    fd:write('test\n')
    fd:write('test2\n')
    fd:close()
    fd = io.open(testfilename_2, 'w')
    fd:write('test3\n')
    fd:write('test4\n')
    fd:close()
  end)
  after_each(function()
    clear()
    os.remove(testfilename)
    os.remove(testfilename_2)
  end)

  it('is able to dump and read back global mark', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('mark A')
    nvim_command('2')
    nvim_command('kB')
    nvim_command('wshada')
    reset()
    nvim_command('rshada')
    nvim_command('normal! `A')
    eq(testfilename, fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
    eq(1, nvim_current_line())
    nvim_command('normal! `B')
    eq(2, nvim_current_line())
  end)

  it('does not dump global mark with `f0` in shada', function()
    nvim_command('set shada+=f0')
    nvim_command('edit ' .. testfilename)
    nvim_command('mark A')
    nvim_command('2')
    nvim_command('kB')
    nvim_command('wshada')
    reset()
    nvim_command('language C')
    eq('Vim(normal):E20: Mark not set', exc_exec('normal! `A'))
  end)

  it("does read back global mark even with `'0` and `f0` in shada", function()
    nvim_command('edit ' .. testfilename)
    nvim_command('mark A')
    nvim_command('2')
    nvim_command('kB')
    nvim_command('wshada')
    reset("set shada='0,f0")
    nvim_command('language C')
    nvim_command('normal! `A')
    eq(testfilename, fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
    eq(1, nvim_current_line())
  end)

  it('is able to dump and read back local mark', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('mark a')
    nvim_command('2')
    nvim_command('kb')
    expect_exit(nvim_command, 'qall')
    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('normal! `a')
    eq(testfilename, fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
    eq(1, nvim_current_line())
    nvim_command('normal! `b')
    eq(2, nvim_current_line())
  end)

  it('is able to dump and read back mark "', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('2')
    expect_exit(nvim_command, 'qall')
    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('normal! `"')
    eq(2, nvim_current_line())
  end)

  it('is able to dump and read back mark " from a closed tab', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('tabedit ' .. testfilename_2)
    nvim_command('2')
    nvim_command('q!')
    expect_exit(nvim_command, 'qall')
    reset()
    nvim_command('edit ' .. testfilename_2)
    nvim_command('normal! `"')
    eq(2, nvim_current_line())
  end)

  it('is able to populate v:oldfiles', function()
    nvim_command('edit ' .. testfilename)
    local tf_full = api.nvim_buf_get_name(0)
    nvim_command('edit ' .. testfilename_2)
    local tf_full_2 = api.nvim_buf_get_name(0)
    expect_exit(nvim_command, 'qall')
    reset()
    local oldfiles = api.nvim_get_vvar('oldfiles')
    table.sort(oldfiles)
    eq(2, #oldfiles)
    eq(testfilename, oldfiles[1]:sub(-#testfilename))
    eq(testfilename_2, oldfiles[2]:sub(-#testfilename_2))
    eq(tf_full, oldfiles[1])
    eq(tf_full_2, oldfiles[2])
    nvim_command('rshada!')
    oldfiles = api.nvim_get_vvar('oldfiles')
    table.sort(oldfiles)
    eq(2, #oldfiles)
    eq(testfilename, oldfiles[1]:sub(-#testfilename))
    eq(testfilename_2, oldfiles[2]:sub(-#testfilename_2))
    eq(tf_full, oldfiles[1])
    eq(tf_full_2, oldfiles[2])
  end)

  it('is able to dump and restore jump list', function()
    nvim_command('edit ' .. testfilename_2)
    nvim_command('normal! G')
    nvim_command('normal! gg')
    nvim_command('edit ' .. testfilename)
    nvim_command('normal! G')
    nvim_command('normal! gg')
    nvim_command('enew')
    nvim_command('normal! gg')
    local saved = exec_capture('jumps')
    expect_exit(nvim_command, 'qall')
    reset()
    eq(saved, exec_capture('jumps'))
  end)

  it('when dumping jump list also dumps current position', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('normal! G')
    nvim_command('split ' .. testfilename_2)
    nvim_command('normal! G')
    nvim_command('wshada')
    nvim_command('quit')
    nvim_command('rshada')
    nvim_command('normal! \15') -- <C-o>
    eq(testfilename_2, fn.bufname('%'))
    eq({ 2, 0 }, api.nvim_win_get_cursor(0))
  end)

  it('is able to dump and restore jump list with different times', function()
    nvim_command('edit ' .. testfilename_2)
    nvim_command('sleep 10m')
    nvim_command('normal! G')
    nvim_command('sleep 10m')
    nvim_command('normal! gg')
    nvim_command('sleep 10m')
    nvim_command('edit ' .. testfilename)
    nvim_command('sleep 10m')
    nvim_command('normal! G')
    nvim_command('sleep 10m')
    nvim_command('normal! gg')
    expect_exit(nvim_command, 'qall')
    reset()
    nvim_command('redraw')
    nvim_command('edit ' .. testfilename)
    eq(testfilename, fn.bufname('%'))
    eq(1, nvim_current_line())
    nvim_command('execute "normal! \\<C-o>"')
    eq(testfilename, fn.bufname('%'))
    eq(2, nvim_current_line())
    nvim_command('execute "normal! \\<C-o>"')
    eq(testfilename_2, fn.bufname('%'))
    eq(1, nvim_current_line())
    nvim_command('execute "normal! \\<C-o>"')
    eq(testfilename_2, fn.bufname('%'))
    eq(2, nvim_current_line())
    nvim_command('execute "normal! \\<C-o>"')
    eq(testfilename_2, fn.bufname('%'))
    eq(2, nvim_current_line())
  end)

  it('is able to dump and restore change list', function()
    nvim_command('edit ' .. testfilename)
    nvim_command('normal! Gra')
    nvim_command('normal! ggrb')
    expect_exit(nvim_command, 'qall!')
    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('normal! Gg;')
    -- Note: without “sync” “commands” test has good changes to fail for unknown
    -- reason (in first eq expected 1 is compared with 2). Any command inserted
    -- causes this to work properly.
    nvim_command('" sync')
    eq(1, nvim_current_line())
    nvim_command('normal! g;')
    nvim_command('" sync 2')
    eq(2, nvim_current_line())
  end)

  -- -c temporary sets lnum to zero to make `+/pat` work, so calling setpcmark()
  -- during -c used to add item with zero lnum to jump list.
  it('does not create incorrect file for non-existent buffers when writing from -c', function()
    local argv = helpers.new_argv {
      args_rm = {
        '-i',
        '--embed', -- no --embed
      },
      args = {
        '-i',
        api.nvim_get_var('tmpname'), -- Use same shada file as parent.
        '--cmd',
        'silent edit ' .. non_existent_testfilename,
        '-c',
        'qall',
      },
    }
    eq('', fn.system(argv))
    eq(0, exc_exec('rshada'))
  end)

  it('does not create incorrect file for non-existent buffers opened from -c', function()
    local argv = helpers.new_argv {
      args_rm = {
        '-i',
        '--embed', -- no --embed
      },
      args = {
        '-i',
        api.nvim_get_var('tmpname'), -- Use same shada file as parent.
        '-c',
        'silent edit ' .. non_existent_testfilename,
        '-c',
        'autocmd VimEnter * qall',
      },
    }
    eq('', fn.system(argv))
    eq(0, exc_exec('rshada'))
  end)

  it('updates deleted marks with :delmarks', function()
    nvim_command('edit ' .. testfilename)

    nvim_command('mark A')
    nvim_command('mark a')
    -- create a change to set the '.' mark,
    -- since it can't be set via :mark
    feed('ggifoobar<esc>')
    nvim_command('wshada')

    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('normal! `A`a`.')
    nvim_command('delmarks A a .')
    nvim_command('wshada')

    reset()
    nvim_command('edit ' .. testfilename)
    eq('Vim(normal):E20: Mark not set', exc_exec('normal! `A'))
    eq('Vim(normal):E20: Mark not set', exc_exec('normal! `a'))
    eq('Vim(normal):E20: Mark not set', exc_exec('normal! `.'))
  end)

  it('updates deleted marks with :delmarks!', function()
    nvim_command('edit ' .. testfilename)

    nvim_command('mark A')
    nvim_command('mark a')
    feed('ggifoobar<esc>')
    nvim_command('wshada')

    reset()
    nvim_command('edit ' .. testfilename)
    nvim_command('normal! `A`a`.')
    nvim_command('delmarks!')
    nvim_command('wshada')

    reset()
    nvim_command('edit ' .. testfilename)
    eq('Vim(normal):E20: Mark not set', exc_exec('normal! `a'))
    eq('Vim(normal):E20: Mark not set', exc_exec('normal! `.'))
    -- Make sure that uppercase marks aren't deleted.
    nvim_command('normal! `A')
  end)
end)
