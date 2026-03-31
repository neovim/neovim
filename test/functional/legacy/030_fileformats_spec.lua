-- Test for a lot of variations of the 'fileformats' option

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local feed, clear, command = n.feed, n.clear, n.command
local eq, write_file = t.eq, t.write_file
local poke_eventloop = n.poke_eventloop

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
    command('set fileformats=')
    command('set fileformat=unix')
    command('e! XXUnix')
    command('w! test.out')
    command('e! XXDos')
    command('w! XXtt01')
    command('e! XXMac')
    command('w! XXtt02')
    command('bwipe XXUnix XXDos XXMac')
    command('set fileformat=dos')
    command('e! XXUnix')
    command('w! XXtt11')
    command('e! XXDos')
    command('w! XXtt12')
    command('e! XXMac')
    command('w! XXtt13')
    command('bwipe XXUnix XXDos XXMac')
    command('set fileformat=mac')
    command('e! XXUnix')
    command('w! XXtt21')
    command('e! XXDos')
    command('w! XXtt22')
    command('e! XXMac')
    command('w! XXtt23')
    command('bwipe XXUnix XXDos XXMac')

    -- Try reading and writing with 'fileformats' set to one format.
    command('set fileformats=unix')
    command('e! XXUxDsMc')
    command('w! XXtt31')
    command('bwipe XXUxDsMc')
    command('set fileformats=dos')
    command('e! XXUxDsMc')
    command('w! XXtt32')
    command('bwipe XXUxDsMc')
    command('set fileformats=mac')
    command('e! XXUxDsMc')
    command('w! XXtt33')
    command('bwipe XXUxDsMc')

    -- Try reading and writing with 'fileformats' set to two formats.
    command('set fileformats=unix,dos')
    command('e! XXUxDsMc')
    command('w! XXtt41')
    command('bwipe XXUxDsMc')
    command('e! XXUxMac')
    command('w! XXtt42')
    command('bwipe XXUxMac')
    command('e! XXDosMac')
    command('w! XXtt43')
    command('bwipe XXDosMac')
    command('set fileformats=unix,mac')
    command('e! XXUxDs')
    command('w! XXtt51')
    command('bwipe XXUxDs')
    command('e! XXUxDsMc')
    command('w! XXtt52')
    command('bwipe XXUxDsMc')
    command('e! XXDosMac')
    command('w! XXtt53')
    command('bwipe XXDosMac')
    command('e! XXEol')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    poke_eventloop()
    command('w! XXtt54')
    command('bwipeout! XXEol')
    command('set fileformats=dos,mac')
    command('e! XXUxDs')
    command('w! XXtt61')
    command('bwipe XXUxDs')
    command('e! XXUxMac')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    poke_eventloop()
    command('w! XXtt62')
    command('bwipeout! XXUxMac')
    command('e! XXUxDsMc')
    command('w! XXtt63')
    command('bwipe XXUxDsMc')
    command('e! XXMacEol')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    poke_eventloop()
    command('w! XXtt64')
    command('bwipeout! XXMacEol')

    -- Try reading and writing with 'fileformats' set to three formats.
    command('set fileformats=unix,dos,mac')
    command('e! XXUxDsMc')
    command('w! XXtt71')
    command('bwipe XXUxDsMc')
    command('e! XXEol')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    poke_eventloop()
    command('w! XXtt72')
    command('bwipeout! XXEol')
    command('set fileformats=mac,dos,unix')
    command('e! XXUxDsMc')
    command('w! XXtt81')
    command('bwipe XXUxDsMc')
    command('e! XXEol')
    feed('ggO<C-R>=&ffs<CR>:<C-R>=&ff<CR><ESC>')
    poke_eventloop()
    command('w! XXtt82')
    command('bwipeout! XXEol')
    -- Try with 'binary' set.
    command('set fileformats=mac,unix,dos')
    command('set binary')
    command('e! XXUxDsMc')
    command('w! XXtt91')
    command('bwipe XXUxDsMc')
    command('set fileformats=mac')
    command('e! XXUxDsMc')
    command('w! XXtt92')
    command('bwipe XXUxDsMc')
    command('set fileformats=dos')
    command('e! XXUxDsMc')
    command('w! XXtt93')

    -- Append "END" to each file so that we can see what the last written
    -- char was.
    command('set fileformat=unix nobin')
    feed('ggdGaEND<esc>')
    poke_eventloop()
    command('w >>XXtt01')
    command('w >>XXtt02')
    command('w >>XXtt11')
    command('w >>XXtt12')
    command('w >>XXtt13')
    command('w >>XXtt21')
    command('w >>XXtt22')
    command('w >>XXtt23')
    command('w >>XXtt31')
    command('w >>XXtt32')
    command('w >>XXtt33')
    command('w >>XXtt41')
    command('w >>XXtt42')
    command('w >>XXtt43')
    command('w >>XXtt51')
    command('w >>XXtt52')
    command('w >>XXtt53')
    command('w >>XXtt54')
    command('w >>XXtt61')
    command('w >>XXtt62')
    command('w >>XXtt63')
    command('w >>XXtt64')
    command('w >>XXtt71')
    command('w >>XXtt72')
    command('w >>XXtt81')
    command('w >>XXtt82')
    command('w >>XXtt91')
    command('w >>XXtt92')
    command('w >>XXtt93')

    -- Concatenate the results.
    -- Make fileformat of test.out the native fileformat.
    -- Add a newline at the end.
    command('set binary')
    command('e! test.out')
    command('$r XXtt01')
    command('$r XXtt02')
    feed('Go1<esc>')
    poke_eventloop()
    command('$r XXtt11')
    command('$r XXtt12')
    command('$r XXtt13')
    feed('Go2<esc>')
    poke_eventloop()
    command('$r XXtt21')
    command('$r XXtt22')
    command('$r XXtt23')
    feed('Go3<esc>')
    poke_eventloop()
    command('$r XXtt31')
    command('$r XXtt32')
    command('$r XXtt33')
    feed('Go4<esc>')
    poke_eventloop()
    command('$r XXtt41')
    command('$r XXtt42')
    command('$r XXtt43')
    feed('Go5<esc>')
    poke_eventloop()
    command('$r XXtt51')
    command('$r XXtt52')
    command('$r XXtt53')
    command('$r XXtt54')
    feed('Go6<esc>')
    poke_eventloop()
    command('$r XXtt61')
    command('$r XXtt62')
    command('$r XXtt63')
    command('$r XXtt64')
    feed('Go7<esc>')
    poke_eventloop()
    command('$r XXtt71')
    command('$r XXtt72')
    feed('Go8<esc>')
    poke_eventloop()
    command('$r XXtt81')
    command('$r XXtt82')
    feed('Go9<esc>')
    poke_eventloop()
    command('$r XXtt91')
    command('$r XXtt92')
    command('$r XXtt93')
    feed('Go10<esc>')
    poke_eventloop()
    command('$r XXUnix')
    command('set nobinary ff&')

    -- Assert buffer contents.  This has to be done manually as
    -- n.expect() calls t.dedent() which messes up the white space
    -- and carriage returns.
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
      n.curbuf_contents())
  end)
end)
