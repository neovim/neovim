-- Sanity checks for tabpage_* API calls via msgpack-rpc
local helpers = require('test.functional.helpers')(after_each)
local clear, nvim, tabpage, curtab, eq, ok =
  helpers.clear, helpers.nvim, helpers.tabpage, helpers.curtab, helpers.eq,
  helpers.ok
local curtabmeths = helpers.curtabmeths
local funcs = helpers.funcs
local request = helpers.request
local NIL = helpers.NIL

describe('tabpage_* functions', function()
  before_each(clear)

  describe('get_windows and get_window', function()
    it('works', function()
      nvim('command', 'tabnew')
      nvim('command', 'vsplit')
      local tab1, tab2 = unpack(nvim('get_tabpages'))
      local win1, win2, win3 = unpack(nvim('get_windows'))
      eq({win1},  tabpage('get_windows', tab1))
      eq({win2, win3},  tabpage('get_windows', tab2))
      eq(win2, tabpage('get_window', tab2))
      nvim('set_current_window', win3)
      eq(win3, tabpage('get_window', tab2))
    end)
  end)

  describe('{get,set,del}_var', function()
    it('works', function()
      curtab('set_var', 'lua', {1, 2, {['3'] = 1}})
      eq({1, 2, {['3'] = 1}}, curtab('get_var', 'lua'))
      eq({1, 2, {['3'] = 1}}, nvim('eval', 't:lua'))
      eq(1, funcs.exists('t:lua'))
      curtabmeths.del_var('lua')
      eq(0, funcs.exists('t:lua'))
    end)

    it('tabpage_set_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL, request('tabpage_set_var', 0, 'lua', val1))
      eq(val1, request('tabpage_set_var', 0, 'lua', val2))
    end)

    it('tabpage_del_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL,  request('tabpage_set_var', 0, 'lua', val1))
      eq(val1, request('tabpage_set_var', 0, 'lua', val2))
      eq(val2, request('tabpage_del_var', 0, 'lua'))
    end)
  end)

  describe('is_valid', function()
    it('works', function()
      nvim('command', 'tabnew')
      local tab = nvim('get_tabpages')[2]
      nvim('set_current_tabpage', tab)
      ok(tabpage('is_valid', tab))
      nvim('command', 'tabclose')
      ok(not tabpage('is_valid', tab))
    end)
  end)
end)
