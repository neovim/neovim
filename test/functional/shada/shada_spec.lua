-- Other ShaDa tests
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_shada = require('test.functional.shada.testutil')
local uv = vim.uv
local paths = t.paths

local api, nvim_command, fn, eq = n.api, n.command, n.fn, t.eq
local write_file, set_session, exc_exec = t.write_file, n.set_session, n.exc_exec
local is_os = t.is_os
local skip = t.skip

local reset, clear, get_shada_rw = t_shada.reset, t_shada.clear, t_shada.get_shada_rw
local read_shada_file = t_shada.read_shada_file

local wshada, _, shada_fname, clean = get_shada_rw('Xtest-functional-shada-shada.shada')

local dirname = 'Xtest-functional-shada-shada.d'
local dirshada = dirname .. '/main.shada'

describe('ShaDa support code', function()
  before_each(reset)
  after_each(function()
    clear()
    clean()
    uv.fs_rmdir(dirname)
  end)

  it('preserves `s` item size limit with unknown entries', function()
    wshada(
      '\100\000\207\000\000\000\000\000\000\004\000\218\003\253'
        .. ('-'):rep(1024 - 3)
        .. '\100\000\207\000\000\000\000\000\000\004\001\218\003\254'
        .. ('-'):rep(1025 - 3)
    )
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 100 then
        found = found + 1
      end
    end
    eq(2, found)
    eq(0, exc_exec('set shada-=s10 shada+=s1'))
    eq(0, exc_exec('wshada ' .. shada_fname))
    found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 100 then
        found = found + 1
      end
    end
    eq(1, found)
  end)

  it('preserves `s` item size limit with instance history entries', function()
    local hist1 = ('-'):rep(1024 - 5)
    local hist2 = ('-'):rep(1025 - 5)
    nvim_command('set shada-=s10 shada+=s1')
    fn.histadd(':', hist1)
    fn.histadd(':', hist2)
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 then
        found = found + 1
        eq(hist1, v.value[2])
      end
    end
    eq(1, found)
  end)

  it('leaves .tmp.a in-place when there is error in original ShaDa', function()
    wshada('Some text file')
    eq(
      'Vim(wshada):E576: Error while reading ShaDa file: last entry specified that it occupies 109 bytes, but file ended earlier',
      exc_exec('wshada ' .. shada_fname)
    )
    eq(1, read_shada_file(shada_fname .. '.tmp.a')[1].type)
  end)

  it(
    'does not leave .tmp.a in-place when there is error in original ShaDa, but writing with bang',
    function()
      wshada('Some text file')
      eq(0, exc_exec('wshada! ' .. shada_fname))
      eq(1, read_shada_file(shada_fname)[1].type)
      eq(nil, uv.fs_stat(shada_fname .. '.tmp.a'))
    end
  )

  it('leaves .tmp.b in-place when there is error in original ShaDa and it has .tmp.a', function()
    wshada('Some text file')
    eq(
      'Vim(wshada):E576: Error while reading ShaDa file: last entry specified that it occupies 109 bytes, but file ended earlier',
      exc_exec('wshada ' .. shada_fname)
    )
    eq(
      'Vim(wshada):E576: Error while reading ShaDa file: last entry specified that it occupies 109 bytes, but file ended earlier',
      exc_exec('wshada ' .. shada_fname)
    )
    eq(1, read_shada_file(shada_fname .. '.tmp.a')[1].type)
    eq(1, read_shada_file(shada_fname .. '.tmp.b')[1].type)
  end)

  it(
    'leaves .tmp.z in-place when there is error in original ShaDa and it has .tmp.a … .tmp.x',
    function()
      wshada('Some text file')
      local i = ('a'):byte()
      while i < ('z'):byte() do
        write_file(shada_fname .. ('.tmp.%c'):format(i), 'Some text file', true)
        i = i + 1
      end
      eq(
        'Vim(wshada):E576: Error while reading ShaDa file: last entry specified that it occupies 109 bytes, but file ended earlier',
        exc_exec('wshada ' .. shada_fname)
      )
      eq(1, read_shada_file(shada_fname .. '.tmp.z')[1].type)
    end
  )

  it('errors out when there are .tmp.a … .tmp.z ShaDa files', function()
    wshada('')
    local i = ('a'):byte()
    while i <= ('z'):byte() do
      write_file(shada_fname .. ('.tmp.%c'):format(i), '', true)
      i = i + 1
    end
    eq(
      'Vim(wshada):E138: All Xtest-functional-shada-shada.shada.tmp.X files exist, cannot write ShaDa file!',
      exc_exec('wshada ' .. shada_fname)
    )
  end)

  it('reads correctly various timestamps', function()
    local msgpack = {
      '\100', -- Positive fixnum 100
      '\204\255', -- uint 8 255
      '\205\010\003', -- uint 16 2563
      '\206\255\010\030\004', -- uint 32 4278853124
      '\207\005\100\060\250\255\010\030\004', -- uint 64 388502516579048964
    }
    local s = '\100'
    local e = '\001\192'
    wshada(s .. table.concat(msgpack, e .. s) .. e)
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    local typ = vim.mpack.decode(s)
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == typ then
        found = found + 1
        eq(vim.mpack.decode(msgpack[found]), v.timestamp)
      end
    end
    eq(#msgpack, found)
  end)

  local marklike = { [7] = true, [8] = true, [10] = true, [11] = true }
  local find_file = function(fname)
    local found = {}
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if marklike[v.type] and v.value.f == fname then
        found[v.type] = (found[v.type] or 0) + 1
      elseif v.type == 9 then
        for _, b in ipairs(v.value) do
          if b.f == fname then
            found[v.type] = (found[v.type] or 0) + 1
          end
        end
      end
    end
    return found
  end

  it('correctly uses shada-r option', function()
    nvim_command('set shellslash')
    api.nvim_set_var('__home', paths.test_source_path)
    nvim_command('let $HOME = __home')
    nvim_command('unlet __home')
    nvim_command('edit ~/README.md')
    nvim_command('normal! GmAggmaAabc')
    nvim_command('undo')
    nvim_command('set shada+=%')
    nvim_command('wshada! ' .. shada_fname)
    local readme_fname = fn.resolve(paths.test_source_path) .. '/README.md'
    eq({ [7] = 2, [8] = 2, [9] = 1, [10] = 4, [11] = 1 }, find_file(readme_fname))
    nvim_command('set shada+=r~')
    nvim_command('wshada! ' .. shada_fname)
    eq({}, find_file(readme_fname))
    nvim_command('set shada-=r~')
    nvim_command('wshada! ' .. shada_fname)
    eq({ [7] = 2, [8] = 2, [9] = 1, [10] = 4, [11] = 1 }, find_file(readme_fname))
    nvim_command('set shada+=r' .. fn.escape(fn.escape(paths.test_source_path, '$~'), ' "\\,'))
    nvim_command('wshada! ' .. shada_fname)
    eq({}, find_file(readme_fname))
  end)

  it('correctly ignores case with shada-r option', function()
    nvim_command('set shellslash')
    local pwd = fn.getcwd()
    local relfname = 'абв/test'
    local fname = pwd .. '/' .. relfname
    api.nvim_set_var('__fname', fname)
    nvim_command('silent! edit `=__fname`')
    fn.setline(1, { 'a', 'b', 'c', 'd' })
    nvim_command('normal! GmAggmaAabc')
    nvim_command('undo')
    nvim_command('set shada+=%')
    nvim_command('wshada! ' .. shada_fname)
    eq({ [7] = 2, [8] = 2, [9] = 1, [10] = 4, [11] = 2 }, find_file(fname))
    nvim_command('set shada+=r' .. pwd .. '/АБВ')
    nvim_command('wshada! ' .. shada_fname)
    eq({}, find_file(fname))
  end)

  it("does not store 'nobuflisted' buffer", function()
    nvim_command('set shellslash')
    local fname = fn.getcwd() .. '/file'
    api.nvim_set_var('__fname', fname)
    nvim_command('edit `=__fname`')
    api.nvim_set_option_value('buflisted', false, {})
    nvim_command('wshada! ' .. shada_fname)
    eq({}, find_file(fname))
    -- Set 'buflisted', then check again.
    api.nvim_set_option_value('buflisted', true, {})
    nvim_command('wshada! ' .. shada_fname)
    eq({ [7] = 1, [8] = 1, [10] = 1 }, find_file(fname))
  end)

  it('is able to set &shada after &viminfo', function()
    api.nvim_set_option_value('viminfo', "'10", {})
    eq("'10", api.nvim_get_option_value('viminfo', {}))
    eq("'10", api.nvim_get_option_value('shada', {}))
    api.nvim_set_option_value('shada', '', {})
    eq('', api.nvim_get_option_value('viminfo', {}))
    eq('', api.nvim_get_option_value('shada', {}))
  end)

  it('is able to set all& after setting &shada', function()
    api.nvim_set_option_value('shada', "'10", {})
    eq("'10", api.nvim_get_option_value('viminfo', {}))
    eq("'10", api.nvim_get_option_value('shada', {}))
    nvim_command('set all&')
    eq("!,'100,<50,s10,h", api.nvim_get_option_value('viminfo', {}))
    eq("!,'100,<50,s10,h", api.nvim_get_option_value('shada', {}))
  end)

  it('is able to set &shada after &viminfo using :set', function()
    nvim_command("set viminfo='10")
    eq("'10", api.nvim_get_option_value('viminfo', {}))
    eq("'10", api.nvim_get_option_value('shada', {}))
    nvim_command('set shada=')
    eq('', api.nvim_get_option_value('viminfo', {}))
    eq('', api.nvim_get_option_value('shada', {}))
  end)

  it('setting &shada gives proper error message on missing number', function()
    eq([[Vim(set):E526: Missing number after <">: shada="]], exc_exec([[set shada=\"]]))
    for _, c in ipairs({ "'", '/', ':', '<', '@', 's' }) do
      eq(
        ([[Vim(set):E526: Missing number after <%s>: shada=%s]]):format(c, c),
        exc_exec(([[set shada=%s]]):format(c))
      )
    end
  end)

  it('":wshada/:rshada [filename]" works when shadafile=NONE', function()
    nvim_command('set shadafile=NONE')
    nvim_command('wshada ' .. shada_fname)
    eq(1, read_shada_file(shada_fname)[1].type)

    wshada('Some text file')
    eq(
      'Vim(rshada):E576: Error while reading ShaDa file: last entry specified that it occupies 109 bytes, but file ended earlier',
      t.pcall_err(n.command, 'rshada ' .. shada_fname)
    )
  end)

  it(':wshada/:rshada without arguments is no-op when shadafile=NONE', function()
    nvim_command('set shadafile=NONE')
    nvim_command('wshada')
    nvim_command('rshada')
  end)

  it('does not crash when ShaDa file directory is not writable', function()
    skip(is_os('win'))

    fn.mkdir(dirname, '', '0')
    eq(0, fn.filewritable(dirname))
    reset { shadafile = dirshada, args = { '--cmd', 'set shada=' } }
    api.nvim_set_option_value('shada', "'10", {})
    eq(
      'Vim(wshada):E886: System error while opening ShaDa file '
        .. 'Xtest-functional-shada-shada.d/main.shada for reading to merge '
        .. 'before writing it: permission denied',
      exc_exec('wshada')
    )
    api.nvim_set_option_value('shada', '', {})
  end)
end)

describe('ShaDa support code', function()
  it('does not write NONE file', function()
    local session = n.new_session(false, {
      merge = false,
      args = { '-u', 'NONE', '-i', 'NONE', '--embed', '--headless', '--cmd', 'qall' },
    })
    session:close()
    eq(nil, uv.fs_stat('NONE'))
    eq(nil, uv.fs_stat('NONE.tmp.a'))
  end)

  it('does not read NONE file', function()
    write_file('NONE', '\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    local session = n.new_session(
      false,
      { merge = false, args = { '-u', 'NONE', '-i', 'NONE', '--embed', '--headless' } }
    )
    set_session(session)
    eq('', fn.getreg('a'))
    session:close()
    os.remove('NONE')
  end)
end)
