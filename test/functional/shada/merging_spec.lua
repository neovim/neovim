-- ShaDa merging data support
local t = require('test.functional.testutil')(after_each)
local nvim_command, fn, eq = t.command, t.fn, t.eq
local exc_exec, exec_capture = t.exc_exec, t.exec_capture
local api = t.api

local t_shada = require('test.functional.shada.testutil')
local reset, clear, get_shada_rw = t_shada.reset, t_shada.clear, t_shada.get_shada_rw
local read_shada_file = t_shada.read_shada_file

local wshada, sdrcmd, shada_fname = get_shada_rw('Xtest-functional-shada-merging.shada')

local mock_file_path = '/a/b/'
if t.is_os('win') then
  mock_file_path = 'C:/a/'
end

describe('ShaDa history merging code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('takes item with greater timestamp from Neovim instance when reading', function()
    wshada('\004\001\009\147\000\196\002ab\196\001a')
    eq(0, exc_exec(sdrcmd()))
    wshada('\004\000\009\147\000\196\002ab\196\001b')
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    eq(0, exc_exec('wshada! ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 and v.value[2] == 'ab' then
        eq(1, v.timestamp)
        eq('a', v.value[3])
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('takes item with equal timestamp from Neovim instance when reading', function()
    wshada('\004\000\009\147\000\196\002ab\196\001a')
    eq(0, exc_exec(sdrcmd()))
    wshada('\004\000\009\147\000\196\002ab\196\001b')
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    eq(0, exc_exec('wshada! ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 and v.value[2] == 'ab' then
        eq(0, v.timestamp)
        eq('a', v.value[3])
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('takes item with greater timestamp from ShaDa when reading', function()
    wshada('\004\000\009\147\000\196\002ab\196\001a')
    eq(0, exc_exec(sdrcmd()))
    wshada('\004\001\009\147\000\196\002ab\196\001b')
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    eq(0, exc_exec('wshada! ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 and v.value[2] == 'ab' then
        eq(1, v.timestamp)
        eq('b', v.value[3])
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('takes item with greater timestamp from Neovim instance when writing', function()
    wshada('\004\001\009\147\000\196\002ab\196\001a')
    eq(0, exc_exec(sdrcmd()))
    wshada('\004\000\009\147\000\196\002ab\196\001b')
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 and v.value[2] == 'ab' then
        eq(1, v.timestamp)
        eq('a', v.value[3])
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('takes item with equal timestamp from Neovim instance when writing', function()
    wshada('\004\000\009\147\000\196\002ab\196\001a')
    eq(0, exc_exec(sdrcmd()))
    wshada('\004\000\009\147\000\196\002ab\196\001b')
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 and v.value[2] == 'ab' then
        eq(0, v.timestamp)
        eq('a', v.value[3])
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('takes item with greater timestamp from ShaDa when writing', function()
    wshada('\004\000\009\147\000\196\002ab\196\001a')
    eq(0, exc_exec(sdrcmd()))
    wshada('\004\001\009\147\000\196\002ab\196\001b')
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 and v.value[2] == 'ab' then
        eq(1, v.timestamp)
        eq('b', v.value[3])
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('correctly reads history items with messed up timestamps', function()
    wshada(
      '\004\010\009\147\000\196\002ab\196\001a'
        .. '\004\010\009\147\000\196\002ac\196\001a'
        .. '\004\005\009\147\000\196\002ad\196\001a'
        .. '\004\100\009\147\000\196\002ae\196\001a'
        .. '\004\090\009\147\000\196\002af\196\001a'
    )
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    eq(0, exc_exec('wshada! ' .. shada_fname))
    local items = { 'ad', 'ab', 'ac', 'af', 'ae' }
    for i, v in ipairs(items) do
      eq(v, fn.histget(':', i))
    end
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 then
        found = found + 1
        eq(items[found], v.value[2])
        eq('a', v.value[3])
      end
    end
    eq(#items, found)
  end)

  it('correctly reorders history items with messed up timestamps when writing', function()
    wshada(
      '\004\010\009\147\000\196\002ab\196\001a'
        .. '\004\010\009\147\000\196\002ac\196\001a'
        .. '\004\005\009\147\000\196\002ad\196\001a'
        .. '\004\100\009\147\000\196\002ae\196\001a'
        .. '\004\090\009\147\000\196\002af\196\001a'
    )
    eq(0, exc_exec('wshada ' .. shada_fname))
    local items = { 'ad', 'ab', 'ac', 'af', 'ae' }
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 then
        found = found + 1
        eq(items[found], v.value[2])
        eq('a', v.value[3])
      end
    end
    eq(#items, found)
  end)

  it('correctly merges history items with duplicate mid entry when writing', function()
    -- Regression test: ShaDa code used to crash here.
    -- Conditions:
    -- 1. Entry which is duplicate to non-last entry.
    -- 2. At least one more non-duplicate entry.
    wshada(
      '\004\000\009\147\000\196\002ab\196\001a'
        .. '\004\001\009\147\000\196\002ac\196\001a'
        .. '\004\002\009\147\000\196\002ad\196\001a'
        .. '\004\003\009\147\000\196\002ac\196\001a'
        .. '\004\004\009\147\000\196\002af\196\001a'
        .. '\004\005\009\147\000\196\002ae\196\001a'
        .. '\004\006\009\147\000\196\002ag\196\001a'
        .. '\004\007\009\147\000\196\002ah\196\001a'
        .. '\004\008\009\147\000\196\002ai\196\001a'
    )
    eq(0, exc_exec('wshada ' .. shada_fname))
    local items = { 'ab', 'ad', 'ac', 'af', 'ae', 'ag', 'ah', 'ai' }
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 then
        found = found + 1
        eq(items[found], v.value[2])
        eq('a', v.value[3])
      end
    end
    eq(#items, found)
  end)

  it('correctly merges history items with duplicate adj entry when writing', function()
    wshada(
      '\004\000\009\147\000\196\002ab\196\001a'
        .. '\004\001\009\147\000\196\002ac\196\001a'
        .. '\004\002\009\147\000\196\002ad\196\001a'
        .. '\004\003\009\147\000\196\002ad\196\001a'
        .. '\004\004\009\147\000\196\002af\196\001a'
        .. '\004\005\009\147\000\196\002ae\196\001a'
        .. '\004\006\009\147\000\196\002ag\196\001a'
        .. '\004\007\009\147\000\196\002ah\196\001a'
        .. '\004\008\009\147\000\196\002ai\196\001a'
    )
    eq(0, exc_exec('wshada ' .. shada_fname))
    local items = { 'ab', 'ac', 'ad', 'af', 'ae', 'ag', 'ah', 'ai' }
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 then
        found = found + 1
        eq(items[found], v.value[2])
        eq('a', v.value[3])
      end
    end
    eq(#items, found)
  end)
end)

describe('ShaDa search pattern support code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('uses last search pattern with gt timestamp from instance when reading', function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162sX\194\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', fn.getreg('/'))
  end)

  it('uses last search pattern with gt tstamp from file when reading with bang', function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162sX\194\162sp\196\001?')
    eq(0, exc_exec(sdrcmd(true)))
    eq('?', fn.getreg('/'))
  end)

  it('uses last search pattern with eq timestamp from instance when reading', function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\001\011\130\162sX\194\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', fn.getreg('/'))
  end)

  it('uses last search pattern with gt timestamp from file when reading', function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\002\011\130\162sX\194\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('?', fn.getreg('/'))
  end)

  it('uses last search pattern with gt timestamp from instance when writing', function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162sX\194\162sp\196\001?')
    eq('-', fn.getreg('/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last search pattern with eq timestamp from instance when writing', function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\001\011\130\162sX\194\162sp\196\001?')
    eq('-', fn.getreg('/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last search pattern with gt timestamp from file when writing', function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\002\011\130\162sX\194\162sp\196\001?')
    eq('-', fn.getreg('/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '?' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last s/ pattern with gt timestamp from instance when reading', function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162ss\195\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', fn.getreg('/'))
  end)

  it('uses last s/ pattern with gt timestamp from file when reading with !', function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162ss\195\162sp\196\001?')
    eq(0, exc_exec(sdrcmd(true)))
    eq('?', fn.getreg('/'))
  end)

  it('uses last s/ pattern with eq timestamp from instance when reading', function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\001\011\130\162ss\195\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', fn.getreg('/'))
  end)

  it('uses last s/ pattern with gt timestamp from file when reading', function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\002\011\130\162ss\195\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('?', fn.getreg('/'))
  end)

  it('uses last s/ pattern with gt timestamp from instance when writing', function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162ss\195\162sp\196\001?')
    eq('-', fn.getreg('/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last s/ pattern with eq timestamp from instance when writing', function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\001\011\130\162ss\195\162sp\196\001?')
    eq('-', fn.getreg('/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last s/ pattern with gt timestamp from file when writing', function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\002\011\130\162ss\195\162sp\196\001?')
    eq('-', fn.getreg('/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '?' then
        found = found + 1
      end
    end
    eq(1, found)
  end)
end)

describe('ShaDa replacement string support code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('uses last replacement with gt timestamp from instance when reading', function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\000\004\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('s/.*/~')
    eq('-', fn.getline('.'))
    nvim_command('bwipeout!')
  end)

  it('uses last replacement with gt timestamp from file when reading with bang', function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\000\004\145\196\001?')
    eq(0, exc_exec(sdrcmd(true)))
    nvim_command('s/.*/~')
    eq('?', fn.getline('.'))
    nvim_command('bwipeout!')
  end)

  it('uses last replacement with eq timestamp from instance when reading', function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\001\004\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('s/.*/~')
    eq('-', fn.getline('.'))
    nvim_command('bwipeout!')
  end)

  it('uses last replacement with gt timestamp from file when reading', function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\002\004\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('s/.*/~')
    eq('?', fn.getline('.'))
    nvim_command('bwipeout!')
  end)

  it('uses last replacement with gt timestamp from instance when writing', function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\000\004\145\196\001?')
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 3 and v.value[1] == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last replacement with eq timestamp from instance when writing', function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\001\004\145\196\001?')
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 3 and v.value[1] == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last replacement with gt timestamp from file when writing', function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\002\004\145\196\001?')
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 3 and v.value[1] == '?' then
        found = found + 1
      end
    end
    eq(1, found)
  end)
end)

describe('ShaDa marks support code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('uses last A mark with gt timestamp from instance when reading', function()
    wshada('\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. '-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\000\018\131\162mX\195\161f\196\006' .. mock_file_path .. '?\161nA')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `A')
    eq('-', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
  end)

  it('can merge with file with mark 9 as the only numeric mark', function()
    wshada('\007\001\014\130\161f\196\006' .. mock_file_path .. '-\161n9')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `9oabc')
    eq('-', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = {}
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 and v.value.f == mock_file_path .. '-' then
        local name = ('%c'):format(v.value.n)
        found[name] = (found[name] or 0) + 1
      end
    end
    eq({ ['0'] = 1, ['1'] = 1 }, found)
  end)

  it('removes duplicates while merging', function()
    wshada(
      '\007\001\014\130\161f\196\006'
        .. mock_file_path
        .. '-\161n9'
        .. '\007\001\014\130\161f\196\006'
        .. mock_file_path
        .. '-\161n9'
    )
    eq(0, exc_exec(sdrcmd()))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 and v.value.f == mock_file_path .. '-' then
        print(require('test.format_string').format_luav(v))
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('does not leak when no append is performed due to too many marks', function()
    wshada(
      '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'a\161n0'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'b\161n1'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161n2'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'd\161n3'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'e\161n4'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'f\161n5'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'g\161n6'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'h\161n7'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'i\161n8'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'j\161n9'
        .. '\007\001\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'k\161n9'
    )
    eq(0, exc_exec(sdrcmd()))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = {}
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 and v.value.f:sub(1, #mock_file_path) == mock_file_path then
        found[#found + 1] = v.value.f:sub(#v.value.f)
      end
    end
    eq({ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j' }, found)
  end)

  it('does not leak when last mark in file removes some of the earlier ones', function()
    wshada(
      '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'a\161n0'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'b\161n1'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161n2'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'd\161n3'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'e\161n4'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'f\161n5'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'g\161n6'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'h\161n7'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'i\161n8'
        .. '\007\002\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'j\161n9'
        .. '\007\003\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'k\161n9'
    )
    eq(0, exc_exec(sdrcmd()))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = {}
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 and v.value.f:sub(1, #mock_file_path) == mock_file_path then
        found[#found + 1] = v.value.f:sub(#v.value.f)
      end
    end
    eq({ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'k' }, found)
  end)

  it('uses last A mark with gt timestamp from file when reading with !', function()
    wshada('\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. '-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\000\018\131\162mX\195\161f\196\006' .. mock_file_path .. '?\161nA')
    eq(0, exc_exec(sdrcmd(true)))
    nvim_command('normal! `A')
    eq('?', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
  end)

  it('uses last A mark with eq timestamp from instance when reading', function()
    wshada('\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. '-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. '?\161nA')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `A')
    eq('-', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
  end)

  it('uses last A mark with gt timestamp from file when reading', function()
    wshada('\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. '-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\002\018\131\162mX\195\161f\196\006' .. mock_file_path .. '?\161nA')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `A')
    eq('?', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
  end)

  it('uses last A mark with gt timestamp from instance when writing', function()
    wshada('\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. '-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\000\018\131\162mX\195\161f\196\006' .. mock_file_path .. '?\161nA')
    nvim_command('normal! `A')
    eq('-', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = {}
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 and v.value.f == mock_file_path .. '-' then
        local name = ('%c'):format(v.value.n)
        found[name] = (found[name] or 0) + 1
      end
    end
    eq({ ['0'] = 1, A = 1 }, found)
  end)

  it('uses last A mark with eq timestamp from instance when writing', function()
    wshada('\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. '-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. '?\161nA')
    nvim_command('normal! `A')
    eq('-', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = {}
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 and v.value.f == mock_file_path .. '-' then
        local name = ('%c'):format(v.value.n)
        found[name] = (found[name] or 0) + 1
      end
    end
    eq({ ['0'] = 1, A = 1 }, found)
  end)

  it('uses last A mark with gt timestamp from file when writing', function()
    wshada('\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. '-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\002\018\131\162mX\195\161f\196\006' .. mock_file_path .. '?\161nA')
    nvim_command('normal! `A')
    eq('-', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = {}
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 then
        local name = ('%c'):format(v.value.n)
        local _t = found[name] or {}
        _t[v.value.f] = (_t[v.value.f] or 0) + 1
        found[name] = _t
      end
    end
    eq({ ['0'] = { [mock_file_path .. '-'] = 1 }, A = { [mock_file_path .. '?'] = 1 } }, found)
  end)

  it('uses last a mark with gt timestamp from instance when reading', function()
    nvim_command('edit ' .. mock_file_path .. '-')
    fn.setline(1, { '-', '?' })
    wshada('\010\001\017\131\161l\001\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\000\017\131\161l\002\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `a')
    eq('-', fn.getline('.'))
  end)

  it('uses last a mark with gt timestamp from file when reading with !', function()
    nvim_command('edit ' .. mock_file_path .. '-')
    fn.setline(1, { '-', '?' })
    wshada('\010\001\017\131\161l\001\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\000\017\131\161l\002\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd(true)))
    nvim_command('normal! `a')
    eq('?', fn.getline('.'))
  end)

  it('uses last a mark with eq timestamp from instance when reading', function()
    nvim_command('edit ' .. mock_file_path .. '-')
    fn.setline(1, { '-', '?' })
    wshada('\010\001\017\131\161l\001\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\001\017\131\161l\002\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `a')
    eq('-', fn.getline('.'))
  end)

  it('uses last a mark with gt timestamp from file when reading', function()
    nvim_command('edit ' .. mock_file_path .. '-')
    fn.setline(1, { '-', '?' })
    wshada('\010\001\017\131\161l\001\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\002\017\131\161l\002\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `a')
    eq('?', fn.getline('.'))
  end)

  it('uses last a mark with gt timestamp from instance when writing', function()
    nvim_command('edit ' .. mock_file_path .. '-')
    fn.setline(1, { '-', '?' })
    wshada('\010\001\017\131\161l\001\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\000\017\131\161l\002\161f\196\006' .. mock_file_path .. '-\161na')
    nvim_command('normal! `a')
    eq('-', fn.getline('.'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if
        v.type == 10
        and v.value.f == '' .. mock_file_path .. '-'
        and v.value.n == ('a'):byte()
      then
        eq(true, v.value.l == 1 or v.value.l == nil)
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last a mark with eq timestamp from instance when writing', function()
    nvim_command('edit ' .. mock_file_path .. '-')
    fn.setline(1, { '-', '?' })
    wshada('\010\001\017\131\161l\001\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\001\017\131\161l\002\161f\196\006' .. mock_file_path .. '-\161na')
    nvim_command('normal! `a')
    eq('-', fn.getline('.'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if
        v.type == 10
        and v.value.f == '' .. mock_file_path .. '-'
        and v.value.n == ('a'):byte()
      then
        eq(true, v.value.l == 1 or v.value.l == nil)
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last a mark with gt timestamp from file when writing', function()
    nvim_command('edit ' .. mock_file_path .. '-')
    fn.setline(1, { '-', '?' })
    wshada('\010\001\017\131\161l\001\161f\196\006' .. mock_file_path .. '-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\002\017\131\161l\002\161f\196\006' .. mock_file_path .. '-\161na')
    nvim_command('normal! `a')
    eq('-', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if
        v.type == 10
        and v.value.f == '' .. mock_file_path .. '-'
        and v.value.n == ('a'):byte()
      then
        eq(2, v.value.l)
        found = found + 1
      end
    end
    eq(1, found)
  end)
end)

describe('ShaDa registers support code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('uses last a register with gt timestamp from instance when reading', function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\000\015\131\161na\162rX\194\162rc\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', fn.getreg('a'))
  end)

  it('uses last a register with gt timestamp from file when reading with !', function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\000\015\131\161na\162rX\194\162rc\145\196\001?')
    eq(0, exc_exec(sdrcmd(true)))
    eq('?', fn.getreg('a'))
  end)

  it('uses last a register with eq timestamp from instance when reading', function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', fn.getreg('a'))
  end)

  it('uses last a register with gt timestamp from file when reading', function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\002\015\131\161na\162rX\194\162rc\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('?', fn.getreg('a'))
  end)

  it('uses last a register with gt timestamp from instance when writing', function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\000\015\131\161na\162rX\194\162rc\145\196\001?')
    eq('-', fn.getreg('a'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 5 and v.value.n == ('a'):byte() then
        eq({ '-' }, v.value.rc)
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last a register with eq timestamp from instance when writing', function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001?')
    eq('-', fn.getreg('a'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 5 and v.value.n == ('a'):byte() then
        eq({ '-' }, v.value.rc)
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last a register with gt timestamp from file when writing', function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\002\015\131\161na\162rX\194\162rc\145\196\001?')
    eq('-', fn.getreg('a'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 5 and v.value.n == ('a'):byte() then
        eq({ '?' }, v.value.rc)
        found = found + 1
      end
    end
    eq(1, found)
  end)
end)

describe('ShaDa jumps support code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('merges jumps when reading', function()
    wshada(
      '\008\001\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\002'
        .. '\008\004\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'd\161l\002'
        .. '\008\007\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'e\161l\002'
    )
    eq(0, exc_exec(sdrcmd()))
    wshada(
      '\008\001\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\002'
        .. '\008\004\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'd\161l\003'
        .. '\008\007\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'f\161l\002'
    )
    eq(0, exc_exec(sdrcmd()))
    eq('', api.nvim_buf_get_name(0))
    eq(
      ' jump line  col file/text\n'
        .. '   5     2    0 '
        .. mock_file_path
        .. 'c\n'
        .. '   4     2    0 '
        .. mock_file_path
        .. 'd\n'
        .. '   3     3    0 '
        .. mock_file_path
        .. 'd\n'
        .. '   2     2    0 '
        .. mock_file_path
        .. 'e\n'
        .. '   1     2    0 '
        .. mock_file_path
        .. 'f\n'
        .. '>',
      exec_capture('jumps')
    )
  end)

  it('merges jumps when writing', function()
    wshada(
      '\008\001\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\002'
        .. '\008\004\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'd\161l\002'
        .. '\008\007\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'e\161l\002'
    )
    eq(0, exc_exec(sdrcmd()))
    wshada(
      '\008\001\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\002'
        .. '\008\004\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'd\161l\003'
        .. '\008\007\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'f\161l\002'
    )
    eq(0, exc_exec('wshada ' .. shada_fname))
    local jumps = {
      { file = '' .. mock_file_path .. 'c', line = 2 },
      { file = '' .. mock_file_path .. 'd', line = 2 },
      { file = '' .. mock_file_path .. 'd', line = 3 },
      { file = '' .. mock_file_path .. 'e', line = 2 },
      { file = '' .. mock_file_path .. 'f', line = 2 },
    }
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 8 then
        found = found + 1
        eq(jumps[found].file, v.value.f)
        eq(jumps[found].line, v.value.l)
      end
    end
    eq(#jumps, found)
  end)

  it('merges JUMPLISTSIZE jumps when writing', function()
    local jumps = {}
    local shada = ''
    for i = 1, 100 do
      shada = shada
        .. ('\008%c\018\131\162mX\195\161f\196\006' .. mock_file_path .. 'c\161l%c'):format(i, i)
      jumps[i] = { file = '' .. mock_file_path .. 'c', line = i }
    end
    wshada(shada)
    eq(0, exc_exec(sdrcmd()))
    shada = ''
    for i = 1, 101 do
      local _t = i * 2
      shada = shada
        .. ('\008\204%c\019\131\162mX\195\161f\196\006' .. mock_file_path .. 'c\161l\204%c'):format(
          _t,
          _t
        )
      jumps[(_t > #jumps + 1) and (#jumps + 1) or _t] =
        { file = '' .. mock_file_path .. 'c', line = _t }
    end
    wshada(shada)
    eq(0, exc_exec('wshada ' .. shada_fname))
    local shift = #jumps - 100
    for i = 1, 100 do
      jumps[i] = jumps[i + shift]
    end
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 8 then
        found = found + 1
        eq(jumps[found].file, v.value.f)
        eq(jumps[found].line, v.value.l)
      end
    end
    eq(100, found)
  end)
end)

describe('ShaDa changes support code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('merges changes when reading', function()
    nvim_command('edit ' .. mock_file_path .. 'c')
    nvim_command('keepjumps call setline(1, range(7))')
    wshada(
      '\011\001\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\001'
        .. '\011\004\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\002'
        .. '\011\007\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\003'
    )
    eq(0, exc_exec(sdrcmd()))
    wshada(
      '\011\001\018\131\162mX\194\161f\196\006'
        .. mock_file_path
        .. 'c\161l\001'
        .. '\011\004\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\005'
        .. '\011\008\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\004'
    )
    eq(0, exc_exec(sdrcmd()))
    eq(
      'change line  col text\n'
        .. '    5     1    0 0\n'
        .. '    4     2    0 1\n'
        .. '    3     5    0 4\n'
        .. '    2     3    0 2\n'
        .. '    1     4    0 3\n'
        .. '>',
      exec_capture('changes')
    )
  end)

  it('merges changes when writing', function()
    nvim_command('edit ' .. mock_file_path .. 'c')
    nvim_command('keepjumps call setline(1, range(7))')
    wshada(
      '\011\001\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\001'
        .. '\011\004\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\002'
        .. '\011\007\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\003'
    )
    eq(0, exc_exec(sdrcmd()))
    wshada(
      '\011\001\018\131\162mX\194\161f\196\006'
        .. mock_file_path
        .. 'c\161l\001'
        .. '\011\004\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\005'
        .. '\011\008\018\131\162mX\195\161f\196\006'
        .. mock_file_path
        .. 'c\161l\004'
    )
    eq(0, exc_exec('wshada ' .. shada_fname))
    local changes = {
      { line = 1 },
      { line = 2 },
      { line = 5 },
      { line = 3 },
      { line = 4 },
    }
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 11 and v.value.f == '' .. mock_file_path .. 'c' then
        found = found + 1
        eq(changes[found].line, v.value.l or 1)
      end
    end
    eq(#changes, found)
  end)

  it('merges JUMPLISTSIZE changes when writing', function()
    nvim_command('edit ' .. mock_file_path .. 'c')
    nvim_command('keepjumps call setline(1, range(202))')
    local changes = {}
    local shada = ''
    for i = 1, 100 do
      shada = shada
        .. ('\011%c\018\131\162mX\195\161f\196\006' .. mock_file_path .. 'c\161l%c'):format(i, i)
      changes[i] = { line = i }
    end
    wshada(shada)
    eq(0, exc_exec(sdrcmd()))
    shada = ''
    for i = 1, 101 do
      local _t = i * 2
      shada = shada
        .. ('\011\204%c\019\131\162mX\195\161f\196\006' .. mock_file_path .. 'c\161l\204%c'):format(
          _t,
          _t
        )
      changes[(_t > #changes + 1) and (#changes + 1) or _t] = { line = _t }
    end
    wshada(shada)
    eq(0, exc_exec('wshada ' .. shada_fname))
    local shift = #changes - 100
    for i = 1, 100 do
      changes[i] = changes[i + shift]
    end
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 11 and v.value.f == '' .. mock_file_path .. 'c' then
        found = found + 1
        eq(changes[found].line, v.value.l)
      end
    end
    eq(100, found)
  end)

  it('merges JUMPLISTSIZE changes when writing, with new items between old', function()
    nvim_command('edit ' .. mock_file_path .. 'c')
    nvim_command('keepjumps call setline(1, range(202))')
    local shada = ''
    for i = 1, 101 do
      local _t = i * 2
      shada = shada
        .. ('\011\204%c\019\131\162mX\195\161f\196\006' .. mock_file_path .. 'c\161l\204%c'):format(
          _t,
          _t
        )
    end
    wshada(shada)
    eq(0, exc_exec(sdrcmd()))
    shada = ''
    for i = 1, 100 do
      shada = shada
        .. ('\011%c\018\131\162mX\195\161f\196\006' .. mock_file_path .. 'c\161l%c'):format(i, i)
    end
    local changes = {}
    for i = 1, 100 do
      changes[i] = { line = i }
    end
    for i = 1, 101 do
      local _t = i * 2
      changes[(_t > #changes + 1) and (#changes + 1) or _t] = { line = _t }
    end
    wshada(shada)
    eq(0, exc_exec('wshada ' .. shada_fname))
    local shift = #changes - 100
    for i = 1, 100 do
      changes[i] = changes[i + shift]
    end
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 11 and v.value.f == '' .. mock_file_path .. 'c' then
        found = found + 1
        eq(changes[found].line, v.value.l)
      end
    end
    eq(100, found)
  end)
end)
