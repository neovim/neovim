local t = require('test.functional.testutil')(after_each)
local eq, eval, clear, write_file, source, insert =
  t.eq, t.eval, t.clear, t.write_file, t.source, t.insert
local pcall_err = t.pcall_err
local command = t.command
local feed_command = t.feed_command
local fn = t.fn
local api = t.api
local skip = t.skip
local is_os = t.is_os
local is_ci = t.is_ci

local fname = 'Xtest-functional-ex_cmds-write'
local fname_bak = fname .. '~'
local fname_broken = fname_bak .. 'broken'

describe(':write', function()
  local function cleanup()
    os.remove('test_bkc_file.txt')
    os.remove('test_bkc_link.txt')
    os.remove('test_fifo')
    os.remove('test/write/p_opt.txt')
    os.remove('test/write')
    os.remove('test')
    os.remove(fname)
    os.remove(fname_bak)
    os.remove(fname_broken)
  end
  before_each(function()
    clear()
    cleanup()
  end)
  after_each(function()
    cleanup()
  end)

  it('&backupcopy=auto preserves symlinks', function()
    command('set backupcopy=auto')
    write_file('test_bkc_file.txt', 'content0')
    if is_os('win') then
      command('silent !mklink test_bkc_link.txt test_bkc_file.txt')
    else
      command('silent !ln -s test_bkc_file.txt test_bkc_link.txt')
    end
    if eval('v:shell_error') ~= 0 then
      pending('Cannot create symlink')
    end
    source([[
      edit test_bkc_link.txt
      call setline(1, ['content1'])
      write
    ]])
    eq(eval("['content1']"), eval("readfile('test_bkc_file.txt')"))
    eq(eval("['content1']"), eval("readfile('test_bkc_link.txt')"))
  end)

  it('&backupcopy=no replaces symlink with new file', function()
    skip(is_ci('cirrus'))
    command('set backupcopy=no')
    write_file('test_bkc_file.txt', 'content0')
    if is_os('win') then
      command('silent !mklink test_bkc_link.txt test_bkc_file.txt')
    else
      command('silent !ln -s test_bkc_file.txt test_bkc_link.txt')
    end
    if eval('v:shell_error') ~= 0 then
      pending('Cannot create symlink')
    end
    source([[
      edit test_bkc_link.txt
      call setline(1, ['content1'])
      write
    ]])
    eq(eval("['content0']"), eval("readfile('test_bkc_file.txt')"))
    eq(eval("['content1']"), eval("readfile('test_bkc_link.txt')"))
  end)

  it('appends FIFO file', function()
    -- mkfifo creates read-only .lnk files on Windows
    if is_os('win') or eval("executable('mkfifo')") == 0 then
      pending('missing "mkfifo" command')
    end

    local text = 'some fifo text from write_spec'
    assert(os.execute('mkfifo test_fifo'))
    insert(text)

    -- Blocks until a consumer reads the FIFO.
    feed_command('write >> test_fifo')

    -- Read the FIFO, this will unblock the :write above.
    local fifo = assert(io.open('test_fifo'))
    eq(text .. '\n', fifo:read('*all'))
    fifo:close()
  end)

  it('++p creates missing parent directories', function()
    eq(0, eval("filereadable('p_opt.txt')"))
    command('write ++p p_opt.txt')
    eq(1, eval("filereadable('p_opt.txt')"))
    os.remove('p_opt.txt')

    eq(0, eval("filereadable('p_opt.txt')"))
    command('write ++p ./p_opt.txt')
    eq(1, eval("filereadable('p_opt.txt')"))
    os.remove('p_opt.txt')

    eq(0, eval("filereadable('test/write/p_opt.txt')"))
    command('write ++p test/write/p_opt.txt')
    eq(1, eval("filereadable('test/write/p_opt.txt')"))

    eq('Vim(write):E32: No file name', pcall_err(command, 'write ++p test_write/'))
    if not is_os('win') then
      eq(
        ('Vim(write):E17: "' .. fn.fnamemodify('.', ':p:h') .. '" is a directory'),
        pcall_err(command, 'write ++p .')
      )
      eq(
        ('Vim(write):E17: "' .. fn.fnamemodify('.', ':p:h') .. '" is a directory'),
        pcall_err(command, 'write ++p ./')
      )
    end
  end)

  it('errors out correctly', function()
    skip(is_ci('cirrus'))
    command('let $HOME=""')
    eq(fn.fnamemodify('.', ':p:h'), fn.fnamemodify('.', ':p:h:~'))
    -- Message from check_overwrite
    if not is_os('win') then
      eq(
        ('Vim(write):E17: "' .. fn.fnamemodify('.', ':p:h') .. '" is a directory'),
        pcall_err(command, 'write .')
      )
    end
    api.nvim_set_option_value('writeany', true, {})
    -- Message from buf_write
    eq('Vim(write):E502: "." is a directory', pcall_err(command, 'write .'))
    fn.mkdir(fname_bak)
    api.nvim_set_option_value('backupdir', '.', {})
    api.nvim_set_option_value('backup', true, {})
    write_file(fname, 'content0')
    command('edit ' .. fname)
    fn.setline(1, 'TTY')
    eq("Vim(write):E510: Can't make backup file (add ! to override)", pcall_err(command, 'write'))
    api.nvim_set_option_value('backup', false, {})
    fn.setfperm(fname, 'r--------')
    eq(
      'Vim(write):E505: "Xtest-functional-ex_cmds-write" is read-only (add ! to override)',
      pcall_err(command, 'write')
    )
    if is_os('win') then
      eq(0, os.execute('del /q/f ' .. fname))
      eq(0, os.execute('rd /q/s ' .. fname_bak))
    else
      eq(true, os.remove(fname))
      eq(true, os.remove(fname_bak))
    end
    write_file(fname_bak, 'TTYX')
    skip(is_os('win'), [[FIXME: exc_exec('write!') outputs 0 in Windows]])
    vim.uv.fs_symlink(fname_bak .. ('/xxxxx'):rep(20), fname)
    eq("Vim(write):E166: Can't open linked file for writing", pcall_err(command, 'write!'))
  end)
end)
