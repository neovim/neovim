local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local fn = n.fn
local api = n.api
local command = n.command
local eq = t.eq
local exec_lua = n.exec_lua
local matches = t.matches
local pcall_err = t.pcall_err

before_each(function()
  n.clear()
end)

describe('vim._with {buf = }', function()
  it('does not trigger autocmd', function()
    exec_lua [[
      local new = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_create_autocmd( { 'BufEnter', 'BufLeave', 'BufWinEnter', 'BufWinLeave' }, {
        callback = function() _G.n = (_G.n or 0) + 1 end
      })
      vim._with({buf = new}, function()
      end)
      assert(_G.n == nil)
    ]]
  end)

  it('trigger autocmd if changed within context', function()
    exec_lua [[
      local new = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_create_autocmd( { 'BufEnter', 'BufLeave', 'BufWinEnter', 'BufWinLeave' }, {
        callback = function() _G.n = (_G.n or 0) + 1 end
      })
      vim._with({}, function()
        vim.api.nvim_set_current_buf(new)
        assert(_G.n ~= nil)
      end)
    ]]
  end)

  it('can access buf options', function()
    local buf1 = api.nvim_get_current_buf()
    local buf2 = exec_lua [[
      buf2 = vim.api.nvim_create_buf(false, true)
      return buf2
    ]]

    eq(false, api.nvim_get_option_value('autoindent', { buf = buf1 }))
    eq(false, api.nvim_get_option_value('autoindent', { buf = buf2 }))

    local val = exec_lua [[
      return vim._with({buf = buf2}, function()
        vim.cmd "set autoindent"
        return vim.api.nvim_get_current_buf()
    end)
    ]]

    eq(false, api.nvim_get_option_value('autoindent', { buf = buf1 }))
    eq(true, api.nvim_get_option_value('autoindent', { buf = buf2 }))
    eq(buf1, api.nvim_get_current_buf())
    eq(buf2, val)
  end)

  it('does not cause ml_get errors with invalid visual selection', function()
    exec_lua [[
      local api = vim.api
      local t = function(s) return api.nvim_replace_termcodes(s, true, true, true) end
      api.nvim_buf_set_lines(0, 0, -1, true, {"a", "b", "c"})
      api.nvim_feedkeys(t "G<C-V>", "txn", false)
      vim._with({buf = api.nvim_create_buf(false, true)}, function() vim.cmd "redraw" end)
    ]]
  end)

  it('can be nested crazily with hidden buffers', function()
    eq(
      true,
      exec_lua([[
      local function scratch_buf_call(fn)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value('cindent', true, {buf = buf})
        return vim._with({buf = buf}, function()
          return vim.api.nvim_get_current_buf() == buf
            and vim.api.nvim_get_option_value('cindent', {buf = buf})
            and fn()
      end) and vim.api.nvim_buf_delete(buf, {}) == nil
    end

    return scratch_buf_call(function()
      return scratch_buf_call(function()
        return scratch_buf_call(function()
          return scratch_buf_call(function()
            return scratch_buf_call(function()
              return scratch_buf_call(function()
                return scratch_buf_call(function()
                  return scratch_buf_call(function()
                    return scratch_buf_call(function()
                      return scratch_buf_call(function()
                        return scratch_buf_call(function()
                          return scratch_buf_call(function()
                            return true
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
    ]])
    )
  end)

  it('can return values by reference', function()
    eq(
      { 4, 7 },
      exec_lua [[
      local val = {4, 10}
      local ref = vim._with({ buf = 0}, function() return val end)
      ref[2] = 7
      return val
    ]]
    )
  end)
end)

describe('vim._with {win = }', function()
  it('does not trigger autocmd', function()
    exec_lua [[
      local old = vim.api.nvim_get_current_win()
      vim.cmd("new")
      local new = vim.api.nvim_get_current_win()
      vim.api.nvim_create_autocmd( { 'WinEnter', 'WinLeave' }, {
        callback = function() _G.n = (_G.n or 0) + 1 end
      })
      vim._with({win = old}, function()
      end)
      assert(_G.n == nil)
    ]]
  end)

  it('trigger autocmd if changed within context', function()
    exec_lua [[
      local old = vim.api.nvim_get_current_win()
      vim.cmd("new")
      local new = vim.api.nvim_get_current_win()
      vim.api.nvim_create_autocmd( { 'WinEnter', 'WinLeave' }, {
        callback = function() _G.n = (_G.n or 0) + 1 end
      })
      vim._with({}, function()
        vim.api.nvim_set_current_win(old)
        assert(_G.n ~= nil)
      end)
    ]]
  end)

  it('can access window options', function()
    command('vsplit')
    local win1 = api.nvim_get_current_win()
    command('wincmd w')
    local win2 = exec_lua [[
      win2 = vim.api.nvim_get_current_win()
      return win2
    ]]
    command('wincmd p')

    eq('', api.nvim_get_option_value('winhighlight', { win = win1 }))
    eq('', api.nvim_get_option_value('winhighlight', { win = win2 }))

    local val = exec_lua [[
      return vim._with({win = win2}, function()
        vim.cmd "setlocal winhighlight=Normal:Normal"
        return vim.api.nvim_get_current_win()
      end)
    ]]

    eq('', api.nvim_get_option_value('winhighlight', { win = win1 }))
    eq('Normal:Normal', api.nvim_get_option_value('winhighlight', { win = win2 }))
    eq(win1, api.nvim_get_current_win())
    eq(win2, val)
  end)

  it('does not cause ml_get errors with invalid visual selection', function()
    -- Add lines to the current buffer and make another window looking into an empty buffer.
    exec_lua [[
      _G.api = vim.api
      _G.t = function(s) return api.nvim_replace_termcodes(s, true, true, true) end
      _G.win_lines = api.nvim_get_current_win()
      vim.cmd "new"
      _G.win_empty = api.nvim_get_current_win()
      api.nvim_set_current_win(win_lines)
      api.nvim_buf_set_lines(0, 0, -1, true, {"a", "b", "c"})
    ]]

    -- Start Visual in current window, redraw in other window with fewer lines.
    exec_lua [[
      api.nvim_feedkeys(t "G<C-V>", "txn", false)
      vim._with({win = win_empty}, function() vim.cmd "redraw" end)
    ]]

    -- Start Visual in current window, extend it in other window with more lines.
    exec_lua [[
      api.nvim_feedkeys(t "<Esc>gg", "txn", false)
      api.nvim_set_current_win(win_empty)
      api.nvim_feedkeys(t "gg<C-V>", "txn", false)
      vim._with({win = win_lines}, function() api.nvim_feedkeys(t "G<C-V>", "txn", false) end)
      vim.cmd "redraw"
    ]]
  end)

  it('updates ruler if cursor moved', function()
    local screen = Screen.new(30, 5)
    screen:set_default_attr_ids {
      [1] = { reverse = true },
      [2] = { bold = true, reverse = true },
    }
    screen:attach()
    exec_lua [[
      _G.api = vim.api
      vim.opt.ruler = true
      local lines = {}
      for i = 0, 499 do lines[#lines + 1] = tostring(i) end
      api.nvim_buf_set_lines(0, 0, -1, true, lines)
      api.nvim_win_set_cursor(0, {20, 0})
      vim.cmd "split"
      _G.win = api.nvim_get_current_win()
      vim.cmd "wincmd w | redraw"
    ]]
    screen:expect [[
      19                            |
      {1:[No Name] [+]  20,1         3%}|
      ^19                            |
      {2:[No Name] [+]  20,1         3%}|
                                    |
    ]]
    exec_lua [[
      vim._with({win = win}, function() api.nvim_win_set_cursor(0, {100, 0}) end)
      vim.cmd "redraw"
    ]]
    screen:expect [[
      99                            |
      {1:[No Name] [+]  100,1       19%}|
      ^19                            |
      {2:[No Name] [+]  20,1         3%}|
                                    |
    ]]
  end)

  it('can return values by reference', function()
    eq(
      { 7, 10 },
      exec_lua [[
      local val = {4, 10}
      local ref = vim._with({win = 0}, function() return val end)
      ref[1] = 7
      return val
    ]]
    )
  end)

  it('layout in current tabpage does not affect windows in others', function()
    command('tab split')
    local t2_move_win = api.nvim_get_current_win()
    command('vsplit')
    local t2_other_win = api.nvim_get_current_win()
    command('tabprevious')
    matches('E36: Not enough room$', pcall_err(command, 'execute "split|"->repeat(&lines)'))
    command('vsplit')

    exec_lua('vim._with({win = ...}, function() vim.cmd.wincmd "J" end)', t2_move_win)
    eq({ 'col', { { 'leaf', t2_other_win }, { 'leaf', t2_move_win } } }, fn.winlayout(2))
  end)
end)

describe('vim._with {lockmarks = true}', function()
  it('is reset', function()
    local mark = exec_lua [[
      vim.api.nvim_buf_set_lines(0, 0, 0, false, {"marky", "snarky", "malarkey"})
      vim.api.nvim_buf_set_mark(0,"m",1,0, {})
      vim._with({lockmarks = true}, function()
        vim.api.nvim_buf_set_lines(0, 0, 2, false, {"mass", "mess", "moss"})
      end)
      return vim.api.nvim_buf_get_mark(0,"m")
    ]]
    t.eq(mark, { 1, 0 })
  end)
end)
