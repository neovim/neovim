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

  describe('open_tabpage', function()
    it('works', function()
      local tabs = api.nvim_list_tabpages()
      eq(1, #tabs)
      local curtab = api.nvim_get_current_tabpage()
      local tab = api.nvim_open_tabpage(0, {
        enter = false,
      })
      local newtabs = api.nvim_list_tabpages()
      eq(2, #newtabs)
      eq(tab, newtabs[2])
      eq(curtab, api.nvim_get_current_tabpage())

      local tab2 = api.nvim_open_tabpage(0, {
        enter = true,
      })
      local newtabs2 = api.nvim_list_tabpages()
      eq(3, #newtabs2)
      eq({
        tabs[1],
        tab2, -- new tabs open after the current tab
        tab,
      }, newtabs2)
      eq(tab2, newtabs2[2])
      eq(tab, newtabs2[3])
      eq(tab2, api.nvim_get_current_tabpage())
    end)

    it('respects the `after` option', function()
      local tab1 = api.nvim_get_current_tabpage()
      command('tabnew')
      local tab2 = api.nvim_get_current_tabpage()
      command('tabnew')
      local tab3 = api.nvim_get_current_tabpage()

      local newtabs = api.nvim_list_tabpages()
      eq(3, #newtabs)
      eq(newtabs, {
        tab1,
        tab2,
        -- new_tab,
        tab3,
      })

      local new_tab = api.nvim_open_tabpage(0, {
        enter = false,
        after = api.nvim_tabpage_get_number(tab2),
      })

      local newtabs2 = api.nvim_list_tabpages()
      eq(4, #newtabs2)
      eq({
        tab1,
        new_tab,
        tab2,
        tab3,
      }, newtabs2)
      eq(api.nvim_get_current_tabpage(), tab3)
    end)

    it('respects the `enter` argument', function()
      eq(1, #api.nvim_list_tabpages())
      local tab1 = api.nvim_get_current_tabpage()

      local new_tab = api.nvim_open_tabpage(0, {
        enter = false,
      })

      local newtabs = api.nvim_list_tabpages()
      eq(2, #newtabs)
      eq(newtabs, {
        tab1,
        new_tab,
      })
      eq(api.nvim_get_current_tabpage(), tab1)

      local new_tab2 = api.nvim_open_tabpage(0, {
        enter = true,
      })
      local newtabs2 = api.nvim_list_tabpages()
      eq(3, #newtabs2)
      eq(newtabs2, {
        tab1,
        new_tab2,
        new_tab,
      })

      eq(api.nvim_get_current_tabpage(), new_tab2)
    end)

    it('applies `enter` autocmds in the context of the new tabpage', function()
      api.nvim_create_autocmd('TabEnter', {
        command = 'let g:entered_tab = nvim_get_current_tabpage()',
      })

      local new_tab = api.nvim_open_tabpage(0, {
        enter = true,
      })

      local entered_tab = assert(tonumber(api.nvim_get_var('entered_tab')))

      eq(new_tab, entered_tab)
    end)

    it('handles edge cases for positioning', function()
      -- Start with 3 tabs
      local tab1 = api.nvim_get_current_tabpage()
      command('tabnew')
      local tab2 = api.nvim_get_current_tabpage()
      command('tabnew')
      local tab3 = api.nvim_get_current_tabpage()

      local initial_tabs = api.nvim_list_tabpages()
      eq(3, #initial_tabs)
      eq({ tab1, tab2, tab3 }, initial_tabs)

      -- Test after=1: should become first tab
      local first_tab = api.nvim_open_tabpage(0, {
        enter = false,
        after = 1,
      })
      local tabs_after_first = api.nvim_list_tabpages()
      eq(4, #tabs_after_first)
      eq({ first_tab, tab1, tab2, tab3 }, tabs_after_first)

      -- Test after=0: should insert after current tab (tab3)
      local explicit_after_current = api.nvim_open_tabpage(0, {
        enter = false,
        after = 0,
      })
      local tabs_after_current = api.nvim_list_tabpages()
      eq(5, #tabs_after_current)
      eq({ first_tab, tab1, tab2, tab3, explicit_after_current }, tabs_after_current)

      -- Test inserting before a middle tab (before tab2, which is now position 3)
      local before_middle = api.nvim_open_tabpage(0, {
        enter = false,
        after = 3,
      })
      local tabs_after_middle = api.nvim_list_tabpages()
      eq(6, #tabs_after_middle)
      eq({ first_tab, tab1, before_middle, tab2, tab3, explicit_after_current }, tabs_after_middle)

      eq(api.nvim_get_current_tabpage(), tab3)

      -- Test default behavior (after current)
      local default_after_current = api.nvim_open_tabpage(0, {
        enter = false,
      })
      local final_tabs = api.nvim_list_tabpages()
      eq(7, #final_tabs)
      eq({
        first_tab,
        tab1,
        before_middle,
        tab2,
        tab3,
        default_after_current,
        explicit_after_current,
      }, final_tabs)
    end)

    it('handles position beyond last tab', function()
      -- Create a few tabs first
      local tab1 = api.nvim_get_current_tabpage()
      command('tabnew')
      local tab2 = api.nvim_get_current_tabpage()
      command('tabnew')
      local tab3 = api.nvim_get_current_tabpage()

      eq(3, #api.nvim_list_tabpages())
      eq({ tab1, tab2, tab3 }, api.nvim_list_tabpages())

      -- Test that requesting position beyond last tab still works
      -- (should place it at the end)
      local new_tab = api.nvim_open_tabpage(0, {
        enter = false,
        after = 10, -- Way beyond the last tab
      })

      local final_tabs = api.nvim_list_tabpages()
      eq(4, #final_tabs)
      -- Should append at the end
      eq({ tab1, tab2, tab3, new_tab }, final_tabs)
    end)

    it('works with specific buffer', function()
      local buf = api.nvim_create_buf(false, false)
      api.nvim_buf_set_lines(buf, 0, -1, false, { 'test content' })

      local original_tab = api.nvim_get_current_tabpage()
      local original_buf = api.nvim_get_current_buf()

      local new_tab = api.nvim_open_tabpage(buf, {
        enter = true, -- Enter the tab to make testing easier
      })

      -- Check that new tab has the specified buffer
      eq(new_tab, api.nvim_get_current_tabpage())
      eq(buf, api.nvim_get_current_buf())
      eq({ 'test content' }, api.nvim_buf_get_lines(buf, 0, -1, false))

      -- Switch back and check original tab still has original buffer
      api.nvim_set_current_tabpage(original_tab)
      eq(original_buf, api.nvim_get_current_buf())
    end)

    it('validates buffer parameter', function()
      -- Test invalid buffer
      eq('Invalid buffer id: 999', pcall_err(api.nvim_open_tabpage, 999, {}))
    end)

    it('works with current buffer (0)', function()
      local current_buf = api.nvim_get_current_buf()

      local new_tab = api.nvim_open_tabpage(0, {
        enter = false,
      })

      api.nvim_set_current_tabpage(new_tab)
      eq(current_buf, api.nvim_get_current_buf())
    end)

    it('handles complex positioning scenarios', function()
      -- Create 5 tabs total
      local tabs = { api.nvim_get_current_tabpage() }
      for i = 2, 5 do
        command('tabnew')
        tabs[i] = api.nvim_get_current_tabpage()
      end

      eq(5, #api.nvim_list_tabpages())

      -- Go to middle tab (tab 3)
      api.nvim_set_current_tabpage(tabs[3])

      -- Insert after=0 (after current, which is tab 3)
      local new_after_current = api.nvim_open_tabpage(0, {
        enter = false,
        after = 0,
      })

      local result_tabs = api.nvim_list_tabpages()
      eq(6, #result_tabs)
      eq({
        tabs[1],
        tabs[2],
        tabs[3],
        new_after_current,
        tabs[4],
        tabs[5],
      }, result_tabs)

      -- Insert at position 2 (before tab2, which becomes new position 2)
      local new_at_pos2 = api.nvim_open_tabpage(0, {
        enter = false,
        after = 2,
      })

      local final_result = api.nvim_list_tabpages()
      eq(7, #final_result)
      eq({
        tabs[1],
        new_at_pos2,
        tabs[2],
        tabs[3],
        new_after_current,
        tabs[4],
        tabs[5],
      }, final_result)
    end)

    it('preserves tab order when entering new tabs', function()
      local tab1 = api.nvim_get_current_tabpage()
      command('tabnew')
      local tab2 = api.nvim_get_current_tabpage()

      -- Create new tab with enter=true, should insert after current (tab2)
      local tab3 = api.nvim_open_tabpage(0, {
        enter = true,
        after = 0,
      })

      local tabs = api.nvim_list_tabpages()
      eq(3, #tabs)
      eq({ tab1, tab2, tab3 }, tabs)
      eq(tab3, api.nvim_get_current_tabpage())

      -- Create another with enter=true and specific position
      api.nvim_set_current_tabpage(tab1)
      local tab4 = api.nvim_open_tabpage(0, {
        enter = true,
        after = 1, -- Should become first tab
      })

      local final_tabs = api.nvim_list_tabpages()
      eq(4, #final_tabs)
      eq({ tab4, tab1, tab2, tab3 }, final_tabs)
      eq(tab4, api.nvim_get_current_tabpage())
    end)
  end)
end)
