local helpers = require('test.functional.helpers')(after_each)
local eq, eval, clear, write_file, execute, source, insert =
  helpers.eq, helpers.eval, helpers.clear, helpers.write_file,
  helpers.execute, helpers.source, helpers.insert

if helpers.pending_win32(pending) then return end

describe(':write', function()
  local function cleanup()
    os.remove('test_bkc_file.txt')
    os.remove('test_bkc_link.txt')
    os.remove('test_fifo')
  end
  before_each(function()
    clear()
    cleanup()
  end)
  after_each(function()
    cleanup()
  end)

  it('&backupcopy=auto preserves symlinks', function()
    execute('set backupcopy=auto')
    write_file('test_bkc_file.txt', 'content0')
    execute("silent !ln -s test_bkc_file.txt test_bkc_link.txt")
    source([[
      edit test_bkc_link.txt
      call setline(1, ['content1'])
      write
    ]])
    eq(eval("['content1']"), eval("readfile('test_bkc_file.txt')"))
    eq(eval("['content1']"), eval("readfile('test_bkc_link.txt')"))
  end)

  it('&backupcopy=no replaces symlink with new file', function()
    execute('set backupcopy=no')
    write_file('test_bkc_file.txt', 'content0')
    execute("silent !ln -s test_bkc_file.txt test_bkc_link.txt")
    source([[
      edit test_bkc_link.txt
      call setline(1, ['content1'])
      write
    ]])
    eq(eval("['content0']"), eval("readfile('test_bkc_file.txt')"))
    eq(eval("['content1']"), eval("readfile('test_bkc_link.txt')"))
  end)

  it("appends FIFO file", function()
    if eval("executable('mkfifo')") == 0 then
      pending('missing "mkfifo" command', function()end)
      return
    end

    local text = "some fifo text from write_spec"
    assert(os.execute("mkfifo test_fifo"))
    insert(text)

    -- Blocks until a consumer reads the FIFO.
    execute("write >> test_fifo")

    -- Read the FIFO, this will unblock the :write above.
    local fifo = assert(io.open("test_fifo"))
    eq(text.."\n", fifo:read("*all"))
    fifo:close()
  end)
end)
