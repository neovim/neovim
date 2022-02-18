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

describe('Ex command', function()
  before_each(clear)
  after_each(function() eq({}, meths.get_vvar('errors')) end)

  it('checks for address line overflow', function()
    if sizeoflong() < 8 then
      pending('Skipped: only works with 64 bit long ints')
    end

    source [[
      new
      call setline(1, 'text')
      call assert_fails('|.44444444444444444444444', 'E1247:')
      call assert_fails('|.9223372036854775806', 'E1247:')
      bwipe!
    ]]
  end)
end)
