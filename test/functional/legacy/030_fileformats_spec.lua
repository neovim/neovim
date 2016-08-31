-- Test for a lot of variations of the 'fileformats' option

local helpers = require('test.functional.helpers')(after_each)
local feed, clear, execute = helpers.feed, helpers.clear, helpers.execute
local eq, write_file = helpers.eq, helpers.write_file

if helpers.pending_win32(pending) then return end

describe('fileformats option', function()
  setup(function()
    clear()
    local dos = 'dos\r\ndos\r\n'
    local mac = 'mac\rmac\r'
    local unix = 'unix\nunix\n'
    local eol = 'noeol'
    write_file('XXDos', dos)
    write_file('XXMac', mac)
    write_file('XXUnix', unix)
    write_file('XXEol', eol)
    write_file('XXDosMac', dos..mac)
    write_file('XXMacEol', mac..eol)
    write_file('XXUxDs', unix..dos)
    write_file('XXUxDsMc', unix..dos..mac)
    write_file('XXUxMac', unix..mac)
  end)

  teardown(function()
    os.remove('test.out')
    os.remove('XXDos')
    os.remove('XXMac')
    os.remove('XXUnix')
    os.remove('XXEol')
    os.remove('XXDosMac')
    os.remove('XXMacEol')
    os.remove('XXUxDs')
    os.remove('XXUxDsMc')
    os.remove('XXUxMac')
    for i = 0, 9 do
      for j = 1, 4 do
        os.remove('XXtt'..i..j)
      end
    end
  end)

  it('is working', function()

    -- Try reading and writing with 'fileformats' empty.
    execute('set fileformats=')
    execute('set fileformat=unix')
    execute('e! XXUnix')
    execute('w! test.out')
    execute('e! XXDos')
    execute('w! XXtt01')
    execute('e! XXMac')
    execute('w! XXtt02')
    execute('bwipe XXUnix XXDos XXMac')
    execute('set fileformat=dos')
    execute('e! XXUnix')
    execute('w! XXtt11')
    execute('e! XXDos')
    execute('w! XXtt12')
    execute('e! XXMac')
    execute('w! XXtt13')
    execute('bwipe XXUnix XXDos XXMac')
    execute('set fileformat=mac')
    execute('e! XXUnix')
    execute('w! XXtt21')
    execute('e! XXDos')
    execute('w! XXtt22')
    execute('e! XXMac')
    execute('w! XXtt23')
    execute('bwipe XXUnix XXDos XXMac')

    -- Try reading and writing with 'fileformats' set to one format.
    execute('set fileformats=unix')
    execute('e! XXUxDsMc')
    execute('w! XXtt31')
    execute('bwipe XXUxDsMc')
    execute('set fileformats=dos')
    execute('e! XXUxDsMc')
    execute('w! XXtt32')
    execute('bwipe XXUxDsMc')
    execute('set fileformats=mac')
    execute('e! XXUxDsMc')
    execute('w! XXtt33')
    execute('bwipe XXUxDsMc')

    -- Try reading and writing with 'fileformats' set to two formats.
    execute('set fileformats=unix,dos')
    execute('e! XXUxDsMc')
    execute('w! XXtt41')
    execute('bwipe XXUxDsMc')
    execute('e! XXUxMac')
    execute('w! XXtt42')
    execute('bwipe XXUxMac')
    execute('e! XXDosMac')
    execute('w! XXtt43')
    execute('bwipe XXDosMac')
    execute('set fileformats=unix,mac')
    execute('e! XXUxDs')
    execute('w! XXtt51')
    execute('bwipe XXUxDs')
    execute('e! XXUxDsMc')
    execute('w! XXtt52')
    execute('bwipe XXUxDsMc')
    execute('e! XXDosMac')
    execute('w! XXtt53')
    execute('bwipe XXDosMac')
    execute('e! XXEol')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    execute('w! XXtt54')
    execute('bwipe XXEol')
    execute('set fileformats=dos,mac')
    execute('e! XXUxDs')
    execute('w! XXtt61')
    execute('bwipe XXUxDs')
    execute('e! XXUxMac')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    execute('w! XXtt62')
    execute('bwipe XXUxMac')
    execute('e! XXUxDsMc')
    execute('w! XXtt63')
    execute('bwipe XXUxDsMc')
    execute('e! XXMacEol')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    execute('w! XXtt64')
    execute('bwipe XXMacEol')

    -- Try reading and writing with 'fileformats' set to three formats.
    execute('set fileformats=unix,dos,mac')
    execute('e! XXUxDsMc')
    execute('w! XXtt71')
    execute('bwipe XXUxDsMc')
    execute('e! XXEol')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    execute('w! XXtt72')
    execute('bwipe XXEol')
    execute('set fileformats=mac,dos,unix')
    execute('e! XXUxDsMc')
    execute('w! XXtt81')
    execute('bwipe XXUxDsMc')
    execute('e! XXEol')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    execute('w! XXtt82')
    execute('bwipe XXEol')
    -- Try with 'binary' set.
    execute('set fileformats=mac,unix,dos')
    execute('set binary')
    execute('e! XXUxDsMc')
    execute('w! XXtt91')
    execute('bwipe XXUxDsMc')
    execute('set fileformats=mac')
    execute('e! XXUxDsMc')
    execute('w! XXtt92')
    execute('bwipe XXUxDsMc')
    execute('set fileformats=dos')
    execute('e! XXUxDsMc')
    execute('w! XXtt93')

    -- Append "END" to each file so that we can see what the last written
    -- char was.
    execute('set fileformat=unix nobin')
    feed('ggdGaEND<esc>')
    execute('w >>XXtt01')
    execute('w >>XXtt02')
    execute('w >>XXtt11')
    execute('w >>XXtt12')
    execute('w >>XXtt13')
    execute('w >>XXtt21')
    execute('w >>XXtt22')
    execute('w >>XXtt23')
    execute('w >>XXtt31')
    execute('w >>XXtt32')
    execute('w >>XXtt33')
    execute('w >>XXtt41')
    execute('w >>XXtt42')
    execute('w >>XXtt43')
    execute('w >>XXtt51')
    execute('w >>XXtt52')
    execute('w >>XXtt53')
    execute('w >>XXtt54')
    execute('w >>XXtt61')
    execute('w >>XXtt62')
    execute('w >>XXtt63')
    execute('w >>XXtt64')
    execute('w >>XXtt71')
    execute('w >>XXtt72')
    execute('w >>XXtt81')
    execute('w >>XXtt82')
    execute('w >>XXtt91')
    execute('w >>XXtt92')
    execute('w >>XXtt93')

    -- Concatenate the results.
    -- Make fileformat of test.out the native fileformat.
    -- Add a newline at the end.
    execute('set binary')
    execute('e! test.out')
    execute('$r XXtt01')
    execute('$r XXtt02')
    feed('Go1<esc>')
    execute('$r XXtt11')
    execute('$r XXtt12')
    execute('$r XXtt13')
    feed('Go2<esc>')
    execute('$r XXtt21')
    execute('$r XXtt22')
    execute('$r XXtt23')
    feed('Go3<esc>')
    execute('$r XXtt31')
    execute('$r XXtt32')
    execute('$r XXtt33')
    feed('Go4<esc>')
    execute('$r XXtt41')
    execute('$r XXtt42')
    execute('$r XXtt43')
    feed('Go5<esc>')
    execute('$r XXtt51')
    execute('$r XXtt52')
    execute('$r XXtt53')
    execute('$r XXtt54')
    feed('Go6<esc>')
    execute('$r XXtt61')
    execute('$r XXtt62')
    execute('$r XXtt63')
    execute('$r XXtt64')
    feed('Go7<esc>')
    execute('$r XXtt71')
    execute('$r XXtt72')
    feed('Go8<esc>')
    execute('$r XXtt81')
    execute('$r XXtt82')
    feed('Go9<esc>')
    execute('$r XXtt91')
    execute('$r XXtt92')
    execute('$r XXtt93')
    feed('Go10<esc>')
    execute('$r XXUnix')
    execute('set nobinary ff&')

    -- Assert buffer contents.  This has to be done manually as
    -- helpers.expect() calls helpers.dedent() which messes up the white space
    -- and carrige returns.
    eq(
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'END\n'..
      'mac\rmac\r\n'..
      'END\n'..
      '1\n'..
      'unix\r\n'..
      'unix\r\n'..
      'END\n'..
      'dos\r\n'..
      'dos\r\n'..
      'END\n'..
      'mac\rmac\r\r\n'..
      'END\n'..
      '2\n'..
      'unix\n'..
      'unix\n'..
      '\rEND\n'..
      'dos\r\n'..
      'dos\r\n'..
      '\rEND\n'..
      'mac\rmac\rEND\n'..
      '3\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\r\n'..
      'END\n'..
      'unix\r\n'..
      'unix\r\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\r\r\n'..
      'END\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\rEND\n'..
      '4\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\r\n'..
      'END\n'..
      'unix\n'..
      'unix\n'..
      'mac\rmac\r\n'..
      'END\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\r\r\n'..
      'END\n'..
      '5\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'END\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\r\n'..
      'END\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\rEND\n'..
      'unix,mac:unix\n'..
      'noeol\n'..
      'END\n'..
      '6\n'..
      'unix\r\n'..
      'unix\r\n'..
      'dos\r\n'..
      'dos\r\n'..
      'END\n'..
      'dos,mac:dos\r\n'..
      'unix\r\n'..
      'unix\r\n'..
      'mac\rmac\r\r\n'..
      'END\n'..
      'unix\r\n'..
      'unix\r\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\r\r\n'..
      'END\n'..
      'dos,mac:mac\rmac\rmac\rnoeol\rEND\n'..
      '7\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\r\n'..
      'END\n'..
      'unix,dos,mac:unix\n'..
      'noeol\n'..
      'END\n'..
      '8\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\r\n'..
      'END\n'..
      'mac,dos,unix:mac\rnoeol\rEND\n'..
      '9\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\rEND\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\rEND\n'..
      'unix\n'..
      'unix\n'..
      'dos\r\n'..
      'dos\r\n'..
      'mac\rmac\rEND\n'..
      '10\n'..
      'unix\n'..
      'unix',
      helpers.curbuf_contents())
  end)
end)
