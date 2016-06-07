-- Specs for :write

local helpers = require('test.functional.helpers')(after_each)
local eq, eval, clear, write_file, execute, source =
	helpers.eq, helpers.eval, helpers.clear, helpers.write_file,
	helpers.execute, helpers.source

describe(':write', function()
  after_each(function()
    os.remove('test_bkc_file.txt')
    os.remove('test_bkc_link.txt')
  end)

  it('&backupcopy=auto preserves symlinks', function()
    clear('set backupcopy=auto')
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
    clear('set backupcopy=no')
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
end)
