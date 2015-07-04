-- Test for "*Cmd" autocommands

local helpers = require('test.functional.helpers')
local clear, execute, expect, feed, write_file =
  helpers.clear, helpers.execute, helpers.expect, helpers.feed,
  helpers.write_file

describe('*Cmd autocommands', function()
  setup(function()
    clear()
    write_file('Xxx', [[
      start of Xxx
      	test40
      end of Xxx
      ]])
  end)
  teardown(function()
    os.remove('Xxx')
    os.remove('test.out')
  end)

  it('are working', function()
    execute('au BufReadCmd XtestA 0r Xxx|$del')
    -- Will read text of Xxx instead.
    execute('e! XtestA')
    execute('au BufWriteCmd XtestA call append(line("$"), "write")')
    -- Will append a line to the file.
    execute('w')
    -- Should not read anything.
    execute('r XtestA')
    execute("au FileReadCmd XtestB '[r Xxx")
    -- Will read Xxx below line 2 instead.
    execute('2r XtestB')
    execute("au FileWriteCmd XtestC '[,']copy $")
    feed('4GA1<esc>')
    -- Will copy lines 4 and 5 to the end.
    execute('4,5w XtestC')
    -- Should not read anything.
    execute('r XtestC')
    execute("au FILEAppendCmd XtestD '[,']w! test.out")
    -- Will write all lines to test.out.
    execute('w >>XtestD')
    -- Should not read anything.
    execute('$r XtestD')
    -- append "end of Xxx" to test.out
    execute('$w >>test.out')
    execute('au BufReadCmd XtestE 0r test.out|$del')
    -- Split window with test.out.
    execute('sp XtestE')
    feed('5Goasdf<esc><c-w><c-w>')
    execute('au BufWriteCmd XtestE w! test.out')
    -- Will write other window to test.out.
    execute('wall')
    execute('edit! test.out')

    -- Assert buffer contents.
    expect([[
      start of Xxx
      	test40
      start of Xxx
      	test401
      end of Xxx
      asdf
      end of Xxx
      write
      	test401
      end of Xxx
      end of Xxx]])
  end)
end)
