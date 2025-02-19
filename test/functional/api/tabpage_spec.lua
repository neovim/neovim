local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, eq, ok = n.clear, t.eq, t.ok
local exec = n.exec
local feed = n.feed
local api = n.api
local fn = n.fn
local request = n.request
local NIL = vim.NIL
local pcall_err = t.pcall_err
local command = n.command

describe('api/tabpage', function()
  before_each(clear)

  describe('list_wins and get_win', function()
    it('works', function()
      command('tabnew')
      command('vsplit')
      local tab1, tab2 = unpack(api.nvim_list_tabpages())
      local win1, win2, win3 = unpack(api.nvim_list_wins())
      eq({ win1 }, api.nvim_tabpage_list_wins(tab1))
      eq(win1, api.nvim_tabpage_get_win(tab1))
      eq({ win2, win3 }, api.nvim_tabpage_list_wins(tab2))
      eq(win2, api.nvim_tabpage_get_win(tab2))
      api.nvim_set_current_win(win3)
      eq(win3, api.nvim_tabpage_get_win(tab2))
      command('tabprev')
      eq(win1, api.nvim_tabpage_get_win(tab1))
      eq(win3, api.nvim_tabpage_get_win(tab2))
    end)

    it('validates args', function()
      eq('Invalid tabpage id: 23', pcall_err(api.nvim_tabpage_list_wins, 23))
    end)
  end)

  describe('set_win', function()
    it('works', function()
      command('tabnew')
      command('vsplit')
      local tab1, tab2 = unpack(api.nvim_list_tabpages())
      local win1, win2, win3 = unpack(api.nvim_list_wins())
      eq({ win1 }, api.nvim_tabpage_list_wins(tab1))
      eq({ win2, win3 }, api.nvim_tabpage_list_wins(tab2))
      eq(win2, api.nvim_tabpage_get_win(tab2))
      api.nvim_tabpage_set_win(tab2, win3)
      eq(win3, api.nvim_tabpage_get_win(tab2))
    end)

    it('works in non-current tabpages', function()
      command('tabnew')
      command('vsplit')
      local tab1, tab2 = unpack(api.nvim_list_tabpages())
      local win1, win2, win3 = unpack(api.nvim_list_wins())
      eq({ win1 }, api.nvim_tabpage_list_wins(tab1))
      eq({ win2, win3 }, api.nvim_tabpage_list_wins(tab2))
      eq(win2, api.nvim_tabpage_get_win(tab2))
      eq(win2, api.nvim_get_current_win())

      command('tabprev')

      eq(tab1, api.nvim_get_current_tabpage())

      eq(win2, api.nvim_tabpage_get_win(tab2))
      api.nvim_tabpage_set_win(tab2, win3)
      eq(win3, api.nvim_tabpage_get_win(tab2))

      command('tabnext')
      eq(win3, api.nvim_get_current_win())
    end)

    it('throws an error when the window does not belong to the tabpage', function()
      command('tabnew')
      command('vsplit')
      local tab1, tab2 = unpack(api.nvim_list_tabpages())
      local win1, win2, win3 = unpack(api.nvim_list_wins())
      eq({ win1 }, api.nvim_tabpage_list_wins(tab1))
      eq({ win2, win3 }, api.nvim_tabpage_list_wins(tab2))
      eq(win2, api.nvim_get_current_win())

      eq(
        string.format('Window does not belong to tabpage %d', tab2),
        pcall_err(api.nvim_tabpage_set_win, tab2, win1)
      )

      eq(
        string.format('Window does not belong to tabpage %d', tab1),
        pcall_err(api.nvim_tabpage_set_win, tab1, win3)
      )
    end)

    it('does not switch window when textlocked or in the cmdwin', function()
      local target_win = api.nvim_get_current_win()
      feed('q:')
      local cur_win = api.nvim_get_current_win()
      eq(
        'Vim:E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_tabpage_set_win, 0, target_win)
      )
      eq(cur_win, api.nvim_get_current_win())
      command('quit!')

      exec(([[
        new
        call setline(1, 'foo')
        setlocal debug=throw indentexpr=nvim_tabpage_set_win(0,%d)
      ]]):format(target_win))
      cur_win = api.nvim_get_current_win()
      eq(
        'Vim(normal):E5555: API call: Vim:E565: Not allowed to change text or change window',
        pcall_err(command, 'normal! ==')
      )
      eq(cur_win, api.nvim_get_current_win())
    end)
  end)

  describe('{get,set,del}_var', function()
    it('works', function()
      api.nvim_tabpage_set_var(0, 'lua', { 1, 2, { ['3'] = 1 } })
      eq({ 1, 2, { ['3'] = 1 } }, api.nvim_tabpage_get_var(0, 'lua'))
      eq({ 1, 2, { ['3'] = 1 } }, api.nvim_eval('t:lua'))
      eq(1, fn.exists('t:lua'))
      api.nvim_tabpage_del_var(0, 'lua')
      eq(0, fn.exists('t:lua'))
      eq('Key not found: lua', pcall_err(api.nvim_tabpage_del_var, 0, 'lua'))
      api.nvim_tabpage_set_var(0, 'lua', 1)
      command('lockvar t:lua')
      eq('Key is locked: lua', pcall_err(api.nvim_tabpage_del_var, 0, 'lua'))
      eq('Key is locked: lua', pcall_err(api.nvim_tabpage_set_var, 0, 'lua', 1))
    end)

    it('tabpage_set_var returns the old value', function()
      local val1 = { 1, 2, { ['3'] = 1 } }
      local val2 = { 4, 7 }
      eq(NIL, request('tabpage_set_var', 0, 'lua', val1))
      eq(val1, request('tabpage_set_var', 0, 'lua', val2))
    end)

    it('tabpage_del_var returns the old value', function()
      local val1 = { 1, 2, { ['3'] = 1 } }
      local val2 = { 4, 7 }
      eq(NIL, request('tabpage_set_var', 0, 'lua', val1))
      eq(val1, request('tabpage_set_var', 0, 'lua', val2))
      eq(val2, request('tabpage_del_var', 0, 'lua'))
    end)
  end)

  describe('get_number', function()
    it('works', function()
      local tabs = api.nvim_list_tabpages()
      eq(1, api.nvim_tabpage_get_number(tabs[1]))

      command('tabnew')
      local tab1, tab2 = unpack(api.nvim_list_tabpages())
      eq(1, api.nvim_tabpage_get_number(tab1))
      eq(2, api.nvim_tabpage_get_number(tab2))

      command('-tabmove')
      eq(2, api.nvim_tabpage_get_number(tab1))
      eq(1, api.nvim_tabpage_get_number(tab2))
    end)
  end)

  describe('is_valid', function()
    it('works', function()
      command('tabnew')
      local tab = api.nvim_list_tabpages()[2]
      api.nvim_set_current_tabpage(tab)
      ok(api.nvim_tabpage_is_valid(tab))
      command('tabclose')
      ok(not api.nvim_tabpage_is_valid(tab))
    end)
  end)
end)
