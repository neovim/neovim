local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local meths = helpers.meths
local source = helpers.source
local eq = helpers.eq

local function sizeoflong()
  if not exec_lua('return pcall(require, "ffi")') then
    pending('missing LuaJIT FFI')
  end
  return exec_lua('return require("ffi").sizeof(require("ffi").typeof("long"))')
end

describe('put', function()
  before_each(clear)
  after_each(function() eq({}, meths.get_vvar('errors')) end)

  it('very large count 64-bit', function()
    if sizeoflong() < 8 then
      pending('Skipped: only works with 64 bit long ints')
    end

    source [[
      new
      let @" = repeat('x', 100)
      call assert_fails('norm 999999999p', 'E1240:')
      bwipe!
    ]]
  end)

  it('very large count (visual block) 64-bit', function()
    if sizeoflong() < 8 then
      pending('Skipped: only works with 64 bit long ints')
    end

    source [[
      new
      call setline(1, repeat('x', 100))
      exe "norm \<C-V>$y"
      call assert_fails('norm 999999999p', 'E1240:')
      bwipe!
    ]]
  end)
end)
