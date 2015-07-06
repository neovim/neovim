-- Test for writing and reading a file starting with a BOM

local helpers, lfs = require('test.functional.helpers'), require('lfs')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect, eq, eval, wait = helpers.clear, helpers.execute, helpers.expect, helpers.eq, helpers.eval, helpers.wait

-- Helper function to write a string to a file after dedenting it.
local write_file = function (name, contents)
  local file = io.open(name, 'w')
  file:write(helpers.dedent(contents))
  file:flush()
  file:close()
end

describe('reading and writing files with BOM', function()
  local latin1 = '\xfe\xfelatin-1'
  local utf8 = '\xef\xbb\xbfutf-8'
  local utf8_err = '\xef\xbb\xbfutf-8\x80err'
  local ucs2 = '\xfe\xff\x00u\x00c\x00s\x00-\x002\x00'
  local ucs2_le = '\xff\xfeu\x00c\x00s\x00-\x002\x00l\x00e\x00'
  local ucs4 = '\x00\x00\xfe\xff\x00\x00\x00u\x00\x00\x00c\x00\x00\x00s'..
    '\x00\x00\x00-\x00\x00\x004\x00\x00\x00'
  local ucs4_le = '\xff\xfe\x00\x00u\x00\x00\x00c\x00\x00\x00s\x00\x00\x00'..
    '-\x00\x00\x004\x00\x00\x00l\x00\x00\x00e\x00\x00\x00'
  setup(function()
    clear()
    write_file('Xtest0', latin1..'\n')
    write_file('Xtest1', utf8..'\n')
    write_file('Xtest2', utf8_err..'\n')
    write_file('Xtest3', ucs2..'\n')
    write_file('Xtest4', ucs2_le..'\n\x00')
    write_file('Xtest5', ucs4..'\n')
    write_file('Xtest6', ucs4_le..'\n\x00\x00\x00')
  end)
  teardown(function()
    os.remove('Xtest0')
    os.remove('Xtest1')
    os.remove('Xtest2')
    os.remove('Xtest3')
    os.remove('Xtest4')
    os.remove('Xtest5')
    os.remove('Xtest6')
  end)

  it('is working', function()
    execute('set encoding=utf-8')
    execute('set fileencodings=ucs-bom,latin-1')
    execute('set ff=unix ffs=unix')
    execute('set ffs& nobinary')
    execute('set noeol')
    execute('set nobin')

    -- Check that editing a latin-1 file doesn't see a BOM.
    eq('', eval('&fileencoding'))
    execute('e Xtest0')
    wait()
    eq(0, eval('&bomb'))
    --eq('latin1', eval('&fileencoding')) -- TODO
    execute('redir! >test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    expect(latin1)
    execute('w >>test.out')
    execute('set bomb fenc=latin-1')
    execute('w! Xtest0x')
    wait()
    helpers.neq(nil, lfs.attributes('Xtest0x'))

    -- Check utf-8.
    execute('e! Xtest1')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=utf-8')
    execute('w! Xtest1x')

    -- Check utf-8 with an error (will fall back to latin-1).
    execute('e! Xtest2')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=utf-8')
    execute('w! Xtest2x')

    -- Check ucs-2.
    execute('e! Xtest3')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=ucs-2')
    execute('w! Xtest3x')

    -- Check ucs-2le.
    execute('e! Xtest4')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=ucs-2le')
    execute('w! Xtest4x')

    -- Check ucs-4.
    execute('e! Xtest5')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=ucs-4')
    execute('w! Xtest5x')

    -- Check ucs-4le.
    execute('e! Xtest6')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=ucs-4le')
    execute('w! Xtest6x')

    -- Check the files written with BOM.
    source([[
      set bin
      e! test.out
      $r Xtest0x
      $r Xtest1x
      $r Xtest2x
      $r Xtest3x
      $r Xtest4x
      $r Xtest5x
      $r Xtest6x
    ]])
    -- Write the file in default format.
    execute('set nobin ff&')
    execute('w! test.out')

    -- Assert buffer contents.
    expect([[
      
      
        fileencoding=latin1
      nobomb
      þþlatin-1
      
      
        fileencoding=utf-8
        bomb
      utf-8
      
      
        fileencoding=latin1
      nobomb
      ï»¿utf-8]]..'\x80'..[[err
      
      
        fileencoding=utf-16
        bomb
      ucs-2
      
      
        fileencoding=utf-16le
        bomb
      ucs-2le
      
      
        fileencoding=ucs-4
        bomb
      ucs-4
      
      
        fileencoding=ucs-4le
        bomb
      ucs-4le
      þþlatin-1
      ï»¿utf-8
      Ã¯Â»Â¿utf-8Â]]..'\x80'..[[err
      ]]..'þÿ\x00u\x00c\x00s\x00-\x002\x00'..[[
      ]]..'ÿþu\x00c\x00s\x00-\x002\x00l\x00e\x00'..[[
      ]]..'\x00'..[[
      ]]..'\x00\x00þÿ\x00\x00\x00u\x00\x00\x00c\x00\x00\x00s\x00\x00\x00-\x00\x00\x004\x00\x00\x00'..[[
      ]]..'ÿþ\x00\x00u\x00\x00\x00c\x00\x00\x00s\x00\x00\x00-\x00\x00\x004\x00\x00\x00l\x00\x00\x00e\x00\x00\x00'..[[
      ]]..'\x00\x00\x00')
  end)
end)
