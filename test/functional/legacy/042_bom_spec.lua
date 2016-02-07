-- Test for writing and reading a file starting with a BOM

local helpers, lfs = require('test.functional.helpers'), require('lfs')
local clear, execute, expect, eq, eval, wait, write_file, neq =
  helpers.clear, helpers.execute, helpers.expect, helpers.eq, helpers.eval,
  helpers.wait, helpers.write_file, helpers.neq

local function diff(filename, text)
  -- Assert that the file exists, otherwise we could get a nil error later.
  neq(nil, lfs.attributes(filename))
  local file = io.open(filename)
  local filecontents = file:read('*all')
  file:close()
  return eq(helpers.dedent(text), filecontents)
end

describe('reading and writing files with BOM:', function()
  local latin1 = '\xfe\xfelatin-1'
  local utf8 = '\xef\xbb\xbfutf-8'
  local utf8_err = '\xef\xbb\xbfutf-8\x80err'
  local ucs2 = '\xfe\xff\x00u\x00c\x00s\x00-\x002\x00'
  local ucs2_le = '\xff\xfeu\x00c\x00s\x00-\x002\x00l\x00e'
  local ucs4 = '\x00\x00\xfe\xff\x00\x00\x00u\x00\x00\x00c\x00\x00\x00s'..
    '\x00\x00\x00-\x00\x00\x004'
  local ucs4_le = '\xff\xfe\x00\x00u\x00\x00\x00c\x00\x00\x00s\x00\x00\x00'..
    '-\x00\x00\x004\x00\x00\x00l\x00\x00\x00e\x00\x00\x00'
  setup(function()
    write_file('Xtest0', latin1..'\n')
    write_file('Xtest1', utf8..'\n')
    write_file('Xtest2', utf8_err..'\n')
    write_file('Xtest3', ucs2..'\x00\n')
    write_file('Xtest4', ucs2_le..'\n\x00')
    write_file('Xtest5', ucs4..'\x00\x00\x00\n')
    write_file('Xtest6', ucs4_le..'\n\x00\x00\x00')
  end)
  before_each(clear)
  teardown(function()
    os.remove('Xtest0')
    os.remove('Xtest1')
    os.remove('Xtest2')
    os.remove('Xtest3')
    os.remove('Xtest4')
    os.remove('Xtest5')
    os.remove('Xtest6')
    os.remove('Xtest.out')
  end)

  it('no BOM in latin1 files', function()
    execute('set fileencodings=ucs-bom,latin-1')
    execute('set noeol')
    -- Check that editing a latin-1 file doesn't see a BOM.
    execute('e Xtest0')
    eq(0, eval('&bomb'))
    eq('latin1', eval('&fileencoding'))
    execute('set bomb fenc=latin-1')
    execute('w! Xtest.out')
    --expect(latin1) -- TODO
    diff('Xtest.out', latin1..'\n')
  end)

  it('utf-8', function()
    execute('set fileencodings=ucs-bom,latin-1')
    execute('set noeol')
    execute('set bomb fenc=latin-1')
    -- Check utf-8.
    execute('e! Xtest1')
    eq(1, eval('&bomb'))
    eq('utf-8', eval('&fileencoding'))
    execute('set fenc=utf-8')
    execute('w! Xtest.out')
    expect('utf-8')
    diff('Xtest.out', utf8..'\n')
  end)

  it('utf-8 with erronous BOM should fall back to latin1', function()
    execute('set fileencodings=ucs-bom,latin-1')
    execute('set noeol')
    execute('set bomb')
    execute('set fenc=utf-8')
    -- Check utf-8 with an error (will fall back to latin-1).
    execute('e! Xtest2')
    eq(0, eval('&bomb'))
    eq('latin1', eval('&fileencoding'))
    execute('set fenc=utf-8')
    execute('w! Xtest.out')
    expect('ï»¿utf-8\x80err')
    diff('Xtest.out', utf8_err..'\n')
  end)

  it('ucs2', function()
    execute('set fileencodings=ucs-bom,latin-1')
    execute('set noeol')
    execute('set bomb fenc=latin-1')
    execute('set fenc=utf-8')

    -- Check ucs-2.
    execute('e! Xtest3')
    eq(1, eval('&bomb'))
    eq('utf-16', eval('&fileencoding'))
    execute('set fenc=ucs-2')
    execute('w! Xtest.out')
    expect('ucs-2')
    diff('Xtest.out', ucs2..'\n')
  end)

  it('ucs-2le', function()
    -- Check ucs-2le.
    execute('e! Xtest4')
    eq(1, eval('&bomb'))
    eq('utf-16le', eval('&fileencoding'))
    execute('set fenc=ucs-2le')
    execute('w! Xtest.out')
    expect('ucs-2le')
    diff('Xtest.out', utf8..'\n')
  end)

  it('ucs-4', function()
    -- Check ucs-4.
    execute('e! Xtest5')
    eq(1, eval('&bomb'))
    eq('ucs-4', eval('&fileencoding'))
    execute('set fenc=ucs-4')
    execute('w! Xtest.out')
    expect('ucs-4')
    diff('Xtest.out', utf8..'\n')
  end)

  it('is working', function()
    -- Check ucs-4le.
    execute('e! Xtest6')
    eq(1, eval('&bomb'))
    eq('ucs-4le', eval('&fileencoding'))
    execute('set fenc=ucs-4le')
    execute('w! Xtest.out')
    expect('ucs-4le')
    diff('Xtest.out', utf8..'\n')
  end)
end)
