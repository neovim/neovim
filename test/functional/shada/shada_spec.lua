-- Other ShaDa tests
local helpers = require('test.functional.helpers')(after_each)
local meths, nvim_command, funcs, eq =
  helpers.meths, helpers.command, helpers.funcs, helpers.eq
local write_file, spawn, set_session, nvim_prog, exc_exec =
  helpers.write_file, helpers.spawn, helpers.set_session, helpers.nvim_prog,
  helpers.exc_exec

local lfs = require('lfs')
local paths = require('test.config.paths')

local mpack = require('mpack')

local shada_helpers = require('test.functional.shada.helpers')
local reset, clear, get_shada_rw =
  shada_helpers.reset, shada_helpers.clear, shada_helpers.get_shada_rw
local read_shada_file = shada_helpers.read_shada_file

local wshada, _, shada_fname, clean =
  get_shada_rw('Xtest-functional-shada-shada.shada')

local dirname = 'Xtest-functional-shada-shada.d'
local dirshada = dirname .. '/main.shada'

describe('ShaDa support code', function()
  before_each(reset)
  after_each(function()
    clear()
    clean()
    lfs.rmdir(dirname)
  end)

  it('preserves `s` item size limit with unknown entries', function()
    wshada('\100\000\207\000\000\000\000\000\000\004\000\218\003\253' .. ('-'):rep(1024 - 3)
           .. '\100\000\207\000\000\000\000\000\000\004\001\218\003\254' .. ('-'):rep(1025 - 3))
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
    funcs.histadd(':', hist1)
    funcs.histadd(':', hist2)
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
    eq('Vim(wshada):E576: Error while reading ShaDa file: last entry specified that it occupies 109 bytes, but file ended earlier', exc_exec('wshada ' .. shada_fname))
    eq(1, read_shada_file(shada_fname .. '.tmp.a')[1].type)
  end)

  it('does not leave .tmp.a in-place when there is error in original ShaDa, but writing with bang', function()
    wshada('Some text file')
    eq(0, exc_exec('wshada! ' .. shada_fname))
    eq(1, read_shada_file(shada_fname)[1].type)
    eq(nil, lfs.attributes(shada_fname .. '.tmp.a'))
  end)

  it('leaves .tmp.b in-place when there is error in original ShaDa and it has .tmp.a', function()
    wshada('Some text file')
    eq('Vim(wshada):E576: Error while reading ShaDa file: last entry specified that it occupies 109 bytes, but file ended earlier', exc_exec('wshada ' .. shada_fname))
    eq('Vim(wshada):E576: Error while reading ShaDa file: last entry specified that it occupies 109 bytes, but file ended earlier', exc_exec('wshada ' .. shada_fname))
    eq(1, read_shada_file(shada_fname .. '.tmp.a')[1].type)
    eq(1, read_shada_file(shada_fname .. '.tmp.b')[1].type)
  end)

  it('leaves .tmp.z in-place when there is error in original ShaDa and it has .tmp.a … .tmp.x', function()
    wshada('Some text file')
    local i = ('a'):byte()
    while i < ('z'):byte() do
      write_file(shada_fname .. ('.tmp.%c'):format(i), 'Some text file', true)
      i = i + 1
    end
    eq('Vim(wshada):E576: Error while reading ShaDa file: last entry specified that it occupies 109 bytes, but file ended earlier', exc_exec('wshada ' .. shada_fname))
    eq(1, read_shada_file(shada_fname .. '.tmp.z')[1].type)
  end)

  it('errors out when there are .tmp.a … .tmp.z ShaDa files', function()
    wshada('')
    local i = ('a'):byte()
    while i <= ('z'):byte() do
      write_file(shada_fname .. ('.tmp.%c'):format(i), '', true)
      i = i + 1
    end
    eq('Vim(wshada):E138: All Xtest-functional-shada-shada.shada.tmp.X files exist, cannot write ShaDa file!', exc_exec('wshada ' .. shada_fname))
  end)

  it('reads correctly various timestamps', function()
    local msgpack = {
      '\100',  -- Positive fixnum 100
      '\204\255',  -- uint 8 255
      '\205\010\003',  -- uint 16 2563
      '\206\255\010\030\004',  -- uint 32 4278853124
      '\207\005\100\060\250\255\010\030\004',  -- uint 64 388502516579048964
    }
    local s = '\100'
    local e = '\001\192'
    wshada(s .. table.concat(msgpack, e .. s) .. e)
    eq(0, exc_exec('wshada ' .. shada_fname))
    local found = 0
    local typ = mpack.unpack(s)
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == typ then
        found = found + 1
        eq(mpack.unpack(msgpack[found]), v.timestamp)
      end
    end
    eq(#msgpack, found)
  end)

  it('does not write NONE file', function()
    local session = spawn({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--embed',
                           '--headless', '--cmd', 'qall'}, true)
    session:close()
    eq(nil, lfs.attributes('NONE'))
    eq(nil, lfs.attributes('NONE.tmp.a'))
  end)

  it('does not read NONE file', function()
    write_file('NONE', '\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    local session = spawn({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--embed',
                           '--headless'}, true)
    set_session(session)
    eq('', funcs.getreg('a'))
    session:close()
    os.remove('NONE')
  end)

  local marklike = {[7]=true, [8]=true, [10]=true, [11]=true}
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
    meths.set_var('__home', paths.test_source_path)
    nvim_command('let $HOME = __home')
    nvim_command('unlet __home')
    nvim_command('edit ~/README.md')
    nvim_command('normal! GmAggmaAabc')
    nvim_command('undo')
    nvim_command('set shada+=%')
    nvim_command('wshada! ' .. shada_fname)
    local readme_fname = funcs.resolve(paths.test_source_path) .. '/README.md'
    eq({[7]=2, [8]=2, [9]=1, [10]=4, [11]=1}, find_file(readme_fname))
    nvim_command('set shada+=r~')
    nvim_command('wshada! ' .. shada_fname)
    eq({}, find_file(readme_fname))
    nvim_command('set shada-=r~')
    nvim_command('wshada! ' .. shada_fname)
    eq({[7]=2, [8]=2, [9]=1, [10]=4, [11]=1}, find_file(readme_fname))
    nvim_command('set shada+=r' .. funcs.escape(
      funcs.escape(paths.test_source_path, '$~'), ' "\\,'))
    nvim_command('wshada! ' .. shada_fname)
    eq({}, find_file(readme_fname))
  end)

  it('correctly ignores case with shada-r option', function()
    nvim_command('set shellslash')
    local pwd = funcs.getcwd()
    local relfname = 'абв/test'
    local fname = pwd .. '/' .. relfname
    meths.set_var('__fname', fname)
    nvim_command('silent! edit `=__fname`')
    funcs.setline(1, {'a', 'b', 'c', 'd'})
    nvim_command('normal! GmAggmaAabc')
    nvim_command('undo')
    nvim_command('set shada+=%')
    nvim_command('wshada! ' .. shada_fname)
    eq({[7]=2, [8]=2, [9]=1, [10]=4, [11]=2}, find_file(fname))
    nvim_command('set shada+=r' .. pwd .. '/АБВ')
    nvim_command('wshada! ' .. shada_fname)
    eq({}, find_file(fname))
  end)

  it('is able to set &shada after &viminfo', function()
    meths.set_option('viminfo', '\'10')
    eq('\'10', meths.get_option('viminfo'))
    eq('\'10', meths.get_option('shada'))
    meths.set_option('shada', '')
    eq('', meths.get_option('viminfo'))
    eq('', meths.get_option('shada'))
  end)

  it('is able to set all& after setting &shada', function()
    meths.set_option('shada', '\'10')
    eq('\'10', meths.get_option('viminfo'))
    eq('\'10', meths.get_option('shada'))
    nvim_command('set all&')
    eq('!,\'100,<50,s10,h', meths.get_option('viminfo'))
    eq('!,\'100,<50,s10,h', meths.get_option('shada'))
  end)

  it('is able to set &shada after &viminfo using :set', function()
    nvim_command('set viminfo=\'10')
    eq('\'10', meths.get_option('viminfo'))
    eq('\'10', meths.get_option('shada'))
    nvim_command('set shada=')
    eq('', meths.get_option('viminfo'))
    eq('', meths.get_option('shada'))
  end)

  it('does not crash when ShaDa file directory is not writable', function()
    if helpers.pending_win32(pending) then return end

    funcs.mkdir(dirname, '', 0)
    eq(0, funcs.filewritable(dirname))
    reset{shadafile=dirshada, args={'--cmd', 'set shada='}}
    meths.set_option('shada', '\'10')
    eq('Vim(wshada):E886: System error while opening ShaDa file '
       .. 'Xtest-functional-shada-shada.d/main.shada for reading to merge '
       .. 'before writing it: permission denied',
       exc_exec('wshada'))
    meths.set_option('shada', '')
  end)
end)
