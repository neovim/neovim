local t = require('test.unit.testutil')
local itp = t.gen_itp(t.it)
local ffi = t.ffi
local eq = t.eq
local NULL = t.NULL

local context = t.cimport('./src/nvim/context.h')
local globals = t.cimport('./src/nvim/globals.h')
local window = t.cimport('./src/nvim/window.h')

t.describe('ctx_switch', function()
  itp('preserves a same-buffer context whose window belongs to another tabpage', function()
    local buf = globals.curbuf
    local wins = ffi.new('win_T[2]')
    local tabs = ffi.new('tabpage_T[2]')
    for i = 0, 1 do
      wins[i].handle = 1000 + i
      wins[i].w_buffer = buf
      wins[i].w_cursor.lnum = 1
      tabs[i].tp_firstwin = wins + i
      tabs[i].tp_lastwin = wins + i
      tabs[i].tp_curwin = wins + i
    end
    tabs[0].tp_next = tabs + 1
    globals.first_tabpage = tabs
    globals.curtab = tabs
    globals.firstwin = wins
    globals.lastwin = wins
    globals.curwin = wins + 1
    globals.prevwin = NULL

    eq(false, window.win_valid(globals.curwin))
    eq(true, window.win_valid_any_tab(globals.curwin))

    local cs = ffi.new('CtxSwitch')
    eq(true, context.ctx_switch(cs, NULL, NULL, buf, 0))
    eq(true, globals.curwin == wins + 1)
    eq(true, globals.curbuf == buf)
    eq(true, globals.curtab == tabs)

    context.ctx_restore(cs)
    eq(true, globals.curwin == wins + 1)
    eq(true, globals.curbuf == buf)
    eq(true, globals.curtab == tabs)
  end)
end)
