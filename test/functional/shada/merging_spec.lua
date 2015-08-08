-- ShaDa merging data support
local helpers = require('test.functional.helpers')
local nvim, nvim_window, nvim_curwin, nvim_command, nvim_feed, nvim_eval, eq =
  helpers.nvim, helpers.window, helpers.curwin, helpers.command, helpers.feed,
  helpers.eval, helpers.eq

local shada_helpers = require('test.functional.shada.helpers')
local reset, set_additional_cmd, clear, exc_exec, get_shada_rw =
  shada_helpers.reset, shada_helpers.set_additional_cmd,
  shada_helpers.clear, shada_helpers.exc_exec,
  shada_helpers.get_shada_rw
local read_shada_file = shada_helpers.read_shada_file

local wshada, sdrcmd, shada_fname =
  get_shada_rw('Xtest-functional-shada-merging.shada')

describe('ShaDa history merging code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('takes item with greater timestamp from NeoVim instance when reading',
  function()
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

  it('takes item with equal timestamp from NeoVim instance when reading',
  function()
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

  it('takes item with greater timestamp from ShaDa when reading',
  function()
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

  it('takes item with greater timestamp from NeoVim instance when writing',
  function()
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

  it('takes item with equal timestamp from NeoVim instance when writing',
  function()
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

  it('takes item with greater timestamp from ShaDa when writing',
  function()
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

  it('correctly reads history items with messed up timestamps',
  function()
    wshada('\004\010\009\147\000\196\002ab\196\001a'
           .. '\004\010\009\147\000\196\002ac\196\001a'
           .. '\004\005\009\147\000\196\002ad\196\001a'
           .. '\004\100\009\147\000\196\002ae\196\001a'
           .. '\004\090\009\147\000\196\002af\196\001a'
          )
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    eq(0, exc_exec('wshada! ' .. shada_fname))
    local items = {'ad', 'ab', 'ac', 'af', 'ae'}
    for i, v in ipairs(items) do
      eq(v, nvim_eval(('histget(":", %i)'):format(i)))
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

  it('correctly reorders history items with messed up timestamps when writing',
  function()
    wshada('\004\010\009\147\000\196\002ab\196\001a'
           .. '\004\010\009\147\000\196\002ac\196\001a'
           .. '\004\005\009\147\000\196\002ad\196\001a'
           .. '\004\100\009\147\000\196\002ae\196\001a'
           .. '\004\090\009\147\000\196\002af\196\001a'
          )
    eq(0, exc_exec('wshada ' .. shada_fname))
    local items = {'ad', 'ab', 'ac', 'af', 'ae'}
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

  it('uses last search pattern with gt timestamp from instance when reading',
  function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162sX\194\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', nvim_eval('@/'))
  end)

  it('uses last search pattern with gt tstamp from file when reading with bang',
  function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162sX\194\162sp\196\001?')
    eq(0, exc_exec(sdrcmd(true)))
    eq('?', nvim_eval('@/'))
  end)

  it('uses last search pattern with eq timestamp from instance when reading',
  function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\001\011\130\162sX\194\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', nvim_eval('@/'))
  end)

  it('uses last search pattern with gt timestamp from file when reading',
  function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\002\011\130\162sX\194\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('?', nvim_eval('@/'))
  end)

  it('uses last search pattern with gt timestamp from instance when writing',
  function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162sX\194\162sp\196\001?')
    eq('-', nvim_eval('@/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last search pattern with eq timestamp from instance when writing',
  function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\001\011\130\162sX\194\162sp\196\001?')
    eq('-', nvim_eval('@/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last search pattern with gt timestamp from file when writing',
  function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\002\011\130\162sX\194\162sp\196\001?')
    eq('-', nvim_eval('@/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '?' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last s/ pattern with gt timestamp from instance when reading',
  function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162ss\195\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', nvim_eval('@/'))
  end)

  it('uses last s/ pattern with gt timestamp from file when reading with !',
  function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162ss\195\162sp\196\001?')
    eq(0, exc_exec(sdrcmd(true)))
    eq('?', nvim_eval('@/'))
  end)

  it('uses last s/ pattern with eq timestamp from instance when reading',
  function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\001\011\130\162ss\195\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', nvim_eval('@/'))
  end)

  it('uses last s/ pattern with gt timestamp from file when reading',
  function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\002\011\130\162ss\195\162sp\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('?', nvim_eval('@/'))
  end)

  it('uses last s/ pattern with gt timestamp from instance when writing',
  function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\000\011\130\162ss\195\162sp\196\001?')
    eq('-', nvim_eval('@/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last s/ pattern with eq timestamp from instance when writing',
  function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\001\011\130\162ss\195\162sp\196\001?')
    eq('-', nvim_eval('@/'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.sp == '-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last s/ pattern with gt timestamp from file when writing',
  function()
    wshada('\002\001\011\130\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\002\002\011\130\162ss\195\162sp\196\001?')
    eq('-', nvim_eval('@/'))
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

  it('uses last replacement with gt timestamp from instance when reading',
  function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\000\004\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('s/.*/~')
    eq('-', nvim_eval('getline(".")'))
    nvim_command('bwipeout!')
  end)

  it('uses last replacement with gt timestamp from file when reading with bang',
  function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\000\004\145\196\001?')
    eq(0, exc_exec(sdrcmd(true)))
    nvim_command('s/.*/~')
    eq('?', nvim_eval('getline(".")'))
    nvim_command('bwipeout!')
  end)

  it('uses last replacement with eq timestamp from instance when reading',
  function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\001\004\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('s/.*/~')
    eq('-', nvim_eval('getline(".")'))
    nvim_command('bwipeout!')
  end)

  it('uses last replacement with gt timestamp from file when reading',
  function()
    wshada('\003\001\004\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\003\002\004\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('s/.*/~')
    eq('?', nvim_eval('getline(".")'))
    nvim_command('bwipeout!')
  end)

  it('uses last replacement with gt timestamp from instance when writing',
  function()
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

  it('uses last replacement with eq timestamp from instance when writing',
  function()
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

  it('uses last replacement with gt timestamp from file when writing',
  function()
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

  it('uses last A mark with gt timestamp from instance when reading',
  function()
    wshada('\007\001\018\131\162mX\195\161f\196\006/a/b/-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\000\018\131\162mX\195\161f\196\006/a/b/?\161nA')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `A')
    eq('-', nvim_eval('fnamemodify(bufname("%"), ":t")'))
  end)

  it('uses last A mark with gt timestamp from file when reading with !',
  function()
    wshada('\007\001\018\131\162mX\195\161f\196\006/a/b/-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\000\018\131\162mX\195\161f\196\006/a/b/?\161nA')
    eq(0, exc_exec(sdrcmd(true)))
    nvim_command('normal! `A')
    eq('?', nvim_eval('fnamemodify(bufname("%"), ":t")'))
  end)

  it('uses last A mark with eq timestamp from instance when reading',
  function()
    wshada('\007\001\018\131\162mX\195\161f\196\006/a/b/-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\001\018\131\162mX\195\161f\196\006/a/b/?\161nA')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `A')
    eq('-', nvim_eval('fnamemodify(bufname("%"), ":t")'))
  end)

  it('uses last A mark with gt timestamp from file when reading',
  function()
    wshada('\007\001\018\131\162mX\195\161f\196\006/a/b/-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\002\018\131\162mX\195\161f\196\006/a/b/?\161nA')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `A')
    eq('?', nvim_eval('fnamemodify(bufname("%"), ":t")'))
  end)

  it('uses last A mark with gt timestamp from instance when writing',
  function()
    wshada('\007\001\018\131\162mX\195\161f\196\006/a/b/-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\000\018\131\162mX\195\161f\196\006/a/b/?\161nA')
    nvim_command('normal! `A')
    eq('-', nvim_eval('fnamemodify(bufname("%"), ":t")'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 and v.value.f == '/a/b/-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last A mark with eq timestamp from instance when writing',
  function()
    wshada('\007\001\018\131\162mX\195\161f\196\006/a/b/-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\001\018\131\162mX\195\161f\196\006/a/b/?\161nA')
    nvim_command('normal! `A')
    eq('-', nvim_eval('fnamemodify(bufname("%"), ":t")'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 and v.value.f == '/a/b/-' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last A mark with gt timestamp from file when writing',
  function()
    wshada('\007\001\018\131\162mX\195\161f\196\006/a/b/-\161nA')
    eq(0, exc_exec(sdrcmd()))
    wshada('\007\002\018\131\162mX\195\161f\196\006/a/b/?\161nA')
    nvim_command('normal! `A')
    eq('-', nvim_eval('fnamemodify(bufname("%"), ":t")'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 7 and v.value.f == '/a/b/?' then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last a mark with gt timestamp from instance when reading',
  function()
    nvim_command('edit /a/b/-')
    nvim_eval('setline(1, ["-", "?"])')
    wshada('\010\001\017\131\161l\001\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\000\017\131\161l\002\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `a')
    eq('-', nvim_eval('getline(".")'))
  end)

  it('uses last a mark with gt timestamp from file when reading with !',
  function()
    nvim_command('edit /a/b/-')
    nvim_eval('setline(1, ["-", "?"])')
    wshada('\010\001\017\131\161l\001\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\000\017\131\161l\002\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd(true)))
    nvim_command('normal! `a')
    eq('?', nvim_eval('getline(".")'))
  end)

  it('uses last a mark with eq timestamp from instance when reading',
  function()
    nvim_command('edit /a/b/-')
    nvim_eval('setline(1, ["-", "?"])')
    wshada('\010\001\017\131\161l\001\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\001\017\131\161l\002\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `a')
    eq('-', nvim_eval('getline(".")'))
  end)

  it('uses last a mark with gt timestamp from file when reading',
  function()
    nvim_command('edit /a/b/-')
    nvim_eval('setline(1, ["-", "?"])')
    wshada('\010\001\017\131\161l\001\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\002\017\131\161l\002\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('normal! `a')
    eq('?', nvim_eval('getline(".")'))
  end)

  it('uses last a mark with gt timestamp from instance when writing',
  function()
    nvim_command('edit /a/b/-')
    nvim_eval('setline(1, ["-", "?"])')
    wshada('\010\001\017\131\161l\001\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\000\017\131\161l\002\161f\196\006/a/b/-\161na')
    nvim_command('normal! `a')
    eq('-', nvim_eval('getline(".")'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 10 and v.value.f == '/a/b/-' and v.value.n == ('a'):byte() then
        eq(true, v.value.l == 1 or v.value.l == nil)
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last a mark with eq timestamp from instance when writing',
  function()
    nvim_command('edit /a/b/-')
    nvim_eval('setline(1, ["-", "?"])')
    wshada('\010\001\017\131\161l\001\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\001\017\131\161l\002\161f\196\006/a/b/-\161na')
    nvim_command('normal! `a')
    eq('-', nvim_eval('getline(".")'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 10 and v.value.f == '/a/b/-' and v.value.n == ('a'):byte() then
        eq(true, v.value.l == 1 or v.value.l == nil)
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last a mark with gt timestamp from file when writing',
  function()
    nvim_command('edit /a/b/-')
    nvim_eval('setline(1, ["-", "?"])')
    wshada('\010\001\017\131\161l\001\161f\196\006/a/b/-\161na')
    eq(0, exc_exec(sdrcmd()))
    wshada('\010\002\017\131\161l\002\161f\196\006/a/b/-\161na')
    nvim_command('normal! `a')
    eq('-', nvim_eval('fnamemodify(bufname("%"), ":t")'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 10 and v.value.f == '/a/b/-' and v.value.n == ('a'):byte() then
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

  it('uses last a register with gt timestamp from instance when reading',
  function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\000\015\131\161na\162rX\194\162rc\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', nvim_eval('@a'))
  end)

  it('uses last a register with gt timestamp from file when reading with !',
  function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\000\015\131\161na\162rX\194\162rc\145\196\001?')
    eq(0, exc_exec(sdrcmd(true)))
    eq('?', nvim_eval('@a'))
  end)

  it('uses last a register with eq timestamp from instance when reading',
  function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('-', nvim_eval('@a'))
  end)

  it('uses last a register with gt timestamp from file when reading',
  function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\002\015\131\161na\162rX\194\162rc\145\196\001?')
    eq(0, exc_exec(sdrcmd()))
    eq('?', nvim_eval('@a'))
  end)

  it('uses last a register with gt timestamp from instance when writing',
  function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\000\015\131\161na\162rX\194\162rc\145\196\001?')
    eq('-', nvim_eval('@a'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 5 and v.value.n == ('a'):byte() then
        eq({'-'}, v.value.rc)
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last a register with eq timestamp from instance when writing',
  function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001?')
    eq('-', nvim_eval('@a'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 5 and v.value.n == ('a'):byte() then
        eq({'-'}, v.value.rc)
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('uses last a register with gt timestamp from file when writing',
  function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    wshada('\005\002\015\131\161na\162rX\194\162rc\145\196\001?')
    eq('-', nvim_eval('@a'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 5 and v.value.n == ('a'):byte() then
        eq({'?'}, v.value.rc)
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
    wshada('\008\001\018\131\162mX\195\161f\196\006/a/b/c\161l\002'
           .. '\008\004\018\131\162mX\195\161f\196\006/a/b/d\161l\002'
           .. '\008\007\018\131\162mX\195\161f\196\006/a/b/e\161l\002')
    eq(0, exc_exec(sdrcmd()))
    wshada('\008\001\018\131\162mX\195\161f\196\006/a/b/c\161l\002'
           .. '\008\004\018\131\162mX\195\161f\196\006/a/b/d\161l\003'
           .. '\008\007\018\131\162mX\195\161f\196\006/a/b/f\161l\002')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('redir => g:jumps | jumps | redir END')
    eq('', nvim_eval('bufname("%")'))
    eq('\n'
       .. ' jump line  col file/text\n'
       .. '   5     2    0 /a/b/c\n'
       .. '   4     3    0 /a/b/d\n'
       .. '   3     2    0 /a/b/d\n'
       .. '   2     2    0 /a/b/f\n'
       .. '   1     2    0 /a/b/e\n'
       .. '>  0     1    0 ', nvim_eval('g:jumps'))
  end)

  it('merges jumps when writing', function()
    wshada('\008\001\018\131\162mX\195\161f\196\006/a/b/c\161l\002'
           .. '\008\004\018\131\162mX\195\161f\196\006/a/b/d\161l\002'
           .. '\008\007\018\131\162mX\195\161f\196\006/a/b/e\161l\002')
    eq(0, exc_exec(sdrcmd()))
    wshada('\008\001\018\131\162mX\195\161f\196\006/a/b/c\161l\002'
           .. '\008\004\018\131\162mX\195\161f\196\006/a/b/d\161l\003'
           .. '\008\007\018\131\162mX\195\161f\196\006/a/b/f\161l\002')
    eq(0, exc_exec('wshada ' .. shada_fname))
    local jumps = {
      {file='/a/b/c', line=2},
      {file='/a/b/d', line=3},
      {file='/a/b/d', line=2},
      {file='/a/b/f', line=2},
      {file='/a/b/e', line=2},
    }
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 8 then
        found = found + 1
        eq(jumps[found].file, v.value.f)
        eq(jumps[found].line, v.value.l)
      end
    end
    eq(found, #jumps)
  end)
end)

describe('ShaDa changes support code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('merges changes when reading', function()
    nvim_command('edit /a/b/c')
    nvim_command('keepjumps call setline(1, range(7))')
    wshada('\011\001\018\131\162mX\195\161f\196\006/a/b/c\161l\001'
           .. '\011\004\018\131\162mX\195\161f\196\006/a/b/c\161l\002'
           .. '\011\007\018\131\162mX\195\161f\196\006/a/b/c\161l\003')
    eq(0, exc_exec(sdrcmd()))
    wshada('\011\001\018\131\162mX\194\161f\196\006/a/b/c\161l\001'
           .. '\011\004\018\131\162mX\195\161f\196\006/a/b/c\161l\005'
           .. '\011\008\018\131\162mX\195\161f\196\006/a/b/c\161l\004')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('redir => g:changes | changes | redir END')
    eq('\n'
       .. 'change line  col text\n'
       .. '    5     1    0 0\n'
       .. '    4     2    0 1\n'
       .. '    3     5    0 4\n'
       .. '    2     3    0 2\n'
       .. '    1     4    0 3\n'
       .. '>', nvim_eval('g:changes'))
  end)

  it('merges changes when writing', function()
    nvim_command('edit /a/b/c')
    nvim_command('keepjumps call setline(1, range(7))')
    wshada('\011\001\018\131\162mX\195\161f\196\006/a/b/c\161l\001'
           .. '\011\004\018\131\162mX\195\161f\196\006/a/b/c\161l\002'
           .. '\011\007\018\131\162mX\195\161f\196\006/a/b/c\161l\003')
    eq(0, exc_exec(sdrcmd()))
    wshada('\011\001\018\131\162mX\194\161f\196\006/a/b/c\161l\001'
           .. '\011\004\018\131\162mX\195\161f\196\006/a/b/c\161l\005'
           .. '\011\008\018\131\162mX\195\161f\196\006/a/b/c\161l\004')
    eq(0, exc_exec('wshada ' .. shada_fname))
    local changes = {
      {line=1},
      {line=2},
      {line=5},
      {line=3},
      {line=4},
    }
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 11 and v.value.f == '/a/b/c' then
        found = found + 1
        eq(changes[found].line, v.value.l or 1)
      end
    end
    eq(found, #changes)
  end)
end)
