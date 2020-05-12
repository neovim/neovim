-- ShaDa compatibility support
local helpers = require('test.functional.helpers')(after_each)
local nvim_command, funcs, eq = helpers.command, helpers.funcs, helpers.eq
local exc_exec = helpers.exc_exec

local shada_helpers = require('test.functional.shada.helpers')
local reset, clear, get_shada_rw = shada_helpers.reset, shada_helpers.clear,
  shada_helpers.get_shada_rw
local read_shada_file = shada_helpers.read_shada_file

local wshada, sdrcmd, shada_fname = get_shada_rw('Xtest-functional-shada-compatibility.shada')

local mock_file_path = '/a/b/'
local mock_file_path2 = '/d/e/'
if helpers.iswin() then
  mock_file_path = 'C:/a/'
  mock_file_path2 = 'C:/d/'
end

describe('ShaDa forward compatibility support code', function()
  before_each(reset)
  after_each(function()
    clear()
    os.remove(shada_fname)
  end)

  it('works with search pattern item with BOOL unknown (sX) key value', function()
    wshada('\002\001\011\130\162sX\194\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('wshada ' .. shada_fname)
    local found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and not v.value.ss then
        eq(false, v.value.sX)
        found = true
      end
    end
    eq(true, found)
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('silent! /---/')
    nvim_command('wshada ' .. shada_fname)
    found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and not v.value.ss then
        eq(nil, v.value.sX)
        found = true
      end
    end
    eq(true, found)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada! ' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)

  it('works with s/search pattern item with BOOL unknown (sX) key value', function()
    wshada('\002\001\015\131\162sX\194\162ss\195\162sp\196\001-')
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('wshada ' .. shada_fname)
    local found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.ss then
        eq(false, v.value.sX)
        found = true
      end
    end
    eq(true, found)
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('silent! s/--/---/ge')
    nvim_command('wshada ' .. shada_fname)
    found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 2 and v.value.ss then
        eq(nil, v.value.sX)
        found = true
      end
    end
    eq(true, found)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada!' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)

  it('works with replacement item with BOOL additional value in list', function()
    wshada('\003\000\005\146\196\001-\194')
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('wshada ' .. shada_fname)
    local found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 3 then
        eq(2, #v.value)
        eq(false, v.value[2])
        found = true
      end
    end
    eq(true, found)
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('silent! s/--/---/ge')
    nvim_command('wshada ' .. shada_fname)
    found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 3 then
        eq(1, #v.value)
        found = true
      end
    end
    eq(true, found)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada!' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)

  for _, v in ipairs({{name='global mark', mpack='\007\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. 'c\161nA'},
                      {name='jump', mpack='\008\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. 'c\161l\002'},
                      {name='local mark', mpack='\010\001\018\131\162mX\195\161f\196\006' .. mock_file_path .. 'c\161na'},
                      {name='change', mpack='\011\001\015\130\162mX\195\161f\196\006' .. mock_file_path .. 'c'},
                     }) do
    it('works with ' .. v.name .. ' item with BOOL unknown (mX) key value', function()
      nvim_command('silent noautocmd edit ' .. mock_file_path .. 'c')
      eq('' .. mock_file_path .. 'c', funcs.bufname('%'))
      funcs.setline('.', {'1', '2', '3'})
      wshada(v.mpack)
      eq(0, exc_exec(sdrcmd(true)))
      os.remove(shada_fname)
      nvim_command('wshada ' .. shada_fname)
      local found = false
      for _, subv in ipairs(read_shada_file(shada_fname)) do
        if subv.type == v.mpack:byte() then
          if subv.value.mX == true then
            found = true
          end
        end
      end
      eq(true, found)
      eq(0, exc_exec(sdrcmd()))
      nvim_command('bwipeout!')
      funcs.setpos('\'A', {0, 1, 1, 0})
      os.remove(shada_fname)
      nvim_command('wshada ' .. shada_fname)
      found = false
      for _, subv in ipairs(read_shada_file(shada_fname)) do
        if subv.type == v.mpack:byte() then
          if subv.value.mX == true then
            found = true
          end
        end
      end
      eq(false, found)
      funcs.garbagecollect(1)
      funcs.garbagecollect(1)
      nvim_command('rshada!' .. shada_fname)
      funcs.garbagecollect(1)
      funcs.garbagecollect(1)
    end)

    if v.name == 'global mark' or v.name == 'local mark' then
      it('works with ' .. v.name .. ' item with <C-a> name', function()
        nvim_command('silent noautocmd edit ' .. mock_file_path .. 'c')
        eq('' .. mock_file_path .. 'c', funcs.bufname('%'))
        funcs.setline('.', {'1', '2', '3'})
        wshada(v.mpack:gsub('n.$', 'n\001')
               .. v.mpack:gsub('n.$', 'n\002')
               .. v.mpack:gsub('n.$', 'n\003'):gsub('' .. mock_file_path .. 'c', '' .. mock_file_path2 .. 'f'))
        eq(0, exc_exec(sdrcmd(true)))
        nvim_command('wshada ' .. shada_fname)
        local found = 0
        for i, subv in ipairs(read_shada_file(shada_fname)) do
          if i == 1 then
            eq(1, subv.type)
          end
          if subv.type == v.mpack:byte() then
            if subv.value.mX == true and subv.value.n <= 3 then
              found = found + 1
            end
          end
        end
        eq(3, found)
        nvim_command('wshada! ' .. shada_fname)
        found = 0
        for i, subv in ipairs(read_shada_file(shada_fname)) do
          if i == 1 then
            eq(1, subv.type)
          end
          if subv.type == v.mpack:byte() then
            if subv.value.mX == true and subv.value.n <= 3 then
              found = found + 1
            end
          end
        end
        eq(0, found)
        funcs.garbagecollect(1)
        funcs.garbagecollect(1)
        nvim_command('rshada!' .. shada_fname)
        funcs.garbagecollect(1)
        funcs.garbagecollect(1)
      end)
    end
  end

  it('works with register item with BOOL unknown (rX) key', function()
    wshada('\005\001\015\131\161na\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('wshada ' .. shada_fname)
    local found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 5 and v.value.rX == false then
        found = true
      end
    end
    eq(true, found)
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('let @a = "Test"')
    nvim_command('wshada ' .. shada_fname)
    found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 5 and v.value.rX == false then
        found = true
      end
    end
    eq(false, found)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada!' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)

  it('works with register item with <C-a> name', function()
    wshada('\005\001\015\131\161n\001\162rX\194\162rc\145\196\001-')
    eq(0, exc_exec(sdrcmd(true)))
    nvim_command('wshada ' .. shada_fname)
    local found = 0
    for i, v in ipairs(read_shada_file(shada_fname)) do
      if i == 1 then
        eq(1, v.type)
      end
      if v.type == 5 then
        if v.value.rX == false and v.value.n == 1 then
          found = found + 1
        end
      end
    end
    eq(1, found)
    nvim_command('wshada! ' .. shada_fname)
    found = 0
    for i, v in ipairs(read_shada_file(shada_fname)) do
      if i == 1 then
        eq(1, v.type)
      end
      if v.type == 5 then
        if v.value.rX == false and v.value.n == 1 then
          found = found + 1
        end
      end
    end
    eq(0, found)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada!' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)

  it('works with register item with type 10', function()
    wshada('\005\001\019\132\161na\162rX\194\162rc\145\196\001-\162rt\010')
    eq(0, exc_exec(sdrcmd(true)))
    eq({}, funcs.getreg('a', 1, 1))
    eq('', funcs.getregtype('a'))
    nvim_command('wshada ' .. shada_fname)
    local found = 0
    for i, v in ipairs(read_shada_file(shada_fname)) do
      if i == 1 then
        eq(1, v.type)
      end
      if v.type == 5 then
        if v.value.rX == false and v.value.rt == 10 then
          found = found + 1
        end
      end
    end
    eq(1, found)
    nvim_command('wshada! ' .. shada_fname)
    found = 0
    for i, v in ipairs(read_shada_file(shada_fname)) do
      if i == 1 then
        eq(1, v.type)
      end
      if v.type == 5 then
        if v.value.rX == false and v.value.rt == 10 then
          found = found + 1
        end
      end
    end
    eq(0, found)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada!' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)

  it('works with buffer list item with BOOL unknown (bX) key', function()
    nvim_command('set shada+=%')
    wshada('\009\000\016\145\130\161f\196\006' .. mock_file_path .. 'c\162bX\195')
    eq(0, exc_exec(sdrcmd()))
    eq(2, funcs.bufnr('$'))
    eq('' .. mock_file_path .. 'c', funcs.bufname(2))
    os.remove(shada_fname)
    nvim_command('wshada ' .. shada_fname)
    local found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 9 and #v.value == 1 and v.value[1].bX == true then
        found = true
      end
    end
    eq(true, found)
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('buffer 2')
    nvim_command('edit!')
    nvim_command('wshada ' .. shada_fname)
    found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 5 and v.value.rX == false then
        found = true
      end
    end
    eq(false, found)
    nvim_command('bwipeout!')
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada!' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)

  it('works with history item with BOOL additional value in list', function()
    wshada('\004\000\006\147\000\196\001-\194')
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    nvim_command('wshada ' .. shada_fname)
    local found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 and v.value[2] == '-' then
        eq(false, v.value[3])
        eq(3, #v.value)
        found = true
      end
    end
    eq(true, found)
    eq(0, exc_exec(sdrcmd()))
    os.remove(shada_fname)
    funcs.histadd(':', '--')
    funcs.histadd(':', '-')
    nvim_command('wshada ' .. shada_fname)
    found = false
    for _, v in ipairs(read_shada_file(shada_fname)) do
      if v.type == 4 and v.value[1] == 0 and v.value[2] == '-' then
        eq(2, #v.value)
        found = true
      end
    end
    eq(true, found)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada!' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)

  it('works with history item with type 10', function()
    wshada('\004\000\006\147\010\196\001-\194')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('wshada ' .. shada_fname)
    eq(0, exc_exec(sdrcmd()))
    local found = 0
    for i, v in ipairs(read_shada_file(shada_fname)) do
      if i == 1 then
        eq(1, v.type)
      end
      if v.type == 4 then
        if v.value[1] == 10 and #v.value == 3 and v.value[3] == false then
          found = found + 1
        end
      end
    end
    eq(1, found)
    nvim_command('wshada! ' .. shada_fname)
    found = 0
    for i, v in ipairs(read_shada_file(shada_fname)) do
      if i == 1 then
        eq(1, v.type)
      end
      if v.type == 4 then
        if v.value[1] == 10 and #v.value == 3 and v.value[3] == false then
          found = found + 1
        end
      end
    end
    eq(0, found)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada!' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)

  it('works with item with 100 type', function()
    wshada('\100\000\006\147\010\196\001-\194')
    eq(0, exc_exec(sdrcmd()))
    nvim_command('wshada ' .. shada_fname)
    eq(0, exc_exec(sdrcmd()))
    local found = 0
    for i, v in ipairs(read_shada_file(shada_fname)) do
      if i == 1 then
        eq(1, v.type)
      end
      if v.type == 100 then
        if v.value[1] == 10 and #v.value == 3 and v.value[3] == false then
          found = found + 1
        end
      end
    end
    eq(1, found)
    nvim_command('wshada! ' .. shada_fname)
    found = 0
    for i, v in ipairs(read_shada_file(shada_fname)) do
      if i == 1 then
        eq(1, v.type)
      end
      if v.type == 100 then
        if v.value[1] == 10 and #v.value == 3 and v.value[3] == false then
          found = found + 1
        end
      end
    end
    eq(0, found)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
    nvim_command('rshada!' .. shada_fname)
    funcs.garbagecollect(1)
    funcs.garbagecollect(1)
  end)
end)
