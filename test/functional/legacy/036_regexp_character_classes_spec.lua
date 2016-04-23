-- Test character classes in regexp using regexpengine 0, 1, 2.

local helpers = require('test.functional.helpers')(after_each)
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local source, write_file = helpers.source, helpers.write_file
local os_name = helpers.os_name

local function sixlines(text)
    local result = ''
    for _ = 1, 6 do
      result = result .. text .. '\n'
    end
    return result
end

local function diff(text, nodedent)
  local tmpname = os.tmpname()
  if os_name() == 'osx' and string.match(tmpname, '^/tmp') then
   tmpname = '/private'..tmpname
  end
  execute('w! '..tmpname)
  helpers.wait()
  local data = io.open(tmpname):read('*all')
  if nodedent then
    helpers.eq(text, data)
  else
    helpers.eq(helpers.dedent(text), data)
  end
  os.remove(tmpname)
end

describe('character classes in regexp', function()
  local ctrl1 = '\t\012\r'
  local punct1 = " !\"#$%&'()#+'-./"
  local digits = '0123456789'
  local punct2 = ':;<=>?@'
  local upper = 'ABCDEFGHIXYZ'
  local punct3 = '[\\]^_`'
  local lower = 'abcdefghiwxyz'
  local punct4 = '{|}~'
  local ctrl2 = '\127\128\130\144\155'
  local iso_text = '\166\177\188\199\211\233' -- "¦±¼ÇÓé" in utf-8
  setup(function()
    -- The original test32.in file was not in utf-8 encoding and did also
    -- contain some control characters.  We use lua escape sequences to write
    -- them to the test file.
    local line = ctrl1..punct1..digits..punct2..upper..punct3..lower..punct4..ctrl2..iso_text
    write_file('test36.in', sixlines(line))
  end)
  before_each(function()
    clear()
    execute('e test36.in')
  end)
  teardown(function()
    os.remove('test36.in')
  end)

  it('is working', function()
    source([[
      1 s/\%#=0\d//g
      2 s/\%#=1\d//g
      3 s/\%#=2\d//g
      4 s/\%#=0[0-9]//g
      5 s/\%#=1[0-9]//g
      6 s/\%#=2[0-9]//g]])
    diff(sixlines(ctrl1..punct1..punct2..upper..punct3..lower..punct4..
        ctrl2..iso_text))
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\D//g
      2 s/\%#=1\D//g
      3 s/\%#=2\D//g
      4 s/\%#=0[^0-9]//g
      5 s/\%#=1[^0-9]//g
      6 s/\%#=2[^0-9]//g]])
    expect([[
      0123456789
      0123456789
      0123456789
      0123456789
      0123456789
      0123456789]])
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\o//g
      2 s/\%#=1\o//g
      3 s/\%#=2\o//g
      4 s/\%#=0[0-7]//g
      5 s/\%#=1[0-7]//g
      6 s/\%#=2[0-7]//g]])
    diff(sixlines(ctrl1..punct1..'89'..punct2..upper..punct3..lower..punct4..ctrl2..
      iso_text))
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\O//g
      2 s/\%#=1\O//g
      3 s/\%#=2\O//g
      4 s/\%#=0[^0-7]//g
      5 s/\%#=1[^0-7]//g
      6 s/\%#=2[^0-7]//g]])
    expect([[
      01234567
      01234567
      01234567
      01234567
      01234567
      01234567]])
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\x//g
      2 s/\%#=1\x//g
      3 s/\%#=2\x//g
      4 s/\%#=0[0-9A-Fa-f]//g
      5 s/\%#=1[0-9A-Fa-f]//g
      6 s/\%#=2[0-9A-Fa-f]//g]])
      diff(sixlines(ctrl1..punct1..punct2..'GHIXYZ'..punct3..'ghiwxyz'..punct4..ctrl2..iso_text))
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\X//g
      2 s/\%#=1\X//g
      3 s/\%#=2\X//g
      4 s/\%#=0[^0-9A-Fa-f]//g
      5 s/\%#=1[^0-9A-Fa-f]//g
      6 s/\%#=2[^0-9A-Fa-f]//g]])
    expect([[
      0123456789ABCDEFabcdef
      0123456789ABCDEFabcdef
      0123456789ABCDEFabcdef
      0123456789ABCDEFabcdef
      0123456789ABCDEFabcdef
      0123456789ABCDEFabcdef]])
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\w//g
      2 s/\%#=1\w//g
      3 s/\%#=2\w//g
      4 s/\%#=0[0-9A-Za-z_]//g
      5 s/\%#=1[0-9A-Za-z_]//g
      6 s/\%#=2[0-9A-Za-z_]//g]])
      diff(sixlines(ctrl1..punct1..punct2..'[\\]^`'..punct4..ctrl2..iso_text))
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\W//g
      2 s/\%#=1\W//g
      3 s/\%#=2\W//g
      4 s/\%#=0[^0-9A-Za-z_]//g
      5 s/\%#=1[^0-9A-Za-z_]//g
      6 s/\%#=2[^0-9A-Za-z_]//g]])
    expect([[
      0123456789ABCDEFGHIXYZ_abcdefghiwxyz
      0123456789ABCDEFGHIXYZ_abcdefghiwxyz
      0123456789ABCDEFGHIXYZ_abcdefghiwxyz
      0123456789ABCDEFGHIXYZ_abcdefghiwxyz
      0123456789ABCDEFGHIXYZ_abcdefghiwxyz
      0123456789ABCDEFGHIXYZ_abcdefghiwxyz]])
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\h//g
      2 s/\%#=1\h//g
      3 s/\%#=2\h//g
      4 s/\%#=0[A-Za-z_]//g
      5 s/\%#=1[A-Za-z_]//g
      6 s/\%#=2[A-Za-z_]//g]])
      diff(sixlines(ctrl1..punct1..digits..punct2..'[\\]^`'..punct4..ctrl2..
        iso_text))
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\H//g
      2 s/\%#=1\H//g
      3 s/\%#=2\H//g
      4 s/\%#=0[^A-Za-z_]//g
      5 s/\%#=1[^A-Za-z_]//g
      6 s/\%#=2[^A-Za-z_]//g]])
    expect([[
      ABCDEFGHIXYZ_abcdefghiwxyz
      ABCDEFGHIXYZ_abcdefghiwxyz
      ABCDEFGHIXYZ_abcdefghiwxyz
      ABCDEFGHIXYZ_abcdefghiwxyz
      ABCDEFGHIXYZ_abcdefghiwxyz
      ABCDEFGHIXYZ_abcdefghiwxyz]])
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\a//g
      2 s/\%#=1\a//g
      3 s/\%#=2\a//g
      4 s/\%#=0[A-Za-z]//g
      5 s/\%#=1[A-Za-z]//g
      6 s/\%#=2[A-Za-z]//g]])
    diff(sixlines(ctrl1..punct1..digits..punct2..punct3..punct4..ctrl2..iso_text))
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\A//g
      2 s/\%#=1\A//g
      3 s/\%#=2\A//g
      4 s/\%#=0[^A-Za-z]//g
      5 s/\%#=1[^A-Za-z]//g
      6 s/\%#=2[^A-Za-z]//g]])
    expect([[
      ABCDEFGHIXYZabcdefghiwxyz
      ABCDEFGHIXYZabcdefghiwxyz
      ABCDEFGHIXYZabcdefghiwxyz
      ABCDEFGHIXYZabcdefghiwxyz
      ABCDEFGHIXYZabcdefghiwxyz
      ABCDEFGHIXYZabcdefghiwxyz]])
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\l//g
      2 s/\%#=1\l//g
      3 s/\%#=2\l//g
      4 s/\%#=0[a-z]//g
      5 s/\%#=1[a-z]//g
      6 s/\%#=2[a-z]//g]])
    diff(sixlines(ctrl1..punct1..digits..punct2..upper..punct3..punct4..
      ctrl2..iso_text))
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\L//g
      2 s/\%#=1\L//g
      3 s/\%#=2\L//g
      4 s/\%#=0[^a-z]//g
      5 s/\%#=1[^a-z]//g
      6 s/\%#=2[^a-z]//g]])
    expect([[
      abcdefghiwxyz
      abcdefghiwxyz
      abcdefghiwxyz
      abcdefghiwxyz
      abcdefghiwxyz
      abcdefghiwxyz]])
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\u//g
      2 s/\%#=1\u//g
      3 s/\%#=2\u//g
      4 s/\%#=0[A-Z]//g
      5 s/\%#=1[A-Z]//g
      6 s/\%#=2[A-Z]//g]])
    diff(sixlines(ctrl1..punct1..digits..punct2..punct3..lower..punct4..
      ctrl2..iso_text))
  end)
  it('is working', function()
    source([[
      1 s/\%#=0\U//g
      2 s/\%#=1\U//g
      3 s/\%#=2\U//g
      4 s/\%#=0[^A-Z]//g
      5 s/\%#=1[^A-Z]//g
      6 s/\%#=2[^A-Z]//g]])
    expect([[
      ABCDEFGHIXYZ
      ABCDEFGHIXYZ
      ABCDEFGHIXYZ
      ABCDEFGHIXYZ
      ABCDEFGHIXYZ
      ABCDEFGHIXYZ]])
  end)
end)
