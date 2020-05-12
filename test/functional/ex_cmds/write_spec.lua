local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local eq, eval, clear, write_file, source, insert =
  helpers.eq, helpers.eval, helpers.clear, helpers.write_file,
  helpers.source, helpers.insert
local redir_exec = helpers.redir_exec
local exc_exec = helpers.exc_exec
local command = helpers.command
local feed_command = helpers.feed_command
local funcs = helpers.funcs
local meths = helpers.meths
local iswin = helpers.iswin

local fname = 'Xtest-functional-ex_cmds-write'
local fname_bak = fname .. '~'
local fname_broken = fname_bak .. 'broken'

describe(':write', function()
  local function cleanup()
    os.remove('test_bkc_file.txt')
    os.remove('test_bkc_link.txt')
    os.remove('test_fifo')
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
    if iswin() then
      command("silent !mklink test_bkc_link.txt test_bkc_file.txt")
    else
      command("silent !ln -s test_bkc_file.txt test_bkc_link.txt")
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
    command('set backupcopy=no')
    write_file('test_bkc_file.txt', 'content0')
    if iswin() then
      command("silent !mklink test_bkc_link.txt test_bkc_file.txt")
    else
      command("silent !ln -s test_bkc_file.txt test_bkc_link.txt")
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

  it("appends FIFO file", function()
    -- mkfifo creates read-only .lnk files on Windows
    if iswin() or eval("executable('mkfifo')") == 0 then
      pending('missing "mkfifo" command')
    end

    local text = "some fifo text from write_spec"
    assert(os.execute("mkfifo test_fifo"))
    insert(text)

    -- Blocks until a consumer reads the FIFO.
    feed_command("write >> test_fifo")

    -- Read the FIFO, this will unblock the :write above.
    local fifo = assert(io.open("test_fifo"))
    eq(text.."\n", fifo:read("*all"))
    fifo:close()
  end)

  it('errors out correctly', function()
    command('let $HOME=""')
    eq(funcs.fnamemodify('.', ':p:h'), funcs.fnamemodify('.', ':p:h:~'))
    -- Message from check_overwrite
    if not iswin() then
      eq(('\nE17: "'..funcs.fnamemodify('.', ':p:h')..'" is a directory'),
        redir_exec('write .'))
    end
    meths.set_option('writeany', true)
    -- Message from buf_write
    eq(('\nE502: "." is a directory'),
       redir_exec('write .'))
    funcs.mkdir(fname_bak)
    meths.set_option('backupdir', '.')
    meths.set_option('backup', true)
    write_file(fname, 'content0')
    eq(0, exc_exec('edit ' .. fname))
    funcs.setline(1, 'TTY')
    eq('Vim(write):E510: Can\'t make backup file (add ! to override)',
       exc_exec('write'))
    meths.set_option('backup', false)
    funcs.setfperm(fname, 'r--------')
    eq('Vim(write):E505: "Xtest-functional-ex_cmds-write" is read-only (add ! to override)',
       exc_exec('write'))
    if iswin() then
      eq(0, os.execute('del /q/f ' .. fname))
      eq(0, os.execute('rd /q/s ' .. fname_bak))
    else
      eq(true, os.remove(fname))
      eq(true, os.remove(fname_bak))
    end
    write_file(fname_bak, 'TTYX')
    -- FIXME: exc_exec('write!') outputs 0 in Windows
    if iswin() then return end
    lfs.link(fname_bak .. ('/xxxxx'):rep(20), fname, true)
    eq('Vim(write):E166: Can\'t open linked file for writing',
       exc_exec('write!'))
  end)
end)
