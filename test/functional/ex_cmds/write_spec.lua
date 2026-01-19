local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, eval, clear, write_file, source, insert =
  t.eq, n.eval, n.clear, t.write_file, n.source, n.insert
local pcall_err = t.pcall_err
local command = n.command
local feed_command = n.feed_command
local fn = n.fn
local api = n.api
local skip = t.skip
local is_os = t.is_os
local is_ci = t.is_ci
local read_file = t.read_file

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
    os.remove('test/write2/p_opt.txt')
    os.remove('test/write2/p_opt2.txt')
    os.remove('test/write2')
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

    eq(0, eval("filereadable('test/write2/p_opt.txt')"))
    eq(0, eval("filereadable('test/write2/p_opt2.txt')"))
    eq(0, eval("filereadable('test/write3/p_opt3.txt')"))
    command('file test/write2/p_opt.txt')
    command('set modified')
    command('sp test/write2/p_opt2.txt')
    command('set modified')
    command('sp test/write3/p_opt3.txt')
    -- don't set p_opt3.txt modified - assert it isn't written
    -- and that write3/ isn't created
    command('wall ++p')
    eq(1, eval("filereadable('test/write2/p_opt.txt')"))
    eq(1, eval("filereadable('test/write2/p_opt2.txt')"))
    eq(0, eval("filereadable('test/write3/p_opt3.txt')"))

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

  it('fails converting a trailing incomplete sequence', function()
    -- From https://github.com/neovim/neovim/issues/36990, an invalid UTF-8 sequence at the end of
    -- the file during conversion testing can overwrite the rest of the file during the real
    -- conversion.

    api.nvim_buf_set_lines(0, 0, 1, true, { 'line 1', 'line 2', 'aaabbb\235\128' })
    command('set noendofline nofixendofline')

    eq(
      "Vim(write):E513: Write error, conversion failed in line 3 (make 'fenc' empty to override)",
      pcall_err(command, 'write ++enc=latin1 ' .. fname)
    )
  end)

  it('converts to latin1 with an invalid sequence at buffer boundary', function()
    -- From https://github.com/neovim/neovim/issues/36990, an invalid UTF-8 sequence that falls
    -- right at the end of the 8 KiB buffer used for encoding conversions causes subsequent data to
    -- be overwritten.

    local content = string.rep('a', 1024 * 8 - 1) .. '\251' .. string.rep('b', 20)
    api.nvim_buf_set_lines(0, 0, 1, true, { content })
    command('set noendofline nofixendofline fenc=latin1')
    command('write ' .. fname)

    local tail = string.sub(read_file(fname) or '', -10)
    eq('bbbbbbbbbb', tail)
  end)

  it('converts to CP1251 with iconv', function()
    api.nvim_buf_set_lines(
      0,
      0,
      1,
      true,
      { 'Привет, мир!', 'Это простой тест.' }
    )
    command('write ++enc=cp1251 ++ff=unix ' .. fname)

    eq(
      '\207\240\232\226\229\242, \236\232\240!\n'
        .. '\221\242\238 \239\240\238\241\242\238\233 \242\229\241\242.\n',
      read_file(fname)
    )
  end)

  it('converts to GB18030 with iconv', function()
    api.nvim_buf_set_lines(0, 0, 1, true, { '你好，世界！', '这是一个测试。' })
    command('write ++enc=gb18030 ++ff=unix ' .. fname)

    eq(
      '\196\227\186\195\163\172\202\192\189\231\163\161\n'
        .. '\213\226\202\199\210\187\184\246\178\226\202\212\161\163\n',
      read_file(fname)
    )
  end)

  it('converts to Shift_JIS with iconv', function()
    api.nvim_buf_set_lines(
      0,
      0,
      1,
      true,
      { 'こんにちは、世界！', 'これはテストです。' }
    )
    command('write ++enc=sjis ++ff=unix ' .. fname)

    eq(
      '\130\177\130\241\130\201\130\191\130\205\129A\144\162\138E\129I\n'
        .. '\130\177\130\234\130\205\131e\131X\131g\130\197\130\183\129B\n',
      read_file(fname)
    )
  end)

  it('fails converting an illegal sequence with iconv', function()
    api.nvim_buf_set_lines(0, 0, 1, true, { 'line 1', 'aaa\128bbb' })

    eq(
      "Vim(write):E513: Write error, conversion failed (make 'fenc' empty to override)",
      pcall_err(command, 'write ++enc=cp1251 ' .. fname)
    )
  end)

  it('handles a multi-byte sequence crossing the buffer boundary converting with iconv', function()
    local content = string.rep('a', 1024 * 8 - 1) .. 'Дbbbbb'
    api.nvim_buf_set_lines(0, 0, 1, true, { content })
    -- Skip the backup so we're testing the "checking" phase also.
    command('set nowritebackup')
    command('write ++enc=cp1251 ++ff=unix ' .. fname)

    local expected = string.rep('a', 1024 * 8 - 1) .. '\196bbbbb\n'
    eq(expected, read_file(fname))
  end)
end)

describe(':update', function()
  before_each(function()
    clear()
    fn.mkdir('test_dir', 'p')
  end)

  after_each(function()
    fn.delete('test_dir', 'rf')
  end)

  it('works for a new buffer', function()
    command('edit test_dir/foo/bar/nonexist.taz | update ++p')
    eq(1, eval("filereadable('test_dir/foo/bar/nonexist.taz')"))
  end)

  it('writes modified buffer', function()
    command('edit test_dir/modified.txt')
    command('call setline(1, "hello world")')
    command('update')
    eq({ 'hello world' }, fn.readfile('test_dir/modified.txt'))
  end)

  it('does not write unmodified existing file', function()
    local filename = 'test_dir/existing.txt'
    local fd = io.open(filename, 'w')
    fd:write('content')
    fd:close()
    local mtime_before = fn.getftime(filename)
    command('edit ' .. filename)
    command('update')
    eq(mtime_before, fn.getftime(filename))
  end)

  it('creates parent directories with ++p', function()
    command('edit test_dir/deep/nested/path/file.txt')
    command('call setline(1, "content")')
    command('update ++p')
    eq(1, eval("filereadable('test_dir/deep/nested/path/file.txt')"))
  end)

  it('fails gracefully for unnamed buffer', function()
    command('enew')
    command('call setline(1, "some content")')
    eq('Vim(update):E32: No file name', pcall_err(command, 'update'))
  end)

  it('respects readonly files', function()
    local filename = 'test_dir/readonly.txt'
    local fd = io.open(filename, 'w')
    fd:write('readonly content')
    fd:close()
    command('edit ' .. filename)
    command('set readonly')
    command('call setline(1, "modified")')
    eq(
      "Vim(update):E45: 'readonly' option is set (add ! to override)",
      pcall_err(command, 'update')
    )

    command('update!')
    eq({ 'modified' }, fn.readfile('test_dir/readonly.txt'))
  end)

  it('can write line ranges', function()
    command('edit test_dir/range.txt')
    command('call setline(1, ["line1", "line2", "line3", "line4"])')
    command('2,3update!')
    eq({ 'line2', 'line3' }, fn.readfile('test_dir/range.txt'))
  end)

  it('can append to existing file', function()
    local filename = 'test_dir/append.txt'
    local fd = io.open(filename, 'w')
    fd:write('existing\n')
    fd:close()
    command('edit test_dir/new_content.txt')
    command('call setline(1, "new content")')
    command('update >> ' .. filename)

    eq({ 'existing', 'new content' }, fn.readfile('test_dir/append.txt'))
  end)

  it('triggers autocmds properly', function()
    command('autocmd BufWritePre * let g:write_pre = 1')
    command('autocmd BufWritePost * let g:write_post = 1')

    command('edit test_dir/autocmd.txt')
    command('call setline(1, "trigger autocmds")')
    command('update')

    eq(1, eval('g:write_pre'))
    eq(1, eval('g:write_post'))
  end)

  it('does not write acwrite buffer when unchanged', function()
    command('file remote://test')
    command('setlocal buftype=acwrite')
    command('let g:triggered = 0 | autocmd BufWriteCmd remote://* let g:triggered = 1')
    command('update')
    eq(0, eval('g:triggered'))
    command('call setline(1, ["hello"])')
    command('update')
    eq(1, eval('g:triggered'))
  end)
end)
