local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local os = require('os')
local clear, feed = helpers.clear, helpers.feed
local assert_alive = helpers.assert_alive
local command, feed_command = helpers.command, helpers.feed_command
local eval = helpers.eval
local eq = helpers.eq
local neq = helpers.neq
local expect = helpers.expect
local exec = helpers.exec
local exec_lua = helpers.exec_lua
local insert = helpers.insert
local api = helpers.api
local fn = helpers.fn
local run = helpers.run
local pcall_err = helpers.pcall_err
local tbl_contains = vim.tbl_contains
local curbuf = helpers.api.nvim_get_current_buf
local curwin = helpers.api.nvim_get_current_win
local curtab = helpers.api.nvim_get_current_tabpage
local NIL = vim.NIL

describe('float window', function()
  before_each(function()
    clear()
    command('hi VertSplit gui=reverse')
  end)

  it('behavior', function()
    -- Create three windows and test that ":wincmd <direction>" changes to the
    -- first window, if the previous window is invalid.
    command('split')
    api.nvim_open_win(0, true, {width=10, height=10, relative='editor', row=0, col=0})
    eq(1002, fn.win_getid())
    eq('editor', api.nvim_win_get_config(1002).relative)
    command([[
      call nvim_win_close(1001, v:false)
      wincmd j
    ]])
    eq(1000, fn.win_getid())
  end)

  it('win_execute() should work' , function()
    local buf = api.nvim_create_buf(false, false)
    api.nvim_buf_set_lines(buf, 0, -1, true, {'the floatwin', 'abc', 'def'})
    local win = api.nvim_open_win(buf, false, {relative='win', width=16, height=1, row=0, col=10})
    local line = fn.win_execute(win, 'echo getline(1)')
    eq('\nthe floatwin', line)
    eq('\n1', fn.win_execute(win, 'echo line(".",'..win..')'))
    eq('\n3', fn.win_execute(win, 'echo line("$",'..win..')'))
    eq('\n0', fn.win_execute(win, 'echo line("$", 123456)'))
    fn.win_execute(win, 'bwipe!')
  end)

  it("win_execute() call commands that are not allowed when 'hidden' is not set" , function()
    command('set nohidden')
    local buf = api.nvim_create_buf(false, false)
    api.nvim_buf_set_lines(buf, 0, -1, true, {'the floatwin'})
    local win = api.nvim_open_win(buf, true, {relative='win', width=16, height=1, row=0, col=10})
    eq('Vim(close):E37: No write since last change (add ! to override)', pcall_err(fn.win_execute, win, 'close'))
    eq('Vim(bdelete):E89: No write since last change for buffer 2 (add ! to override)', pcall_err(fn.win_execute, win, 'bdelete'))
    fn.win_execute(win, 'bwipe!')
  end)

  it('closed immediately by autocmd #11383', function()
    eq('Window was closed immediately',
      pcall_err(exec_lua, [[
        local api = vim.api
        local function crashes(contents)
          local buf = api.nvim_create_buf(false, true)
          local floatwin = api.nvim_open_win(buf, true, {
            relative = 'cursor';
            style = 'minimal';
            row = 0; col = 0;
            height = #contents;
            width = 10;
          })
          api.nvim_buf_set_lines(buf, 0, -1, true, contents)
          local winnr = vim.fn.win_id2win(floatwin)
          api.nvim_command('wincmd p')
          api.nvim_command('autocmd BufEnter * ++once '..winnr..'wincmd c')
          return buf, floatwin
        end
        crashes{'foo'}
        crashes{'bar'}
    ]]))
    assert_alive()
  end)

  it('closed immediately by autocmd after win_enter #15548', function()
    eq('Window was closed immediately',
      pcall_err(exec_lua, [[
        vim.cmd "autocmd BufLeave * ++once quit!"
        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_open_win(buf, true, {
          relative = "win",
          row = 0, col = 0,
          width = 1, height = 1,
          noautocmd = false,
        })
    ]]))
    assert_alive()
  end)

  it('open with WinNew autocmd', function()
    local new_triggered_before_enter, new_curwin, win = unpack(exec_lua([[
      local enter_triggered = false
      local new_triggered_before_enter = false
      local new_curwin
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_create_autocmd('WinEnter', {
        callback = function()
          enter_triggered = true
        end
      })
      vim.api.nvim_create_autocmd('WinNew', {
        callback = function()
          new_triggered_before_enter = not enter_triggered
          new_curwin = vim.api.nvim_get_current_win()
        end
      })
      local opts = {
        relative = "win",
        row = 0, col = 0,
        width = 1, height = 1,
        noautocmd = false,
      }
      local win = vim.api.nvim_open_win(buf, true, opts)
      return {new_triggered_before_enter, new_curwin, win}
    ]]))
    eq(true, new_triggered_before_enter)
    eq(win, new_curwin)
  end)

  it('opened with correct height', function()
    local height = exec_lua([[
      vim.go.winheight = 20
      local bufnr = vim.api.nvim_create_buf(false, true)

      local opts = {
        height = 10,
        col = 5,
        row = 1,
        relative = 'editor',
        style = 'minimal',
        width = 15
      }

      local win_id = vim.api.nvim_open_win(bufnr, true, opts)

      return vim.api.nvim_win_get_height(win_id)
    ]])

    eq(10, height)
  end)

  it('opened with correct width', function()
    local width = exec_lua([[
      vim.go.winwidth = 20
      local bufnr = vim.api.nvim_create_buf(false, true)

      local opts = {
        height = 10,
        col = 5,
        row = 1,
        relative = 'editor',
        style = 'minimal',
        width = 10
      }

      local win_id = vim.api.nvim_open_win(bufnr, true, opts)

      return vim.api.nvim_win_get_width(win_id)
    ]])

    eq(10, width)
  end)

  it('opened with correct position', function()
    local pos = exec_lua([[
      local bufnr = vim.api.nvim_create_buf(false, true)

      local opts = {
        width = 10,
        height = 10,
        col = 7,
        row = 9,
        relative = 'editor',
        style = 'minimal'
      }

      local win_id = vim.api.nvim_open_win(bufnr, false, opts)

      return vim.api.nvim_win_get_position(win_id)
    ]])

    eq(9, pos[1])
    eq(7, pos[2])
  end)

  it('opened with correct position relative to the mouse', function()
    api.nvim_input_mouse('left', 'press', '', 0, 10, 10)
    local pos = exec_lua([[
      local bufnr = vim.api.nvim_create_buf(false, true)

      local opts = {
        width = 10,
        height = 10,
        col = 1,
        row = 2,
        relative = 'mouse',
        style = 'minimal'
      }

      local win_id = vim.api.nvim_open_win(bufnr, false, opts)

      return vim.api.nvim_win_get_position(win_id)
    ]])

    eq(12, pos[1])
    eq(11, pos[2])
  end)

  it('opened with correct position relative to the cursor', function()
    local pos = exec_lua([[
      local bufnr = vim.api.nvim_create_buf(false, true)

      local opts = {
        width = 10,
        height = 10,
        col = 7,
        row = 9,
        relative = 'cursor',
        style = 'minimal'
      }

      local win_id = vim.api.nvim_open_win(bufnr, false, opts)

      return vim.api.nvim_win_get_position(win_id)
    ]])

    eq(9, pos[1])
    eq(7, pos[2])
  end)

  it('opened with correct position relative to another window', function()
    local pos = exec_lua([[
      local bufnr = vim.api.nvim_create_buf(false, true)

      local par_opts = {
        width = 50,
        height = 50,
        col = 7,
        row = 9,
        relative = 'editor',
        style = 'minimal'
      }

      local par_win_id = vim.api.nvim_open_win(bufnr, false, par_opts)

      local opts = {
        width = 10,
        height = 10,
        col = 7,
        row = 9,
        relative = 'win',
        style = 'minimal',
        win = par_win_id
      }

      local win_id = vim.api.nvim_open_win(bufnr, false, opts)

      return vim.api.nvim_win_get_position(win_id)
    ]])

    eq(18, pos[1])
    eq(14, pos[2])
  end)


  it('opened with correct position relative to another relative window', function()
    local pos = exec_lua([[
      local bufnr = vim.api.nvim_create_buf(false, true)

      local root_opts = {
        width = 50,
        height = 50,
        col = 7,
        row = 9,
        relative = 'editor',
        style = 'minimal'
      }

      local root_win_id = vim.api.nvim_open_win(bufnr, false, root_opts)

      local par_opts = {
        width = 20,
        height = 20,
        col = 2,
        row = 3,
        relative = 'win',
        win = root_win_id,
        style = 'minimal'
      }

      local par_win_id = vim.api.nvim_open_win(bufnr, false, par_opts)

      local opts = {
        width = 10,
        height = 10,
        col = 3,
        row = 2,
        relative = 'win',
        win = par_win_id,
        style = 'minimal'
      }

      local win_id = vim.api.nvim_open_win(bufnr, false, opts)

      return vim.api.nvim_win_get_position(win_id)
    ]])

    eq(14, pos[1])
    eq(12, pos[2])
  end)

  it('is not operated on by windo when non-focusable #15374', function()
    command([[
      let winids = []
      windo call add(winids, win_getid())
    ]])
    local windo_count_before = eval('len(winids)')
    local winid = exec_lua([[
      local bufnr = vim.api.nvim_create_buf(false, true)
      local opts = {
        relative = 'editor',
        focusable = false,
        height = 5,
        width = 5,
        col = 5,
        row = 5,
      }
      return vim.api.nvim_open_win(bufnr, false, opts)
    ]])
    command([[
      let winids = []
      windo call add(winids, win_getid())
    ]])
    local windo_count_after = eval('len(winids)')
    eq(windo_count_before, windo_count_after)
    eq(false, tbl_contains(eval('winids'), winid))
  end)

  it('is operated on by windo when focusable', function()
    command([[
      let winids = []
      windo call add(winids, win_getid())
    ]])
    local windo_count_before = eval('len(winids)')
    local winid = exec_lua([[
      local bufnr = vim.api.nvim_create_buf(false, true)
      local opts = {
        relative = 'editor',
        focusable = true,
        height = 5,
        width = 5,
        col = 5,
        row = 5,
      }
      return vim.api.nvim_open_win(bufnr, false, opts)
    ]])
    command([[
      let winids = []
      windo call add(winids, win_getid())
    ]])
    local windo_count_after = eval('len(winids)')
    eq(windo_count_before + 1, windo_count_after)
    eq(true, tbl_contains(eval('winids'), winid))
  end)

  it('is not active after windo when non-focusable #15374', function()
    local winid = exec_lua([[
      local bufnr = vim.api.nvim_create_buf(false, true)
      local opts = {
        relative = 'editor',
        focusable = false,
        height = 5,
        width = 5,
        col = 5,
        row = 5,
      }
      return vim.api.nvim_open_win(bufnr, false, opts)
    ]])
    command('windo echo')
    neq(winid, eval('win_getid()'))
  end)

  it('is active after windo when focusable', function()
    local winid = exec_lua([[
      local bufnr = vim.api.nvim_create_buf(false, true)
      local opts = {
        relative = 'editor',
        focusable = true,
        height = 5,
        width = 5,
        col = 5,
        row = 5,
      }
      return vim.api.nvim_open_win(bufnr, false, opts)
    ]])
    command('windo echo')
    eq(winid, eval('win_getid()'))
  end)

  it('supports windo with focusable and non-focusable floats', function()
    local winids = exec_lua([[
      local result = {vim.api.nvim_get_current_win()}
      local bufnr = vim.api.nvim_create_buf(false, true)
      local opts = {
        relative = 'editor',
        focusable = false,
        height = 5,
        width = 5,
        col = 5,
        row = 5,
      }
      vim.api.nvim_open_win(bufnr, false, opts)
      opts.focusable = true
      table.insert(result, vim.api.nvim_open_win(bufnr, false, opts))
      opts.focusable = false
      vim.api.nvim_open_win(bufnr, false, opts)
      opts.focusable = true
      table.insert(result, vim.api.nvim_open_win(bufnr, false, opts))
      opts.focusable = false
      vim.api.nvim_open_win(bufnr, false, opts)
      return result
    ]])
    table.sort(winids)
    command([[
      let winids = []
      windo call add(winids, win_getid())
      call sort(winids)
    ]])
    eq(winids, eval('winids'))
  end)

  it("open does not trigger BufEnter #15300", function()
    local res = exec_lua[[
      local times = {}
      local buf = vim.api.nvim_create_buf(fasle, true)
      vim.api.nvim_create_autocmd('BufEnter', {
        callback = function(opt)
          if opt.buf == buf then
            times[#times + 1] = 1
          end
        end
      })
      local win_id
      local fconfig = {
        relative = 'editor',
        row = 10,
        col = 10,
        width = 10,
        height = 10,
      }
      --enter is false doesn't trigger
      win_id = vim.api.nvim_open_win(buf, false, fconfig)
      vim.api.nvim_win_close(win_id, true)
      times[#times + 1] = #times == 0 and true or nil

      --enter is true trigger
      win_id = vim.api.nvim_open_win(buf, true, fconfig)
      vim.api.nvim_win_close(win_id, true)
      times[#times + 1] = #times == 2 and true or nil

      --enter is true and fconfig.noautocmd is true doesn't trigger
      fconfig.noautocmd = true
      win_id = vim.api.nvim_open_win(buf, true, fconfig)
      vim.api.nvim_win_close(win_id, true)
      times[#times + 1] = #times == 2 and true or nil

      return times
    ]]
    eq({true, 1, true}, res)
  end)

  it('no crash with bufpos and non-existent window', function()
    command('new')
    local closed_win = api.nvim_get_current_win()
    command('close')
    local buf = api.nvim_create_buf(false,false)
    api.nvim_open_win(buf, true, {relative='win', win=closed_win, width=1, height=1, bufpos={0,0}})
    assert_alive()
  end)

  it("no segfault when setting minimal style after clearing local 'fillchars' #19510", function()
    local float_opts = {relative = 'editor', row = 1, col = 1, width = 1, height = 1}
    local float_win = api.nvim_open_win(0, true, float_opts)
    api.nvim_set_option_value('fillchars', NIL, {win=float_win})
    float_opts.style = 'minimal'
    api.nvim_win_set_config(float_win, float_opts)
    assert_alive()
    end)

    it("should re-apply 'style' when present", function()
    local float_opts = {style = 'minimal', relative = 'editor', row = 1, col = 1, width = 1, height = 1}
    local float_win = api.nvim_open_win(0, true, float_opts)
    api.nvim_set_option_value('number', true, { win = float_win })
    float_opts.row = 2
    api.nvim_win_set_config(float_win, float_opts)
    eq(false, api.nvim_get_option_value('number', { win = float_win }))
  end)

  it("should not re-apply 'style' when missing", function()
    local float_opts = {style = 'minimal', relative = 'editor', row = 1, col = 1, width = 1, height = 1}
    local float_win = api.nvim_open_win(0, true, float_opts)
    api.nvim_set_option_value('number', true, { win = float_win })
    float_opts.row = 2
    float_opts.style = nil
    api.nvim_win_set_config(float_win, float_opts)
    eq(true, api.nvim_get_option_value('number', { win = float_win }))
  end)

  it("'scroll' is computed correctly when opening float with splitkeep=screen #20684", function()
    api.nvim_set_option_value('splitkeep', 'screen', {})
    local float_opts = {relative = 'editor', row = 1, col = 1, width = 10, height = 10}
    local float_win = api.nvim_open_win(0, true, float_opts)
    eq(5, api.nvim_get_option_value('scroll', {win=float_win}))
  end)

  it(':unhide works when there are floating windows', function()
    local float_opts = {relative = 'editor', row = 1, col = 1, width = 5, height = 5}
    local w0 = curwin()
    api.nvim_open_win(0, false, float_opts)
    api.nvim_open_win(0, false, float_opts)
    eq(3, #api.nvim_list_wins())
    command('unhide')
    eq({ w0 }, api.nvim_list_wins())
  end)

  it(':all works when there are floating windows', function()
    command('args Xa.txt')
    local float_opts = {relative = 'editor', row = 1, col = 1, width = 5, height = 5}
    local w0 = curwin()
    api.nvim_open_win(0, false, float_opts)
    api.nvim_open_win(0, false, float_opts)
    eq(3, #api.nvim_list_wins())
    command('all')
    eq({ w0 }, api.nvim_list_wins())
  end)

  describe('with only one tabpage,', function()
    local float_opts = {relative = 'editor', row = 1, col = 1, width = 1, height = 1}
    local old_buf, old_win
    before_each(function()
      insert('foo')
      old_buf = curbuf()
      old_win = curwin()
    end)
    describe('closing the last non-floating window gives E444', function()
      before_each(function()
        api.nvim_open_win(old_buf, true, float_opts)
      end)
      it('if called from non-floating window', function()
        api.nvim_set_current_win(old_win)
        eq('Vim:E444: Cannot close last window',
           pcall_err(api.nvim_win_close, old_win, false))
      end)
      it('if called from floating window', function()
        eq('Vim:E444: Cannot close last window',
           pcall_err(api.nvim_win_close, old_win, false))
      end)
    end)
    describe("deleting the last non-floating window's buffer", function()
      describe('leaves one window with an empty buffer when there is only one buffer', function()
        local same_buf_float
        before_each(function()
          same_buf_float = api.nvim_open_win(old_buf, false, float_opts)
        end)
        after_each(function()
          eq(old_win, curwin())
          expect('')
          eq(1, #api.nvim_list_wins())
        end)
        it('if called from non-floating window', function()
          api.nvim_buf_delete(old_buf, {force = true})
        end)
        it('if called from floating window', function()
          api.nvim_set_current_win(same_buf_float)
          command('autocmd WinLeave * let g:win_leave = nvim_get_current_win()')
          command('autocmd WinEnter * let g:win_enter = nvim_get_current_win()')
          api.nvim_buf_delete(old_buf, {force = true})
          eq(same_buf_float, eval('g:win_leave'))
          eq(old_win, eval('g:win_enter'))
        end)
      end)
      describe('closes other windows with that buffer when there are other buffers', function()
        local same_buf_float, other_buf, other_buf_float
        before_each(function()
          same_buf_float = api.nvim_open_win(old_buf, false, float_opts)
          other_buf = api.nvim_create_buf(true, false)
          other_buf_float = api.nvim_open_win(other_buf, true, float_opts)
          insert('bar')
          api.nvim_set_current_win(old_win)
        end)
        after_each(function()
          eq(other_buf, curbuf())
          expect('bar')
          eq(2, #api.nvim_list_wins())
        end)
        it('if called from non-floating window', function()
          api.nvim_buf_delete(old_buf, {force = true})
          eq(old_win, curwin())
        end)
        it('if called from floating window with the same buffer', function()
          api.nvim_set_current_win(same_buf_float)
          command('autocmd WinLeave * let g:win_leave = nvim_get_current_win()')
          command('autocmd WinEnter * let g:win_enter = nvim_get_current_win()')
          api.nvim_buf_delete(old_buf, {force = true})
          eq(same_buf_float, eval('g:win_leave'))
          eq(old_win, eval('g:win_enter'))
          eq(old_win, curwin())
        end)
        -- TODO: this case is too hard to deal with
        pending('if called from floating window with another buffer', function()
          api.nvim_set_current_win(other_buf_float)
          api.nvim_buf_delete(old_buf, {force = true})
        end)
      end)
      describe('creates an empty buffer when there is only one listed buffer', function()
        local same_buf_float, unlisted_buf_float
        before_each(function()
          same_buf_float = api.nvim_open_win(old_buf, false, float_opts)
          local unlisted_buf = api.nvim_create_buf(true, false)
          unlisted_buf_float = api.nvim_open_win(unlisted_buf, true, float_opts)
          insert('unlisted')
          command('set nobuflisted')
          api.nvim_set_current_win(old_win)
        end)
        after_each(function()
          expect('')
          eq(2, #api.nvim_list_wins())
        end)
        it('if called from non-floating window', function()
          api.nvim_buf_delete(old_buf, {force = true})
          eq(old_win, curwin())
        end)
        it('if called from floating window with the same buffer', function()
          api.nvim_set_current_win(same_buf_float)
          command('autocmd WinLeave * let g:win_leave = nvim_get_current_win()')
          command('autocmd WinEnter * let g:win_enter = nvim_get_current_win()')
          api.nvim_buf_delete(old_buf, {force = true})
          eq(same_buf_float, eval('g:win_leave'))
          eq(old_win, eval('g:win_enter'))
          eq(old_win, curwin())
        end)
        -- TODO: this case is too hard to deal with
        pending('if called from floating window with an unlisted buffer', function()
          api.nvim_set_current_win(unlisted_buf_float)
          api.nvim_buf_delete(old_buf, {force = true})
        end)
      end)
    end)
    describe('with splits, deleting the last listed buffer creates an empty buffer', function()
      describe('when a non-floating window has an unlisted buffer', function()
        local same_buf_float
        before_each(function()
          command('botright vnew')
          insert('unlisted')
          command('set nobuflisted')
          api.nvim_set_current_win(old_win)
          same_buf_float = api.nvim_open_win(old_buf, false, float_opts)
        end)
        after_each(function()
          expect('')
          eq(2, #api.nvim_list_wins())
        end)
        it('if called from non-floating window with the deleted buffer', function()
          api.nvim_buf_delete(old_buf, {force = true})
          eq(old_win, curwin())
        end)
        it('if called from floating window with the deleted buffer', function()
          api.nvim_set_current_win(same_buf_float)
          api.nvim_buf_delete(old_buf, {force = true})
          eq(same_buf_float, curwin())
        end)
      end)
    end)
  end)

  describe('with multiple tabpages but only one listed buffer,', function()
    local float_opts = {relative = 'editor', row = 1, col = 1, width = 1, height = 1}
    local unlisted_buf, old_buf, old_win
    before_each(function()
      insert('unlisted')
      command('set nobuflisted')
      unlisted_buf = curbuf()
      command('tabnew')
      insert('foo')
      old_buf = curbuf()
      old_win = curwin()
    end)
    describe('without splits, deleting the last listed buffer creates an empty buffer', function()
      local same_buf_float
      before_each(function()
        api.nvim_set_current_win(old_win)
        same_buf_float = api.nvim_open_win(old_buf, false, float_opts)
      end)
      after_each(function()
        expect('')
        eq(2, #api.nvim_list_wins())
        eq(2, #api.nvim_list_tabpages())
      end)
      it('if called from non-floating window', function()
        api.nvim_buf_delete(old_buf, {force = true})
        eq(old_win, curwin())
      end)
      it('if called from non-floating window in another tabpage', function()
        command('tab split')
        eq(3, #api.nvim_list_tabpages())
        api.nvim_buf_delete(old_buf, {force = true})
      end)
      it('if called from floating window with the same buffer', function()
        api.nvim_set_current_win(same_buf_float)
        command('autocmd WinLeave * let g:win_leave = nvim_get_current_win()')
        command('autocmd WinEnter * let g:win_enter = nvim_get_current_win()')
        api.nvim_buf_delete(old_buf, {force = true})
        eq(same_buf_float, eval('g:win_leave'))
        eq(old_win, eval('g:win_enter'))
        eq(old_win, curwin())
      end)
    end)
    describe('with splits, deleting the last listed buffer creates an empty buffer', function()
      local same_buf_float
      before_each(function()
        command('botright vsplit')
        api.nvim_set_current_buf(unlisted_buf)
        api.nvim_set_current_win(old_win)
        same_buf_float = api.nvim_open_win(old_buf, false, float_opts)
      end)
      after_each(function()
        expect('')
        eq(3, #api.nvim_list_wins())
        eq(2, #api.nvim_list_tabpages())
      end)
      it('if called from non-floating window with the deleted buffer', function()
        api.nvim_buf_delete(old_buf, {force = true})
        eq(old_win, curwin())
      end)
      it('if called from floating window with the deleted buffer', function()
        api.nvim_set_current_win(same_buf_float)
        api.nvim_buf_delete(old_buf, {force = true})
        eq(same_buf_float, curwin())
      end)
    end)
  end)

  describe('with multiple tabpages and multiple listed buffers,', function()
    local float_opts = {relative = 'editor', row = 1, col = 1, width = 1, height = 1}
    local old_tabpage, old_buf, old_win
    before_each(function()
      old_tabpage = curtab()
      insert('oldtab')
      command('tabnew')
      old_buf = curbuf()
      old_win = curwin()
    end)
    describe('closing the last non-floating window', function()
      describe('closes the tabpage when all floating windows are closeable', function()
        local same_buf_float
        before_each(function()
          same_buf_float = api.nvim_open_win(old_buf, false, float_opts)
        end)
        after_each(function()
          eq(old_tabpage, curtab())
          expect('oldtab')
          eq(1, #api.nvim_list_tabpages())
        end)
        it('if called from non-floating window', function()
          api.nvim_win_close(old_win, false)
        end)
        it('if called from floating window', function()
          api.nvim_set_current_win(same_buf_float)
          api.nvim_win_close(old_win, false)
        end)
      end)
      describe('gives E5601 when there are non-closeable floating windows', function()
        local other_buf_float
        before_each(function()
          command('set nohidden')
          local other_buf = api.nvim_create_buf(true, false)
          other_buf_float = api.nvim_open_win(other_buf, true, float_opts)
          insert('foo')
          api.nvim_set_current_win(old_win)
        end)
        it('if called from non-floating window', function()
          eq('Vim:E5601: Cannot close window, only floating window would remain',
             pcall_err(api.nvim_win_close, old_win, false))
        end)
        it('if called from floating window', function()
          api.nvim_set_current_win(other_buf_float)
          eq('Vim:E5601: Cannot close window, only floating window would remain',
             pcall_err(api.nvim_win_close, old_win, false))
        end)
      end)
    end)
    describe("deleting the last non-floating window's buffer", function()
      describe('closes the tabpage when all floating windows are closeable', function()
        local same_buf_float, other_buf, other_buf_float
        before_each(function()
          same_buf_float = api.nvim_open_win(old_buf, false, float_opts)
          other_buf = api.nvim_create_buf(true, false)
          other_buf_float = api.nvim_open_win(other_buf, true, float_opts)
          api.nvim_set_current_win(old_win)
        end)
        after_each(function()
          eq(old_tabpage, curtab())
          expect('oldtab')
          eq(1, #api.nvim_list_tabpages())
        end)
        it('if called from non-floating window', function()
          api.nvim_buf_delete(old_buf, {force = false})
        end)
        it('if called from floating window with the same buffer', function()
          api.nvim_set_current_win(same_buf_float)
          api.nvim_buf_delete(old_buf, {force = false})
        end)
        -- TODO: this case is too hard to deal with
        pending('if called from floating window with another buffer', function()
          api.nvim_set_current_win(other_buf_float)
          api.nvim_buf_delete(old_buf, {force = false})
        end)
      end)
      -- TODO: what to do when there are non-closeable floating windows?
    end)
  end)

  local function with_ext_multigrid(multigrid)
    local screen, attrs
    before_each(function()
      screen = Screen.new(40,7)
      screen:attach {ext_multigrid=multigrid}
      attrs = {
        [0] = {bold=true, foreground=Screen.colors.Blue},
        [1] = {background = Screen.colors.LightMagenta},
        [2] = {background = Screen.colors.LightMagenta, bold = true, foreground = Screen.colors.Blue1},
        [3] = {bold = true},
        [4] = {bold = true, reverse = true},
        [5] = {reverse = true},
        [6] = {background = Screen.colors.LightMagenta, bold = true, reverse = true},
        [7] = {foreground = Screen.colors.White, background = Screen.colors.Red},
        [8] = {bold = true, foreground = Screen.colors.SeaGreen4},
        [9] = {background = Screen.colors.LightGrey, underline = true},
        [10] = {background = Screen.colors.LightGrey, underline = true, bold = true, foreground = Screen.colors.Magenta},
        [11] = {bold = true, foreground = Screen.colors.Magenta},
        [12] = {background = Screen.colors.Red, bold = true, foreground = Screen.colors.Blue1},
        [13] = {background = Screen.colors.WebGray},
        [14] = {foreground = Screen.colors.Brown},
        [15] = {background = Screen.colors.Grey20},
        [16] = {background = Screen.colors.Grey20, bold = true, foreground = Screen.colors.Blue1},
        [17] = {background = Screen.colors.Yellow},
        [18] = {foreground = Screen.colors.Brown, background = Screen.colors.Grey20},
        [19] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray},
        [20] = {bold = true, foreground = Screen.colors.Brown},
        [21] = {background = Screen.colors.Gray90},
        [22] = {background = Screen.colors.LightRed},
        [23] = {foreground = Screen.colors.Black, background = Screen.colors.White};
        [24] = {foreground = Screen.colors.Black, background = Screen.colors.Grey80};
        [25] = {blend = 100, background = Screen.colors.Gray0};
        [26] = {blend = 80, background = Screen.colors.Gray0};
        [27] = {foreground = Screen.colors.Black, background = Screen.colors.LightGrey};
        [28] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey};
      }
      screen:set_default_attr_ids(attrs)
    end)

    it('can be created and reconfigured', function()
      local buf = api.nvim_create_buf(false,false)
      local win = api.nvim_open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
      local expected_pos = {
          [4]={1001, 'NW', 1, 2, 5, true},
      }

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~    }{1:                    }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                                       }|*2
                                                  |
          ]])
      end


      api.nvim_win_set_config(win, {relative='editor', row=0, col=10})
      expected_pos[4][4] = 0
      expected_pos[4][5] = 10
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:                    }          |
          {0:~         }{2:~                   }{0:          }|
          {0:~                                       }|*4
                                                  |
        ]])
      end

      api.nvim_win_close(win, false)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ]])
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|*5
                                                  |
        ]])
      end
    end)

    it('window position fixed', function()
      command('rightbelow 20vsplit')
      local buf = api.nvim_create_buf(false,false)
      local win = api.nvim_open_win(buf, false, {
        relative='win', width=15, height=2, row=2, col=10, anchor='NW', fixed=true})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------]{5:│}[4:--------------------]|*5
          {5:[No Name]           }{4:[No Name]           }|
          [3:----------------------------------------]|
        ## grid 2
                             |
          {0:~                  }|*4
        ## grid 3
                                                  |
        ## grid 4
          ^                    |
          {0:~                   }|*4
        ## grid 5
          {1:               }|
          {2:~              }|
        ]], float_pos={
          [5] = {1002, "NW", 4, 2, 10, true};
        }}
      else
        screen:expect([[
                             {5:│}^                    |
          {0:~                  }{5:│}{0:~                   }|
          {0:~                  }{5:│}{0:~         }{1:          }|
          {0:~                  }{5:│}{0:~         }{2:~         }|
          {0:~                  }{5:│}{0:~                   }|
          {5:[No Name]           }{4:[No Name]           }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {fixed=false})

      if multigrid then
        screen:expect_unchanged()
      else
        screen:expect([[
                             {5:│}^                    |
          {0:~                  }{5:│}{0:~                   }|
          {0:~                  }{5:│}{0:~    }{1:               }|
          {0:~                  }{5:│}{0:~    }{2:~              }|
          {0:~                  }{5:│}{0:~                   }|
          {5:[No Name]           }{4:[No Name]           }|
                                                  |
        ]])
      end
    end)

    it('draws correctly with redrawdebug=compositor', function()
      -- NB: we do not test that it produces the "correct" debug info
      -- (as it is intermediate only, and is allowed to change by internal
      -- refactors). Only check that it doesn't cause permanent glitches,
      -- or something.
      command("set redrawdebug=compositor")
      command("set wd=1")
      local buf = api.nvim_create_buf(false,false)
      local win = api.nvim_open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
      local expected_pos = {
          [4]={1001, 'NW', 1, 2, 5, true},
      }

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~    }{1:                    }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                                       }|*2
                                                  |
          ]])
      end


      api.nvim_win_set_config(win, {relative='editor', row=0, col=10})
      expected_pos[4][4] = 0
      expected_pos[4][5] = 10
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:                    }          |
          {0:~         }{2:~                   }{0:          }|
          {0:~                                       }|*4
                                                  |
        ]])
      end

      api.nvim_win_close(win, false)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ]])
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|*5
                                                  |
        ]])
      end
    end)

    it('return their configuration', function()
      local buf = api.nvim_create_buf(false, false)
      local win = api.nvim_open_win(buf, false, {relative='editor', width=20, height=2, row=3, col=5, zindex=60})
      local expected = {anchor='NW', col=5, external=false, focusable=true, height=2, relative='editor', row=3, width=20, zindex=60, hide=false}
      eq(expected, api.nvim_win_get_config(win))
      eq(true, exec_lua([[
        local expected, win = ...
        local actual = vim.api.nvim_win_get_config(win)
        for k,v in pairs(expected) do
          if v ~= actual[k] then
            error(k)
          end
        end
        return true]], expected, win))

      eq({external=false, focusable=true, hide=false, relative='',split="left",width=40,height=6}, api.nvim_win_get_config(0))

      if multigrid then
        api.nvim_win_set_config(win, {external=true, width=10, height=1})
        eq({external=true,focusable=true,width=10,height=1,relative='',hide=false}, api.nvim_win_get_config(win))
      end
    end)

    it('defaults to NormalFloat highlight and inherited options', function()
      command('set number')
      command('hi NormalFloat guibg=#333333 guifg=NONE')
      feed('ix<cr>y<cr><esc>gg')
      local win = api.nvim_open_win(0, false, {relative='editor', width=20, height=4, row=4, col=10})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          {14:  1 }^x                                   |
          {14:  2 }y                                   |
          {14:  3 }                                    |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {18:  1 }{15:x               }|
          {18:  2 }{15:y               }|
          {18:  3 }{15:                }|
          {16:~                   }|
        ]], float_pos={[4] = {1001, "NW", 1, 4, 10, true}}}
      else
        screen:expect([[
          {14:  1 }^x                                   |
          {14:  2 }y                                   |
          {14:  3 }      {18:  1 }{15:x               }          |
          {0:~         }{18:  2 }{15:y               }{0:          }|
          {0:~         }{18:  3 }{15:                }{0:          }|
          {0:~         }{16:~                   }{0:          }|
                                                  |
        ]])
      end

      local buf = api.nvim_create_buf(false, true)
      api.nvim_win_set_buf(win, buf)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          {14:  1 }^x                                   |
          {14:  2 }y                                   |
          {14:  3 }                                    |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {18:  1 }{15:                }|
          {16:~                   }|*3
        ]], float_pos={[4] = {1001, "NW", 1, 4, 10, true}}}
      else
        screen:expect([[
          {14:  1 }^x                                   |
          {14:  2 }y                                   |
          {14:  3 }      {18:  1 }{15:                }          |
          {0:~         }{16:~                   }{0:          }|*3
                                                  |
        ]])
      end
    end)

    it("can use 'minimal' style", function()
      command('set number')
      command('set signcolumn=yes')
      command('set colorcolumn=1')
      command('set cursorline')
      command('set foldcolumn=1')
      command('hi NormalFloat guibg=#333333 guifg=NONE')
      feed('ix<cr>y<cr><esc>gg')
      local win = api.nvim_open_win(0, false, {relative='editor', width=20, height=4, row=4, col=10, style='minimal'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }                                |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {15:x                   }|
          {15:y                   }|
          {15:                    }|*2
        ]], float_pos={[4] = {1001, "NW", 1, 4, 10, true}}}
      else
        screen:expect{grid=[[
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }  {15:x                   }          |
          {0:~         }{15:y                   }{0:          }|
          {0:~         }{15:                    }{0:          }|*2
                                                  |
        ]]}
      end

      --  signcolumn=yes still works if there actually are signs
      command('sign define piet1 text=𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄ texthl=Search')
      command('sign place 1 line=1 name=piet1 buffer=1')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          {19: }{17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }                                |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{15:x                 }|
          {19:  }{15:y                 }|
          {19:  }{15:                  }|
          {15:                    }|
        ]], float_pos={[4] = {1001, "NW", 1, 4, 10, true}}}

      else
        screen:expect([[
          {19: }{17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }  {17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{15:x                 }          |
          {0:~         }{19:  }{15:y                 }{0:          }|
          {0:~         }{19:  }{15:                  }{0:          }|
          {0:~         }{15:                    }{0:          }|
                                                  |
        ]])
      end
      command('sign unplace 1 buffer=1')

      local buf = api.nvim_create_buf(false, true)
      api.nvim_win_set_buf(win, buf)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }                                |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {15:                    }|*4
        ]], float_pos={[4] = {1001, "NW", 1, 4, 10, true}}}
      else
        screen:expect([[
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }  {15:                    }          |
          {0:~         }{15:                    }{0:          }|*3
                                                  |
        ]])
      end
    end)

    it("would not break 'minimal' style with signcolumn=auto:[min]-[max]", function()
      command('set number')
      command('set signcolumn=auto:1-3')
      command('set colorcolumn=1')
      command('set cursorline')
      command('set foldcolumn=1')
      command('hi NormalFloat guibg=#333333 guifg=NONE')
      feed('ix<cr>y<cr><esc>gg')
      local win = api.nvim_open_win(0, false, {relative='editor', width=20, height=4, row=4, col=10, style='minimal'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }                                |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {15:x                   }|
          {15:y                   }|
          {15:                    }|*2
        ]], float_pos={[4] = {1001, "NW", 1, 4, 10, true}}}
      else
        screen:expect{grid=[[
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }  {15:x                   }          |
          {0:~         }{15:y                   }{0:          }|
          {0:~         }{15:                    }{0:          }|*2
                                                  |
        ]]}
      end

      command('sign define piet1 text=𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄ texthl=Search')
      command('sign place 1 line=1 name=piet1 buffer=1')
      --  signcolumn=auto:1-3 still works if there actually are signs
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          {19: }{17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }                                |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{15:x                 }|
          {19:  }{15:y                 }|
          {19:  }{15:                  }|
          {15:                    }|
        ]], float_pos={[4] = {1001, "NW", 1, 4, 10, true}}}

      else
        screen:expect([[
          {19: }{17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }  {17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{15:x                 }          |
          {0:~         }{19:  }{15:y                 }{0:          }|
          {0:~         }{19:  }{15:                  }{0:          }|
          {0:~         }{15:                    }{0:          }|
                                                  |
        ]])
      end
      command('sign unplace 1 buffer=1')

      local buf = api.nvim_create_buf(false, true)
      api.nvim_win_set_buf(win, buf)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }                                |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {15:                    }|*4
        ]], float_pos={[4] = {1001, "NW", 1, 4, 10, true}}}
      else
        screen:expect([[
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }  {15:                    }          |
          {0:~         }{15:                    }{0:          }|*3
                                                  |
        ]])
      end
    end)

    it("would not break 'minimal' style with statuscolumn set", function()
      command('set number')
      command('set signcolumn=yes')
      command('set colorcolumn=1')
      command('set cursorline')
      command('set foldcolumn=1')
      command('set statuscolumn=%l%s%C')
      command('hi NormalFloat guibg=#333333 guifg=NONE')
      feed('ix<cr>y<cr><esc>gg')
      api.nvim_open_win(0, false, {relative='editor', width=20, height=4, row=4, col=10, style='minimal'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          {20:1}{19:   }{20:   }{22:^x}{21:                                }|
          {14:2}{19:   }{14:   }{22:y}                                |
          {14:3}{19:   }{14:   }{22: }                                |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {15:x                   }|
          {15:y                   }|
          {15:                    }|*2
        ]], float_pos={[4] = {1001, "NW", 1, 4, 10, true}}}
      else
        screen:expect{grid=[[
          {20:1}{19:   }{20:   }{22:^x}{21:                                }|
          {14:2}{19:   }{14:   }{22:y}                                |
          {14:3}{19:   }{14:   }{22: }  {15:x                   }          |
          {0:~         }{15:y                   }{0:          }|
          {0:~         }{15:                    }{0:          }|*2
                                                  |
        ]]}
      end
    end)

    it('can have border', function()
      local buf = api.nvim_create_buf(false, false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {' halloj! ',
                                             ' BORDAA  '})
      local win = api.nvim_open_win(buf, false, {relative='editor', width=9, height=2, row=2, col=5, border="double"})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═════════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔═════════╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═════════╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {border="single"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌─────────┐}|
          {5:│}{1: halloj! }{5:│}|
          {5:│}{1: BORDAA  }{5:│}|
          {5:└─────────┘}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:┌─────────┐}{0:                        }|
          {0:~    }{5:│}{1: halloj! }{5:│}{0:                        }|
          {0:~    }{5:│}{1: BORDAA  }{5:│}{0:                        }|
          {0:~    }{5:└─────────┘}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {border="rounded"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╭─────────╮}|
          {5:│}{1: halloj! }{5:│}|
          {5:│}{1: BORDAA  }{5:│}|
          {5:╰─────────╯}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╭─────────╮}{0:                        }|
          {0:~    }{5:│}{1: halloj! }{5:│}{0:                        }|
          {0:~    }{5:│}{1: BORDAA  }{5:│}{0:                        }|
          {0:~    }{5:╰─────────╯}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {border="solid"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:           }|
          {5: }{1: halloj! }{5: }|
          {5: }{1: BORDAA  }{5: }|
          {5:           }|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:           }{0:                        }|
          {0:~    }{5: }{1: halloj! }{5: }{0:                        }|
          {0:~    }{5: }{1: BORDAA  }{5: }{0:                        }|
          {0:~    }{5:           }{0:                        }|
                                                  |
        ]]}
      end

      -- support: ascii char, UTF-8 char, composed char, highlight per char
      api.nvim_win_set_config(win, {border={"x", {"å", "ErrorMsg"}, {"\\"}, {"n̈̊", "Search"}}})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:x}{7:ååååååååå}{5:\}|
          {17:n̈̊}{1: halloj! }{17:n̈̊}|
          {17:n̈̊}{1: BORDAA  }{17:n̈̊}|
          {5:\}{7:ååååååååå}{5:x}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:x}{7:ååååååååå}{5:\}{0:                        }|
          {0:~    }{17:n̈̊}{1: halloj! }{17:n̈̊}{0:                        }|
          {0:~    }{17:n̈̊}{1: BORDAA  }{17:n̈̊}{0:                        }|
          {0:~    }{5:\}{7:ååååååååå}{5:x}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {border="none"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1: halloj! }|
          {1: BORDAA  }|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{1: halloj! }{0:                          }|
          {0:~    }{1: BORDAA  }{0:                          }|
          {0:~                                       }|*2
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {border={"", "", "", ">", "", "", "", "<"}})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:<}{1: halloj! }{5:>}|
          {5:<}{1: BORDAA  }{5:>}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:<}{1: halloj! }{5:>}{0:                        }|
          {0:~    }{5:<}{1: BORDAA  }{5:>}{0:                        }|
          {0:~                                       }|*2
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {border={"", "_", "", "", "", "-", "", ""}})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:_________}|
          {1: halloj! }|
          {1: BORDAA  }|
          {5:---------}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:_________}{0:                          }|
          {0:~    }{1: halloj! }{0:                          }|
          {0:~    }{1: BORDAA  }{0:                          }|
          {0:~    }{5:---------}{0:                          }|
                                                  |
        ]]}
      end

      insert [[
        neeed some dummy
        background text
        to show the effect
        of color blending
        of border shadow
      ]]

      api.nvim_win_set_config(win, {border="shadow"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
            neeed some dummy                      |
            background text                       |
            to show the effect                    |
            of color blending                     |
            of border shadow                      |
          ^                                        |
        ## grid 3
                                                  |
        ## grid 4
          {1: halloj! }{25: }|
          {1: BORDAA  }{26: }|
          {25: }{26:         }|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 6, curline = 5, curcol = 0, linecount = 6, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
            neeed some dummy                      |
            background text                       |
            to {1: halloj! }{23:e}ffect                    |
            of {1: BORDAA  }{24:n}ding                     |
            of {23:b}{24:order sha}dow                      |
          ^                                        |
                                                  |
        ]]}
      end
    end)

    it('validates title title_pos', function()
      local buf = api.nvim_create_buf(false,false)
      eq("title requires border to be set",
         pcall_err(api.nvim_open_win,buf, false, {
          relative='editor', width=9, height=2, row=2, col=5, title='Title',
         }))
      eq("title_pos requires title to be set",
         pcall_err(api.nvim_open_win,buf, false, {
          relative='editor', width=9, height=2, row=2, col=5,
          border='single', title_pos='left',
         }))
    end)

    it('validate title_pos in nvim_win_get_config', function()
      local title_pos = exec_lua([[
        local bufnr = vim.api.nvim_create_buf(false, false)
        local opts = {
          relative = 'editor',
          col = 2,
          row = 5,
          height = 2,
          width = 9,
          border = 'double',
          title = 'Test',
          title_pos = 'center'
        }

        local win_id = vim.api.nvim_open_win(bufnr, true, opts)
        return vim.api.nvim_win_get_config(win_id).title_pos
      ]])

      eq('center', title_pos)
    end)

    it('validates footer footer_pos', function()
      local buf = api.nvim_create_buf(false,false)
      eq("footer requires border to be set",
         pcall_err(api.nvim_open_win,buf, false, {
          relative='editor', width=9, height=2, row=2, col=5, footer='Footer',
         }))
      eq("footer_pos requires footer to be set",
         pcall_err(api.nvim_open_win,buf, false, {
          relative='editor', width=9, height=2, row=2, col=5,
          border='single', footer_pos='left',
         }))
    end)

    it('validate footer_pos in nvim_win_get_config', function()
      local footer_pos = exec_lua([[
        local bufnr = vim.api.nvim_create_buf(false, false)
        local opts = {
          relative = 'editor',
          col = 2,
          row = 5,
          height = 2,
          width = 9,
          border = 'double',
          footer = 'Test',
          footer_pos = 'center'
        }

        local win_id = vim.api.nvim_open_win(bufnr, true, opts)
        return vim.api.nvim_win_get_config(win_id).footer_pos
      ]])

      eq('center', footer_pos)
    end)

    it('center aligned title longer than window width #25746', function()
      local buf = api.nvim_create_buf(false, false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {' halloj! ',
                                             ' BORDAA  '})
      local win = api.nvim_open_win(buf, false, {
        relative='editor', width=9, height=2, row=2, col=5, border="double",
        title = "abcdefghijklmnopqrstuvwxyz",title_pos = "center",
      })

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔}{11:abcdefghi}{5:╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔}{11:abcdefghi}{5:╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═════════╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_close(win, false)
      assert_alive()
    end)

    it('border with title', function()
      local buf = api.nvim_create_buf(false, false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {' halloj! ',
                                             ' BORDAA  '})
      local win = api.nvim_open_win(buf, false, {
        relative='editor', width=9, height=2, row=2, col=5, border="double",
        title = "Left",title_pos = "left",
      })

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔}{11:Left}{5:═════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔}{11:Left}{5:═════╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═════════╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {title= "Center",title_pos="center"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═}{11:Center}{5:══╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔═}{11:Center}{5:══╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═════════╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {title= "Right",title_pos="right"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔════}{11:Right}{5:╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔════}{11:Right}{5:╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═════════╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {title= { {"🦄"},{"BB"}},title_pos="right"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═════}🦄BB{5:╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔═════}🦄BB{5:╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═════════╝}{0:                        }|
                                                  |
        ]]}
      end
    end)

    it('border with footer', function()
      local buf = api.nvim_create_buf(false, false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {' halloj! ',
                                             ' BORDAA  '})
      local win = api.nvim_open_win(buf, false, {
        relative='editor', width=9, height=2, row=2, col=5, border="double",
        footer = "Left",footer_pos = "left",
      })

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═════════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚}{11:Left}{5:═════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔═════════╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚}{11:Left}{5:═════╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {footer= "Center",footer_pos="center"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═════════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═}{11:Center}{5:══╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔═════════╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═}{11:Center}{5:══╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {footer= "Right",footer_pos="right"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═════════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚════}{11:Right}{5:╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔═════════╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚════}{11:Right}{5:╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {footer= { {"🦄"},{"BB"}},footer_pos="right"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═════════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════}🦄BB{5:╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔═════════╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═════}🦄BB{5:╝}{0:                        }|
                                                  |
        ]]}
      end
    end)

    it('border with title and footer', function()
      local buf = api.nvim_create_buf(false, false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {' halloj! ',
                                             ' BORDAA  '})
      local win = api.nvim_open_win(buf, false, {
        relative='editor', width=9, height=2, row=2, col=5, border="double",
        title = "Left", title_pos = "left", footer = "Right", footer_pos = "right",
      })

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔}{11:Left}{5:═════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚════}{11:Right}{5:╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔}{11:Left}{5:═════╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚════}{11:Right}{5:╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {title= "Center",title_pos="center",footer= "Center",footer_pos="center"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═}{11:Center}{5:══╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═}{11:Center}{5:══╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔═}{11:Center}{5:══╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═}{11:Center}{5:══╝}{0:                        }|
                                                  |
        ]]}
      end

      api.nvim_win_set_config(win, {title= "Right",title_pos="right",footer= "Left",footer_pos="left"})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔════}{11:Right}{5:╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚}{11:Left}{5:═════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔════}{11:Right}{5:╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚}{11:Left}{5:═════╝}{0:                        }|
                                                  |
        ]]}
      end

      command('hi B0 guibg=Red guifg=Black')
      command('hi B1 guifg=White')
      api.nvim_win_set_config(win, {
        title = {{"🦄"}, {"BB", {"B0", "B1"}}}, title_pos = "right",
        footer= {{"🦄"}, {"BB", {"B0", "B1"}}}, footer_pos = "right",
      })
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═════}🦄{7:BB}{5:╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════}🦄{7:BB}{5:╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{5:╔═════}🦄{7:BB}{5:╗}{0:                        }|
          {0:~    }{5:║}{1: halloj! }{5:║}{0:                        }|
          {0:~    }{5:║}{1: BORDAA  }{5:║}{0:                        }|
          {0:~    }{5:╚═════}🦄{7:BB}{5:╝}{0:                        }|
                                                  |
        ]]}
      end
    end)

    it('terminates border on edge of viewport when window extends past viewport', function()
      local buf = api.nvim_create_buf(false, false)
      api.nvim_open_win(buf, false, {relative='editor', width=40, height=7, row=0, col=0, border="single", zindex=201})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌────────────────────────────────────────┐}|
          {5:│}{1:                                        }{5:│}|
          {5:│}{2:~                                       }{5:│}|*6
          {5:└────────────────────────────────────────┘}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 0, 0, true, 201 }
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          {5:^┌──────────────────────────────────────┐}|
          {5:│}{1:                                      }{5:│}|
          {5:│}{2:~                                     }{5:│}|*4
          {5:└──────────────────────────────────────┘}|
        ]]}
      end
    end)

    it('with border show popupmenu', function()
      screen:try_resize(40,10)
      local buf = api.nvim_create_buf(false, false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'aaa aab ',
                                             'abb acc ', ''})
      api.nvim_open_win(buf, true, {relative='editor', width=9, height=3, row=0, col=5, border="double"})
      feed 'G'

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*9
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*8
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═════════╗}|
          {5:║}{1:aaa aab  }{5:║}|
          {5:║}{1:abb acc  }{5:║}|
          {5:║}{1:^         }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 0, 5, true };
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 2, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
               {5:╔═════════╗}                        |
          {0:~    }{5:║}{1:aaa aab  }{5:║}{0:                        }|
          {0:~    }{5:║}{1:abb acc  }{5:║}{0:                        }|
          {0:~    }{5:║}{1:^         }{5:║}{0:                        }|
          {0:~    }{5:╚═════════╝}{0:                        }|
          {0:~                                       }|*4
                                                  |
        ]]}
      end

      feed 'i<c-x><c-p>'
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*9
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*8
        ## grid 3
          {3:-- }{8:match 1 of 4}                         |
        ## grid 4
          {5:╔═════════╗}|
          {5:║}{1:aaa aab  }{5:║}|
          {5:║}{1:abb acc  }{5:║}|
          {5:║}{1:acc^      }{5:║}|
          {5:╚═════════╝}|
        ## grid 5
          {1: aaa            }|
          {1: aab            }|
          {1: abb            }|
          {13: acc            }|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 0, 5, true, 50 };
          [5] = { -1, "NW", 4, 4, 0, false, 100 };
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount=1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 2, curcol = 3, linecount=3, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
               {5:╔═════════╗}                        |
          {0:~    }{5:║}{1:aaa aab  }{5:║}{0:                        }|
          {0:~    }{5:║}{1:abb acc  }{5:║}{0:                        }|
          {0:~    }{5:║}{1:acc^      }{5:║}{0:                        }|
          {0:~    }{1: aaa            }{0:                   }|
          {0:~    }{1: aab            }{0:                   }|
          {0:~    }{1: abb            }{0:                   }|
          {0:~    }{13: acc            }{0:                   }|
          {0:~                                       }|
          {3:-- }{8:match 1 of 4}                         |
        ]]}
      end

      feed '<esc>'
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*9
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*8
        ## grid 3
                                                  |
        ## grid 4
          {5:╔═════════╗}|
          {5:║}{1:aaa aab  }{5:║}|
          {5:║}{1:abb acc  }{5:║}|
          {5:║}{1:ac^c      }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 0, 5, true };
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 2, curcol = 2, linecount = 3, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
               {5:╔═════════╗}                        |
          {0:~    }{5:║}{1:aaa aab  }{5:║}{0:                        }|
          {0:~    }{5:║}{1:abb acc  }{5:║}{0:                        }|
          {0:~    }{5:║}{1:ac^c      }{5:║}{0:                        }|
          {0:~    }{5:╚═════════╝}{0:                        }|
          {0:~                                       }|*4
                                                  |
        ]]}
      end

      exec([[
        nnoremenu Test.foo :
        nnoremenu Test.bar :
        nnoremenu Test.baz :
      ]])
      feed ':popup Test<CR>'
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*9
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*8
        ## grid 3
          :popup Test                             |
        ## grid 4
          {5:╔═════════╗}|
          {5:║}{1:aaa aab  }{5:║}|
          {5:║}{1:abb acc  }{5:║}|
          {5:║}{1:ac^c      }{5:║}|
          {5:╚═════════╝}|
        ## grid 5
          {1: foo }|
          {1: bar }|
          {1: baz }|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 0, 5, true };
          [5] = { -1, "NW", 4, 4, 2, false, 250 };
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 2, curcol = 2, linecount = 3, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
               {5:╔═════════╗}                        |
          {0:~    }{5:║}{1:aaa aab  }{5:║}{0:                        }|
          {0:~    }{5:║}{1:abb acc  }{5:║}{0:                        }|
          {0:~    }{5:║}{1:ac^c      }{5:║}{0:                        }|
          {0:~    }{5:╚═}{1: foo }{5:═══╝}{0:                        }|
          {0:~      }{1: bar }{0:                            }|
          {0:~      }{1: baz }{0:                            }|
          {0:~                                       }|*2
          :popup Test                             |
        ]]}
      end
    end)

    it('show ruler of current floating window', function()
      command 'set ruler'
      local buf = api.nvim_create_buf(false, false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'aaa aab ',
                                             'abb acc '})
      api.nvim_open_win(buf, true, {relative='editor', width=9, height=3, row=0, col=5})
      feed 'gg'

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                1,1           All |
        ## grid 4
          {1:^aaa aab  }|
          {1:abb acc  }|
          {2:~        }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
               {1:^aaa aab  }                          |
          {0:~    }{1:abb acc  }{0:                          }|
          {0:~    }{2:~        }{0:                          }|
          {0:~                                       }|*3
                                1,1           All |
        ]]}
      end

      feed 'w'
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                1,5           All |
        ## grid 4
          {1:aaa ^aab  }|
          {1:abb acc  }|
          {2:~        }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 4, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
               {1:aaa ^aab  }                          |
          {0:~    }{1:abb acc  }{0:                          }|
          {0:~    }{2:~        }{0:                          }|
          {0:~                                       }|*3
                                1,5           All |
        ]]}
      end
    end)

    it("correct ruler position in current float with 'rulerformat' set", function()
      command 'set ruler rulerformat=fish:<><'
      api.nvim_open_win(0, true, {relative='editor', width=9, height=3, row=0, col=5})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                fish:<><          |
        ## grid 4
          {1:^         }|
          {2:~        }|*2
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
               {1:^         }                          |
          {0:~    }{2:~        }{0:                          }|*2
          {0:~                                       }|*3
                                fish:<><          |
        ]]}
      end
    end)

    it('does not show ruler of not-last current float during ins-completion', function()
      screen:try_resize(50,9)
      command 'set ruler showmode'
      api.nvim_open_win(0, false, {relative='editor', width=3, height=3, row=0, col=0})
      api.nvim_open_win(0, false, {relative='editor', width=3, height=3, row=0, col=5})
      feed '<c-w>w'
      neq('', api.nvim_win_get_config(0).relative)
      neq(fn.winnr '$', fn.winnr())
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|*8
          [3:--------------------------------------------------]|
        ## grid 2
                                                            |
          {0:~                                                 }|*7
        ## grid 3
                                          0,0-1         All |
        ## grid 4
          {1:   }|
          {2:~  }|*2
        ## grid 5
          {1:^   }|
          {2:~  }|*2
        ]], float_pos={
          [5] = {1002, "NW", 1, 0, 5, true, 50};
          [4] = {1001, "NW", 1, 0, 0, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [5] = {win = 1002, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          {1:   }  {1:^   }                                          |
          {2:~  }{0:  }{2:~  }{0:                                          }|*2
          {0:~                                                 }|*5
                                          0,0-1         All |
        ]]}
      end
      feed 'i<c-x>'
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|*8
          [3:--------------------------------------------------]|
        ## grid 2
                                                            |
          {0:~                                                 }|*7
        ## grid 3
          {3:-- ^X mode (^]^D^E^F^I^K^L^N^O^Ps^U^V^Y)}          |
        ## grid 4
          {1:   }|
          {2:~  }|*2
        ## grid 5
          {1:^   }|
          {2:~  }|*2
        ]], float_pos={
          [5] = {1002, "NW", 1, 0, 5, true, 50};
          [4] = {1001, "NW", 1, 0, 0, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [5] = {win = 1002, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          {1:   }  {1:^   }                                          |
          {2:~  }{0:  }{2:~  }{0:                                          }|*2
          {0:~                                                 }|*5
          {3:-- ^X mode (^]^D^E^F^I^K^L^N^O^Ps^U^V^Y)}          |
        ]]}
      end
    end)

    it('can have minimum size', function()
      insert("the background text")
      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'x'})
      local win = api.nvim_open_win(buf, false, {relative='win', width=1, height=1, row=0, col=4, focusable=false})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          the background tex^t                     |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:x}|
        ]], float_pos={
          [4] = {1001, "NW", 2, 0, 4, false}
        }}
      else
        screen:expect([[
          the {1:x}ackground tex^t                     |
          {0:~                                       }|*5
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='win', row=0, col=15})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          the background tex^t                     |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:x}|
        ]], float_pos={
          [4] = {1001, "NW", 2, 0, 15, false}
        }}
      else
        screen:expect([[
          the background {1:x}ex^t                     |
          {0:~                                       }|*5
                                                  |
        ]])
      end

      api.nvim_win_close(win,false)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          the background tex^t                     |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ]])
      else
        screen:expect([[
          the background tex^t                     |
          {0:~                                       }|*5
                                                  |
        ]])
      end
    end)

    describe('no crash when rearranging windows', function()
      local function test_rearrange_windows(cmd)
        command('set laststatus=2')
        screen:try_resize(40, 13)

        command('args X1 X2 X3 X4 X5 X6')
        command('sargument 2')
        command('sargument 3')
        local w3 = curwin()
        command('sargument 4')
        local w4 = curwin()
        command('sargument 5')
        command('sargument 6')

        local float_opts = { relative = 'editor', row = 6, col = 0, width = 40, height = 1 }
        api.nvim_win_set_config(w3, float_opts)
        api.nvim_win_set_config(w4, float_opts)
        command('wincmd =')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [8:----------------------------------------]|*2
            {4:X6                                      }|
            [7:----------------------------------------]|*2
            {5:X5                                      }|
            [4:----------------------------------------]|*2
            {5:X2                                      }|
            [2:----------------------------------------]|*2
            {5:X1                                      }|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
                                                    |
            {0:~                                       }|
          ## grid 5
            {1:                                        }|
          ## grid 6
            {1:                                        }|
          ## grid 7
                                                    |
            {0:~                                       }|
          ## grid 8
            ^                                        |
            {0:~                                       }|
          ]], float_pos={
            [5] = {1002, "NW", 1, 6, 0, true, 50};
            [6] = {1003, "NW", 1, 6, 0, true, 50};
          }, win_viewport={
            [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [5] = {win = 1002, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [6] = {win = 1003, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [7] = {win = 1004, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [8] = {win = 1005, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          }}
        else
          screen:expect{grid=[[
            ^                                        |
            {0:~                                       }|
            {4:X6                                      }|
                                                    |
            {0:~                                       }|
            {5:X5                                      }|
            {1:                                        }|
            {0:~                                       }|
            {5:X2                                      }|
                                                    |
            {0:~                                       }|
            {5:X1                                      }|
                                                    |
          ]]}
        end

        command(cmd)
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            {4:X1                                      }|
            [4:----------------------------------------]|
            {5:X2                                      }|
            [9:----------------------------------------]|
            {5:X3                                      }|
            [10:----------------------------------------]|
            {5:X4                                      }|
            [7:----------------------------------------]|
            {5:X5                                      }|
            [8:----------------------------------------]|
            {5:X6                                      }|
            [3:----------------------------------------]|
          ## grid 2
            ^                                        |
          ## grid 3
                                                    |
          ## grid 4
                                                    |
          ## grid 7
                                                    |
          ## grid 8
                                                    |
          ## grid 9
                                                    |
          ## grid 10
                                                    |
          ]], win_viewport={
            [2] = {win = 1000, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [4] = {win = 1001, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [7] = {win = 1004, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [8] = {win = 1005, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [9] = {win = 1006, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [10] = {win = 1007, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          }}
        else
          screen:expect{grid=[[
            ^                                        |
            {4:X1                                      }|
                                                    |
            {5:X2                                      }|
                                                    |
            {5:X3                                      }|
                                                    |
            {5:X4                                      }|
                                                    |
            {5:X5                                      }|
                                                    |
            {5:X6                                      }|
                                                    |
          ]]}
        end
      end

      it('using :unhide', function()
        test_rearrange_windows('unhide')
      end)

      it('using :all', function()
        test_rearrange_windows('all')
      end)
    end)

    it('API has proper error messages', function()
      local buf = api.nvim_create_buf(false,false)
      eq("Invalid key: 'bork'",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=2,bork=true}))
      eq("'win' key is only valid with relative='win' and relative=''",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=2,relative='editor',row=0,col=0,win=0}))
      eq("floating windows cannot have 'vertical'",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=2,relative='editor',row=0,col=0,vertical=true}))
      eq("floating windows cannot have 'split'",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=2,relative='editor',row=0,col=0,split="left"}))
      eq("Only one of 'relative' and 'external' must be used",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=2,relative='editor',row=0,col=0,external=true}))
      eq("Invalid value of 'relative' key",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=2,relative='shell',row=0,col=0}))
      eq("Invalid value of 'anchor' key",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=2,relative='editor',row=0,col=0,anchor='bottom'}))
      eq("'relative' requires 'row'/'col' or 'bufpos'",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=2,relative='editor'}))
      eq("'width' key must be a positive Integer",
         pcall_err(api.nvim_open_win, buf, false, {width=-1,height=2,relative='editor', row=0, col=0}))
      eq("'height' key must be a positive Integer",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=-1,relative='editor', row=0, col=0}))
      eq("'height' key must be a positive Integer",
         pcall_err(api.nvim_open_win, buf, false, {width=20,height=0,relative='editor', row=0, col=0}))
      eq("Must specify 'width'",
         pcall_err(api.nvim_open_win, buf, false, {relative='editor', row=0, col=0}))
      eq("Must specify 'height'",
         pcall_err(api.nvim_open_win, buf, false, {relative='editor', row=0, col=0, width=2}))
    end)

    it('can be placed relative window or cursor', function()
      screen:try_resize(40,9)
      api.nvim_buf_set_lines(0, 0, -1, true, {'just some', 'example text'})
      feed('gge')
      local oldwin = api.nvim_get_current_win()
      command('below split')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|*3
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*3
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ]])
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      local buf = api.nvim_create_buf(false,false)
      -- no 'win' arg, relative default window
      local win = api.nvim_open_win(buf, false, {relative='win', width=20, height=2, row=0, col=10})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*3
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*3
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {1002, "NW", 4, 0, 10, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some {1:                    }          |
          example te{2:~                   }          |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='cursor', row=1, col=-2})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*3
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*3
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {1002, "NW", 4, 1, 1, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          e{1:                    }                   |
          {0:~}{2:~                   }{0:                   }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='cursor', row=0, col=0, anchor='SW'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*3
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*3
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {1002, "SW", 4, 0, 3, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~  }{1:                    }{0:                 }|
          {5:[No}{2:~                   }{5:                 }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='win', win=oldwin, row=1, col=10, anchor='NW'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*3
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*3
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {1002, "NW", 2, 1, 10, true}
        }}
      else
        screen:expect([[
          just some                               |
          example te{1:                    }          |
          {0:~         }{2:~                   }{0:          }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='win', win=oldwin, row=3, col=39, anchor='SE'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*3
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*3
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {1002, "SE", 2, 3, 39, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text       {1:                    } |
          {0:~                  }{2:~                   }{0: }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='win', win=0, row=0, col=50, anchor='NE'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*3
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*3
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {1002, "NE", 4, 0, 50, true}
        }, win_viewport = {
          [2] = {
              topline = 0,
              botline = 3,
              curline = 0,
              curcol = 3,
              linecount = 2,
              sum_scroll_delta = 0,
              win = 1000,
          },
          [4] = {
              topline = 0,
              botline = 3,
              curline = 0,
              curcol = 3,
              linecount = 2,
              sum_scroll_delta = 0,
              win = 1001
          },
          [5] = {
            topline = 0,
            botline = 2,
            curline = 0,
            curcol = 0,
            linecount = 1,
            sum_scroll_delta = 0,
            win = 1002
          }
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some           {1:                    }|
          example text        {2:~                   }|
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end
    end)

    it('always anchor to corner including border', function()
      screen:try_resize(40,13)
      api.nvim_buf_set_lines(0, 0, -1, true, {'just some example text', 'some more example text'})
      feed('ggeee')
      command('below split')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|*5
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*5
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some example text                  |
          some more example text                  |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          just some exampl^e text                  |
          some more example text                  |
          {0:~                                       }|*3
        ]])
      else
        screen:expect([[
          just some example text                  |
          some more example text                  |
          {0:~                                       }|*3
          {5:[No Name] [+]                           }|
          just some exampl^e text                  |
          some more example text                  |
          {0:~                                       }|*3
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      local buf = api.nvim_create_buf(false, false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {' halloj! ',
                                             ' BORDAA  '})
      local win = api.nvim_open_win(buf, false, {relative='cursor', width=9, height=2, row=1, col=-2, border="double"})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*5
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*5
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some example text                  |
          some more example text                  |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          just some exampl^e text                  |
          some more example text                  |
          {0:~                                       }|*3
        ## grid 5
          {5:╔═════════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [5] = {1002, "NW", 4, 1, 14, true}
        }}
      else
        screen:expect([[
          just some example text                  |
          some more example text                  |
          {0:~                                       }|*3
          {5:[No Name] [+]                           }|
          just some exampl^e text                  |
          some more exam{5:╔═════════╗}               |
          {0:~             }{5:║}{1: halloj! }{5:║}{0:               }|
          {0:~             }{5:║}{1: BORDAA  }{5:║}{0:               }|
          {0:~             }{5:╚═════════╝}{0:               }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='cursor', row=0, col=-2, anchor='NE'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*5
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*5
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some example text                  |
          some more example text                  |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          just some exampl^e text                  |
          some more example text                  |
          {0:~                                       }|*3
        ## grid 5
          {5:╔═════════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [5] = {1002, "NE", 4, 0, 14, true}
        }}
      else
        screen:expect([[
          just some example text                  |
          some more example text                  |
          {0:~                                       }|*3
          {5:[No Name] [+]                           }|
          jus{5:╔═════════╗}pl^e text                  |
          som{5:║}{1: halloj! }{5:║}ple text                  |
          {0:~  }{5:║}{1: BORDAA  }{5:║}{0:                          }|
          {0:~  }{5:╚═════════╝}{0:                          }|
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='cursor', row=1, col=-2, anchor='SE'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*5
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*5
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some example text                  |
          some more example text                  |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          just some exampl^e text                  |
          some more example text                  |
          {0:~                                       }|*3
        ## grid 5
          {5:╔═════════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [5] = {1002, "SE", 4, 1, 14, true}
        }}
      else
        screen:expect([[
          just some example text                  |
          some more example text                  |
          {0:~                                       }|
          {0:~  }{5:╔═════════╗}{0:                          }|
          {0:~  }{5:║}{1: halloj! }{5:║}{0:                          }|
          {5:[No║}{1: BORDAA  }{5:║                          }|
          jus{5:╚═════════╝}pl^e text                  |
          some more example text                  |
          {0:~                                       }|*3
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='cursor', row=0, col=-2, anchor='SW'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*5
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|*5
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some example text                  |
          some more example text                  |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          just some exampl^e text                  |
          some more example text                  |
          {0:~                                       }|*3
        ## grid 5
          {5:╔═════════╗}|
          {5:║}{1: halloj! }{5:║}|
          {5:║}{1: BORDAA  }{5:║}|
          {5:╚═════════╝}|
        ]], float_pos={
          [5] = {1002, "SW", 4, 0, 14, true}
        }}
      else
        screen:expect([[
          just some example text                  |
          some more example text                  |
          {0:~             }{5:╔═════════╗}{0:               }|
          {0:~             }{5:║}{1: halloj! }{5:║}{0:               }|
          {0:~             }{5:║}{1: BORDAA  }{5:║}{0:               }|
          {5:[No Name] [+] ╚═════════╝               }|
          just some exampl^e text                  |
          some more example text                  |
          {0:~                                       }|*3
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end
    end)

    it('anchored to another floating window updated in the same call #14735', function()
      feed('i<CR><CR><CR><Esc>')

      exec([[
        let b1 = nvim_create_buf(v:true, v:false)
        let b2 = nvim_create_buf(v:true, v:false)
        let b3 = nvim_create_buf(v:true, v:false)
        let b4 = nvim_create_buf(v:true, v:false)
        let b5 = nvim_create_buf(v:true, v:false)
        let b6 = nvim_create_buf(v:true, v:false)
        let b7 = nvim_create_buf(v:true, v:false)
        let b8 = nvim_create_buf(v:true, v:false)
        call setbufline(b1, 1, '1')
        call setbufline(b2, 1, '2')
        call setbufline(b3, 1, '3')
        call setbufline(b4, 1, '4')
        call setbufline(b5, 1, '5')
        call setbufline(b6, 1, '6')
        call setbufline(b7, 1, '7')
        call setbufline(b8, 1, '8')
        let o1 = #{relative: 'editor', row: 1, col: 10, width: 5, height: 1}
        let w1 = nvim_open_win(b1, v:false, o1)
        let o2 = extendnew(o1, #{col: 30})
        let w2 = nvim_open_win(b2, v:false, o2)
        let o3 = extendnew(o1, #{relative: 'win', win: w1, anchor: 'NE', col: 0})
        let w3 = nvim_open_win(b3, v:false, o3)
        let o4 = extendnew(o3, #{win: w2})
        let w4 = nvim_open_win(b4, v:false, o4)
        let o5 = extendnew(o3, #{win: w3, anchor: 'SE', row: 0})
        let w5 = nvim_open_win(b5, v:false, o5)
        let o6 = extendnew(o5, #{win: w4})
        let w6 = nvim_open_win(b6, v:false, o6)
        let o7 = extendnew(o5, #{win: w5, anchor: 'SW', col: 5})
        let w7 = nvim_open_win(b7, v:false, o7)
        let o8 = extendnew(o7, #{win: w6})
        let w8 = nvim_open_win(b8, v:false, o8)
      ]])
      if multigrid then
      screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |*3
          ^                                        |
          {0:~                                       }|*2
        ## grid 3
                                                  |
        ## grid 5
          {1:1    }|
        ## grid 6
          {1:2    }|
        ## grid 7
          {1:3    }|
        ## grid 8
          {1:4    }|
        ## grid 9
          {1:5    }|
        ## grid 10
          {1:6    }|
        ## grid 11
          {1:7    }|
        ## grid 12
          {1:8    }|
        ]], float_pos={
          [5] = {1002, "NW", 1, 1, 10, true, 50};
          [6] = {1003, "NW", 1, 1, 30, true, 50};
          [7] = {1004, "NE", 5, 1, 0, true, 50};
          [8] = {1005, "NE", 6, 1, 0, true, 50};
          [9] = {1006, "SE", 7, 0, 0, true, 50};
          [10] = {1007, "SE", 8, 0, 0, true, 50};
          [11] = {1008, "SW", 9, 0, 5, true, 50};
          [12] = {1009, "SW", 10, 0, 5, true, 50};
        }}
      else
        screen:expect([[
               {1:7    }               {1:8    }          |
          {1:5    }     {1:1    }     {1:6    }     {1:2    }     |
               {1:3    }               {1:4    }          |
          ^                                        |
          {0:~                                       }|*2
                                                  |
        ]])
      end

      -- Reconfigure in different directions
      exec([[
        let o1 = extendnew(o1, #{anchor: 'NW'})
        call nvim_win_set_config(w8, o1)
        let o2 = extendnew(o2, #{anchor: 'NW'})
        call nvim_win_set_config(w4, o2)
        let o3 = extendnew(o3, #{win: w8})
        call nvim_win_set_config(w2, o3)
        let o4 = extendnew(o4, #{win: w4})
        call nvim_win_set_config(w1, o4)
        let o5 = extendnew(o5, #{win: w2})
        call nvim_win_set_config(w6, o5)
        let o6 = extendnew(o6, #{win: w1})
        call nvim_win_set_config(w3, o6)
        let o7 = extendnew(o7, #{win: w6})
        call nvim_win_set_config(w5, o7)
        let o8 = extendnew(o8, #{win: w3})
        call nvim_win_set_config(w7, o8)
      ]])
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |*3
          ^                                        |
          {0:~                                       }|*2
        ## grid 3
                                                  |
        ## grid 5
          {1:1    }|
        ## grid 6
          {1:2    }|
        ## grid 7
          {1:3    }|
        ## grid 8
          {1:4    }|
        ## grid 9
          {1:5    }|
        ## grid 10
          {1:6    }|
        ## grid 11
          {1:7    }|
        ## grid 12
          {1:8    }|
        ]], float_pos={
          [5] = {1002, "NE", 8, 1, 0, true, 50};
          [6] = {1003, "NE", 12, 1, 0, true, 50};
          [7] = {1004, "SE", 5, 0, 0, true, 50};
          [8] = {1005, "NW", 1, 1, 30, true, 50};
          [9] = {1006, "SW", 10, 0, 5, true, 50};
          [10] = {1007, "SE", 6, 0, 0, true, 50};
          [11] = {1008, "SW", 7, 0, 5, true, 50};
          [12] = {1009, "NW", 1, 1, 10, true, 50};
        }}
      else
        screen:expect([[
               {1:5    }               {1:7    }          |
          {1:6    }     {1:8    }     {1:3    }     {1:4    }     |
               {1:2    }               {1:1    }          |
          ^                                        |
          {0:~                                       }|*2
                                                  |
        ]])
      end

      -- Not clear how cycles should behave, but they should not hang or crash
      exec([[
        let o1 = extendnew(o1, #{relative: 'win', win: w7})
        call nvim_win_set_config(w1, o1)
        let o2 = extendnew(o2, #{relative: 'win', win: w8})
        call nvim_win_set_config(w2, o2)
        let o3 = extendnew(o3, #{win: w1})
        call nvim_win_set_config(w3, o3)
        let o4 = extendnew(o4, #{win: w2})
        call nvim_win_set_config(w4, o4)
        let o5 = extendnew(o5, #{win: w3})
        call nvim_win_set_config(w5, o5)
        let o6 = extendnew(o6, #{win: w4})
        call nvim_win_set_config(w6, o6)
        let o7 = extendnew(o7, #{win: w5})
        call nvim_win_set_config(w7, o7)
        let o8 = extendnew(o8, #{win: w6})
        call nvim_win_set_config(w8, o8)
        redraw
      ]])
    end)

    it('can be placed relative text in a window', function()
      screen:try_resize(30,5)
      local firstwin = api.nvim_get_current_win()
      api.nvim_buf_set_lines(0, 0, -1, true, {'just some', 'example text that is wider than the window', '', '', 'more text'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------------]|*4
          [3:------------------------------]|
        ## grid 2
          ^just some                     |
          example text that is wider tha|
          n the window                  |
                                        |
        ## grid 3
                                        |
        ]]}
      else
        screen:expect{grid=[[
          ^just some                     |
          example text that is wider tha|
          n the window                  |
                                        |*2
        ]]}
      end

      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'some info!'})

      local win = api.nvim_open_win(buf, false, {relative='win', width=12, height=1, bufpos={1,32}})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------------]|*4
          [3:------------------------------]|
        ## grid 2
          ^just some                     |
          example text that is wider tha|
          n the window                  |
                                        |
        ## grid 3
                                        |
        ## grid 4
          {1:some info!  }|
        ]], float_pos={
          [4] = { 1001, "NW", 2, 3, 2, true }
        }}
      else
        screen:expect{grid=[[
          ^just some                     |
          example text that is wider tha|
          n the window                  |
            {1:some info!  }                |
                                        |
        ]]}
      end
      eq({relative='win', width=12, height=1, bufpos={1,32}, anchor='NW', hide=false,
          external=false, col=0, row=1, win=firstwin, focusable=true, zindex=50}, api.nvim_win_get_config(win))

      feed('<c-e>')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------------]|*4
          [3:------------------------------]|
        ## grid 2
          ^example text that is wider tha|
          n the window                  |
                                        |*2
        ## grid 3
                                        |
        ## grid 4
          {1:some info!  }|
        ]], float_pos={
          [4] = { 1001, "NW", 2, 2, 2, true },
        }}
      else
        screen:expect{grid=[[
          ^example text that is wider tha|
          n the window                  |
            {1:some info!  }                |
                                        |*2
        ]]}
      end


      screen:try_resize(45,5)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:---------------------------------------------]|*4
          [3:---------------------------------------------]|
        ## grid 2
          ^example text that is wider than the window   |
                                                       |*2
          more text                                    |
        ## grid 3
                                                       |
        ## grid 4
          {1:some info!  }|
        ]], float_pos={
          [4] = { 1001, "NW", 2, 1, 32, true }
        }}
      else
        -- note: appears misaligned due to cursor
        screen:expect{grid=[[
          ^example text that is wider than the window   |
                                          {1:some info!  } |
                                                       |
          more text                                    |
                                                       |
        ]]}
      end

      screen:try_resize(25,10)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|*9
          [3:-------------------------]|
        ## grid 2
          ^example text that is wide|
          r than the window        |
                                   |*2
          more text                |
          {0:~                        }|*4
        ## grid 3
                                   |
        ## grid 4
          {1:some info!  }|
        ]], float_pos={
          [4] = { 1001, "NW", 2, 2, 7, true }
        }}
      else
        screen:expect{grid=[[
          ^example text that is wide|
          r than the window        |
                 {1:some info!  }      |
                                   |
          more text                |
          {0:~                        }|*4
                                   |
        ]]}
      end

      api.nvim_win_set_config(win, {relative='win', bufpos={1,32}, anchor='SW'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|*9
          [3:-------------------------]|
        ## grid 2
          ^example text that is wide|
          r than the window        |
                                   |*2
          more text                |
          {0:~                        }|*4
        ## grid 3
                                   |
        ## grid 4
          {1:some info!  }|
        ]], float_pos={
          [4] = { 1001, "SW", 2, 1, 7, true }
        }}
      else
        screen:expect{grid=[[
          ^example{1:some info!  }s wide|
          r than the window        |
                                   |*2
          more text                |
          {0:~                        }|*4
                                   |
        ]]}
      end

      command('set laststatus=0')
      command('botright vnew')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----]{5:│}[5:--------------------]|*9
          [3:-------------------------]|
        ## grid 2
          exam|
          ple |
          text|
           tha|
          t is|
           wid|
          er t|
          han |
          the |
        ## grid 3
                                   |
        ## grid 4
          {1:some info!  }|
        ## grid 5
          ^                    |
          {0:~                   }|*8
        ]], float_pos={
          [4] = { 1001, "SW", 2, 8, 0, true }
        }}
      else
        screen:expect{grid=[[
          exam{5:│}^                    |
          ple {5:│}{0:~                   }|
          text{5:│}{0:~                   }|
           tha{5:│}{0:~                   }|
          t is{5:│}{0:~                   }|
           wid{5:│}{0:~                   }|
          er t{5:│}{0:~                   }|
          {1:some info!  }{0:             }|
          the {5:│}{0:~                   }|
                                   |
        ]]}
      end
      command('close')

      api.nvim_win_set_config(win, {relative='win', bufpos={1,32}, anchor='NW', col=-2})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|*9
          [3:-------------------------]|
        ## grid 2
          ^example text that is wide|
          r than the window        |
                                   |*2
          more text                |
          {0:~                        }|*4
        ## grid 3
                                   |
        ## grid 4
          {1:some info!  }|
        ]], float_pos={
          [4] = { 1001, "NW", 2, 2, 5, true }
        }}
      else
        screen:expect{grid=[[
          ^example text that is wide|
          r than the window        |
               {1:some info!  }        |
                                   |
          more text                |
          {0:~                        }|*4
                                   |
        ]]}
      end

      api.nvim_win_set_config(win, {relative='win', bufpos={1,32}, row=2})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|*9
          [3:-------------------------]|
        ## grid 2
          ^example text that is wide|
          r than the window        |
                                   |*2
          more text                |
          {0:~                        }|*4
        ## grid 3
                                   |
        ## grid 4
          {1:some info!  }|
        ]], float_pos={
          [4] = { 1001, "NW", 2, 3, 7, true }
        }}
      else
        screen:expect{grid=[[
          ^example text that is wide|
          r than the window        |
                                   |
                 {1:some info!  }      |
          more text                |
          {0:~                        }|*4
                                   |
        ]]}
      end

      command('%fold')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|*9
          [3:-------------------------]|
        ## grid 2
          {28:^+--  5 lines: just some··}|
          {0:~                        }|*8
        ## grid 3
                                   |
        ## grid 4
          {1:some info!  }|
        ]], float_pos={
          [4] = { 1001, "NW", 2, 2, 0, true }
        }}
      else
        screen:expect{grid=[[
          {28:^+--  5 lines: just some··}|
          {0:~                        }|
          {1:some info!  }{0:             }|
          {0:~                        }|*6
                                   |
        ]]}
      end
    end)

    it('validates cursor even when window is not entered', function()
      screen:try_resize(30,5)
      command("set nowrap")
      insert([[some text that is wider than the window]])
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|*4
          [3:------------------------------]|
        ## grid 2
          that is wider than the windo^w |
          {0:~                             }|*3
        ## grid 3
                                        |
        ]])
      else
        screen:expect([[
          that is wider than the windo^w |
          {0:~                             }|*3
                                        |
        ]])
      end

      local buf = api.nvim_create_buf(false,true)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'some floaty text'})
      api.nvim_open_win(buf, false, {relative='editor', width=20, height=1, row=3, col=1})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------------]|*4
          [3:------------------------------]|
        ## grid 2
          that is wider than the windo^w |
          {0:~                             }|*3
        ## grid 3
                                        |
        ## grid 4
          {1:some floaty text    }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 3, 1, true}
        }}
      else
        screen:expect([[
          that is wider than the windo^w |
          {0:~                             }|*2
          {0:~}{1:some floaty text    }{0:         }|
                                        |
        ]])
      end
    end)

    if multigrid then
      pending("supports second UI without multigrid", function()
        local session2 = helpers.connect(eval('v:servername'))
        print(session2:request("nvim_eval", "2+2"))
        local screen2 = Screen.new(40,7)
        screen2:attach(nil, session2)
        screen2:set_default_attr_ids(attrs)
        local buf = api.nvim_create_buf(false,false)
        api.nvim_open_win(buf, true, {relative='editor', width=20, height=2, row=2, col=5})
        local expected_pos = {
          [2]={1001, 'NW', 1, 2, 5}
        }
        screen:expect{grid=[[
        ## grid 1
                                                  |
          {0:~                                       }|*5
                                                  |
        ## grid 2
          {1:^                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
        screen2:expect([[
                                                  |
          {0:~                                       }|
          {0:~    }{1:^                    }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                                       }|*2
                                                  |
          ]])
      end)
    end


    it('handles resized screen', function()
      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'such', 'very', 'float'})
      local win = api.nvim_open_win(buf, false, {relative='editor', width=15, height=4, row=2, col=10})
      local expected_pos = {
          [4]={1001, 'NW', 1, 2, 10, true},
      }
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~         }{1:such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~         }{2:~              }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,5)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*4
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*3
        ## grid 3
                                                  |
        ## grid 4
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:such           }               |
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~         }{2:~              }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,4)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*3
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*2
        ## grid 3
                                                  |
        ## grid 4
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:such           }               |
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,3)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*2
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:such           }               |
          {0:~         }{1:very           }{0:               }|
                                                  |
        ]])
      end
      feed('<c-w>wjj')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*2
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {1:such           }|
          {1:very           }|
          {1:^float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                    {1:such           }               |
          {0:~         }{1:very           }{0:               }|
                    ^                              |
        ]])
      end

      screen:try_resize(40,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:such           }|
          {1:very           }|
          {1:^float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {0:~         }{1:such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:^float          }{0:               }|
          {0:~         }{2:~              }{0:               }|
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {height=3})
      feed('gg')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {0:~         }{1:^such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~                                       }|
                                                  |
        ]])
      end

      screen:try_resize(26,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------]|*6
          [3:--------------------------]|
        ## grid 2
                                    |
          {0:~                         }|*5
        ## grid 3
                                    |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                    |
          {0:~                         }|
          {0:~         }{1:^such           }{0: }|
          {0:~         }{1:very           }{0: }|
          {0:~         }{1:float          }{0: }|
          {0:~                         }|
                                    |
        ]])
      end

      screen:try_resize(25,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|*6
          [3:-------------------------]|
        ## grid 2
                                   |
          {0:~                        }|*5
        ## grid 3
                                   |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                   |
          {0:~                        }|
          {0:~         }{1:^such           }|
          {0:~         }{1:very           }|
          {0:~         }{1:float          }|
          {0:~                        }|
                                   |
        ]])
      end

      screen:try_resize(24,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------]|*6
          [3:------------------------]|
        ## grid 2
                                  |
          {0:~                       }|*5
        ## grid 3
                                  |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                  |
          {0:~                       }|
          {0:~        }{1:^such           }|
          {0:~        }{1:very           }|
          {0:~        }{1:float          }|
          {0:~                       }|
                                  |
        ]])
      end

      screen:try_resize(16,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------]|*6
          [3:----------------]|
        ## grid 2
                          |
          {0:~               }|*5
        ## grid 3
                          |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                          |
          {0:~               }|
          {0:~}{1:^such           }|
          {0:~}{1:very           }|
          {0:~}{1:float          }|
          {0:~               }|
                          |
        ]])
      end

      screen:try_resize(15,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:---------------]|*6
          [3:---------------]|
        ## grid 2
                         |
          {0:~              }|*5
        ## grid 3
                         |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                         |
          {0:~              }|
          {1:^such           }|
          {1:very           }|
          {1:float          }|
          {0:~              }|
                         |
        ]])
      end

      screen:try_resize(14,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------]|*6
          [3:--------------]|
        ## grid 2
                        |
          {0:~             }|*5
        ## grid 3
                        |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                        |
          {0:~             }|
          {1:^such          }|
          {1:very          }|
          {1:float         }|
          {0:~             }|
                        |
        ]])
      end

      screen:try_resize(12,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------]|*6
          [3:------------]|
        ## grid 2
                      |
          {0:~           }|*5
        ## grid 3
                      |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                      |
          {0:~           }|
          {1:^such        }|
          {1:very        }|
          {1:float       }|
          {0:~           }|
                      |
        ]])
      end

      -- Doesn't make much sense, but check nvim doesn't crash
      screen:try_resize(1,1)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------]|
          [3:------------]|
        ## grid 2
                      |
        ## grid 3
                      |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          {1:^such        }|
                      |
        ]])
      end

      screen:try_resize(40,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {0:~         }{1:^such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~                                       }|
                                                  |
        ]])
      end
    end)

    it('does not crash with inccommand #9379', function()
      local expected_pos = {
        [4]={1001, 'NW', 1, 2, 0, true},
      }

      command("set inccommand=split")
      command("set laststatus=2")

      local buf = api.nvim_create_buf(false,false)
      api.nvim_open_win(buf, true, {relative='editor', width=30, height=3, row=2, col=0})

      insert([[
      foo
      bar
      ]])

      if multigrid then
        screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*5
            {5:[No Name]                               }|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|*4
          ## grid 3
                                                    |
          ## grid 4
            {1:foo                           }|
            {1:bar                           }|
            {1:^                              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {1:foo                           }{0:          }|
          {1:bar                           }{0:          }|
          {1:^                              }{0:          }|
          {5:[No Name]                               }|
                                                  |
        ]])
      end

      feed(':%s/.')

      if multigrid then
        screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*5
            {5:[Preview]                               }|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
          ## grid 3
            :%s/.^                                   |
          ## grid 4
            {17:f}{1:oo                           }|
            {17:b}{1:ar                           }|
            {1:                              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {5:[No Name]                               }|
          {17:f}{1:oo                           }          |
          {17:b}{1:ar                           }          |
          {1:                              }{0:          }|
          {5:[Preview]                               }|
          :%s/.^                                   |
        ]])
      end

      feed('<Esc>')

      if multigrid then
        screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*5
            {5:[No Name]                               }|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|*4
          ## grid 3
                                                    |
          ## grid 4
            {1:foo                           }|
            {1:bar                           }|
            {1:^                              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {1:foo                           }{0:          }|
          {1:bar                           }{0:          }|
          {1:^                              }{0:          }|
          {5:[No Name]                               }|
                                                  |
        ]])
      end
    end)

    it('does not crash when set cmdheight #9680', function()
      local buf = api.nvim_create_buf(false,false)
      api.nvim_open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
      command("set cmdheight=2")
      eq(1, api.nvim_eval('1'))
    end)

    describe('and completion', function()
      before_each(function()
        local buf = api.nvim_create_buf(false,false)
        local win = api.nvim_open_win(buf, true, {relative='editor', width=12, height=4, row=2, col=5})
        api.nvim_set_option_value('winhl', 'Normal:ErrorMsg', {win=win})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {7:^            }|
            {12:~           }|*3
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:^            }{0:                       }|
            {0:~    }{12:~           }{0:                       }|*3
                                                    |
          ]])
        end
      end)

      it('with builtin popupmenu', function()
        feed('ix ')
        fn.complete(3, {'aa', 'word', 'longtext'})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa^        }|
            {12:~           }|*3
          ## grid 5
            {13: aa             }|
            {1: word           }|
            {1: longtext       }|
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true, 50},
            [5] = {-1, "NW", 4, 1, 1, false, 100}
          }}
        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x aa^        }{0:                       }|
            {0:~    }{12:~}{13: aa             }{0:                  }|
            {0:~    }{12:~}{1: word           }{0:                  }|
            {0:~    }{12:~}{1: longtext       }{0:                  }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed('<esc>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {7:x a^a        }|
            {12:~           }|*3
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true},
          }}

        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x a^a        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|*3
                                                    |
          ]])
        end

        feed('<c-w>wi')
        fn.complete(1, {'xx', 'yy', 'zz'})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            xx^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa        }|
            {12:~           }|*3
          ## grid 5
            {13:xx             }|
            {1:yy             }|
            {1:zz             }|
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true, 50},
            [5] = {-1, "NW", 2, 1, 0, false, 100}
          }}
        else
          screen:expect([[
            xx^                                      |
            {13:xx             }{0:                         }|
            {1:yy             }{7:  }{0:                       }|
            {1:zz             }{12:  }{0:                       }|
            {0:~    }{12:~           }{0:                       }|*2
            {3:-- INSERT --}                            |
          ]])
        end

        feed('<c-y>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            xx^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa        }|
            {12:~           }|*3
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
            xx^                                      |
            {0:~                                       }|
            {0:~    }{7:x aa        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|*3
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it('command menu rendered above cursor (pum_above)', function()
        command('set wildmenu wildmode=longest:full wildoptions=pum')
        feed(':sign u<tab>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|*5
          ## grid 3
            :sign un^                                |
          ## grid 4
            {7:            }|
            {12:~           }|*3
          ## grid 5
            {1: undefine       }|
            {1: unplace        }|
          ]], float_pos={
            [5] = {-1, "SW", 1, 6, 5, false, 250};
            [4] = {1001, "NW", 1, 2, 5, true, 50};
          }}
        else
          screen:expect{grid=[[
                                                    |
            {0:~                                       }|
            {0:~    }{7:            }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{1: undefine       }{0:                   }|
            {0:~    }{1: unplace        }{0:                   }|
            :sign un^                                |
          ]]}
        end
      end)

      it('with ext_popupmenu', function()
        screen:set_option('ext_popupmenu', true)
        feed('ix ')
        fn.complete(3, {'aa', 'word', 'longtext'})
        local items = {{"aa", "", "", ""}, {"word", "", "", ""}, {"longtext", "", "", ""}}
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa^        }|
            {12:~           }|*3
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true},
          }, popupmenu={
            anchor = {4, 0, 2}, items = items, pos = 0
          }}
        else
          screen:expect{grid=[[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x aa^        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|*3
            {3:-- INSERT --}                            |
          ]], popupmenu={
            anchor = {1, 2, 7}, items = items, pos = 0
          }}
        end

        feed('<esc>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {7:x a^a        }|
            {12:~           }|*3
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x a^a        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|*3
                                                    |
          ]])
        end

        feed('<c-w>wi')
        fn.complete(1, {'xx', 'yy', 'zz'})
        items = {{"xx", "", "", ""}, {"yy", "", "", ""}, {"zz", "", "", ""}}
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            xx^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa        }|
            {12:~           }|*3
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true},
          }, popupmenu={
            anchor = {2, 0, 0}, items = items, pos = 0
          }}
        else
          screen:expect{grid=[[
            xx^                                      |
            {0:~                                       }|
            {0:~    }{7:x aa        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|*3
            {3:-- INSERT --}                            |
          ]], popupmenu={
            anchor = {1, 0, 0}, items = items, pos = 0
          }}
        end

        feed('<c-y>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            xx^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa        }|
            {12:~           }|*3
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
            xx^                                      |
            {0:~                                       }|
            {0:~    }{7:x aa        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|*3
            {3:-- INSERT --}                            |
          ]])
        end
      end)
    end)

    describe('float shown after pum', function()
      local win
      before_each(function()
        command('hi NormalFloat guibg=#333333 guifg=NONE')
        feed('i')
        fn.complete(1, {'aa', 'word', 'longtext'})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {13:aa             }|
            {1:word           }|
            {1:longtext       }|
          ]], float_pos={
            [4] = {-1, "NW", 2, 1, 0, false, 100}}
          }
        else
          screen:expect([[
            aa^                                      |
            {13:aa             }{0:                         }|
            {1:word           }{0:                         }|
            {1:longtext       }{0:                         }|
            {0:~                                       }|*2
            {3:-- INSERT --}                            |
          ]])
        end

        local buf = api.nvim_create_buf(false,true)
        api.nvim_buf_set_lines(buf,0,-1,true,{"some info", "about item"})
        win = api.nvim_open_win(buf, false, {relative='cursor', width=12, height=2, row=1, col=10})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {13:aa             }|
            {1:word           }|
            {1:longtext       }|
          ## grid 5
            {15:some info   }|
            {15:about item  }|
          ]], float_pos={
            [4] = {-1, "NW", 2, 1, 0, false, 100},
            [5] = {1001, "NW", 2, 1, 12, true, 50},
          }}
        else
          screen:expect([[
            aa^                                      |
            {13:aa             }{15:e info   }{0:                }|
            {1:word           }{15:ut item  }{0:                }|
            {1:longtext       }{0:                         }|
            {0:~                                       }|*2
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it('and close pum first', function()
        feed('<c-y>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 5
            {15:some info   }|
            {15:about item  }|
          ]], float_pos={
            [5] = {1001, "NW", 2, 1, 12, true},
          }}
        else
          screen:expect([[
            aa^                                      |
            {0:~           }{15:some info   }{0:                }|
            {0:~           }{15:about item  }{0:                }|
            {0:~                                       }|*3
            {3:-- INSERT --}                            |
          ]])
        end

        api.nvim_win_close(win, false)
        if multigrid then
          screen:expect([[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ]])
        else
          screen:expect([[
            aa^                                      |
            {0:~                                       }|*5
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it('and close float first', function()
        api.nvim_win_close(win, false)
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {13:aa             }|
            {1:word           }|
            {1:longtext       }|
          ]], float_pos={
            [4] = {-1, "NW", 2, 1, 0, false, 100},
          }}
        else
          screen:expect([[
            aa^                                      |
            {13:aa             }{0:                         }|
            {1:word           }{0:                         }|
            {1:longtext       }{0:                         }|
            {0:~                                       }|*2
            {3:-- INSERT --}                            |
          ]])
        end

        feed('<c-y>')
        if multigrid then
          screen:expect([[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ]])
        else
          screen:expect([[
            aa^                                      |
            {0:~                                       }|*5
            {3:-- INSERT --}                            |
          ]])
        end
      end)
    end)

    it("can use Normal as background", function()
      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf,0,-1,true,{"here", "float"})
      local win = api.nvim_open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
      api.nvim_set_option_value('winhl', 'Normal:Normal', {win=win})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          here                |
          float               |
        ]], float_pos={
          [4] = {1001, "NW", 1, 2, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }here                {0:               }|
          {0:~    }float               {0:               }|
          {0:~                                       }|*2
                                                  |
        ]]}
      end
    end)

    describe("handles :wincmd", function()
      local win
      local expected_pos
      before_each(function()
        -- the default, but be explicit:
        command("set laststatus=1")
        command("set hidden")
        api.nvim_buf_set_lines(0,0,-1,true,{"x"})
        local buf = api.nvim_create_buf(false,false)
        win = api.nvim_open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
        api.nvim_buf_set_lines(buf,0,-1,true,{"y"})
        expected_pos = {
          [4]={1001, 'NW', 1, 2, 5, true}
        }
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end
      end)

      it("w", function()
        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end
      end)

      it("w with focusable=false", function()
        api.nvim_win_set_config(win, {focusable=false})
        expected_pos[4][6] = false
        feed("<c-w>wi") -- i to provoke redraw
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
            {3:-- INSERT --}                            |
          ]])
        end

        feed("<esc><c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end
      end)

      it("W", function()
        feed("<c-w>W")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        feed("<c-w>W")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end
      end)

      it("focus by mouse", function()
        if multigrid then
          api.nvim_input_mouse('left', 'press', '', 4, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          api.nvim_input_mouse('left', 'press', '', 0, 2, 5)
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        if multigrid then
          api.nvim_input_mouse('left', 'press', '', 2, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end
      end)

      it("focus by mouse (focusable=false)", function()
        api.nvim_win_set_config(win, {focusable=false})
        api.nvim_buf_set_lines(0, -1, -1, true, {"a"})
        expected_pos[4][6] = false
        if multigrid then
          api.nvim_input_mouse('left', 'press', '', 4, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            a                                       |
            {0:~                                       }|*4
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          api.nvim_input_mouse('left', 'press', '', 0, 2, 5)
          screen:expect([[
            x                                       |
            ^a                                       |
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        if multigrid then
          api.nvim_input_mouse('left', 'press', '', 2, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            a                                       |
            {0:~                                       }|*4
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos, unchanged=true}
        else
          api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
          screen:expect([[
            ^x                                       |
            a                                       |
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end
      end)

      it("j", function()
        feed("<c-w>ji") -- INSERT to trigger screen change
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
            {3:-- INSERT --}                            |
          ]])
        end

        feed("<esc><c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        feed("<c-w>j")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

      end)

      it("vertical resize + - _", function()
        feed('<c-w>w')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        feed('<c-w>+')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|*2
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|*2
            {0:~                                       }|
                                                    |
          ]])
        end

        feed('<c-w>2-')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~                                       }|*3
                                                    |
          ]])
        end

        feed('<c-w>4_')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|*3
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|*3
                                                    |
          ]])
        end

        feed('<c-w>_')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|*5
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x    {1:^y                   }               |
            {0:~    }{2:~                   }{0:               }|*5
                                                    |
          ]])
        end
      end)

      it("horizontal resize > < |", function()
        feed('<c-w>w')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        feed('<c-w>>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                    }|
            {2:~                    }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                    }{0:              }|
            {0:~    }{2:~                    }{0:              }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        feed('<c-w>10<lt>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y          }|
            {2:~          }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y          }{0:                        }|
            {0:~    }{2:~          }{0:                        }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        feed('<c-w>15|')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y              }|
            {2:~              }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y              }{0:                    }|
            {0:~    }{2:~              }{0:                    }|
            {0:~                                       }|*2
                                                    |
          ]])
        end

        feed('<c-w>|')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                                       }|
            {2:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {1:^y                                       }|
            {2:~                                       }|
            {0:~                                       }|*2
                                                    |
          ]])
        end
      end)

      it("s :split (non-float)", function()
        feed("<c-w>s")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^x                                       |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            x                                       |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            ^x    {2:~                   }               |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ## grid 5
            x                                       |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:^y                   }{5:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end


        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^x                                       |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end
      end)

      it("s :split (float)", function()
        feed("<c-w>w<c-w>s")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^y                                       |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^y                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>j")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            y                                       |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            y                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            ^x    {2:~                   }               |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>ji")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            y                                       |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            y                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            ^x    {2:~                   }               |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it(":new (non-float)", function()
        feed(":new<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {4:[No Name]                               }|
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            :new                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                                        |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                                        |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            :new                                    |
          ]])
        end
      end)

      it(":new (float)", function()
        feed("<c-w>w:new<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {4:[No Name]                               }|
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            :new                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                                        |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                                        |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            :new                                    |
          ]])
        end
      end)

      it("v :vsplit (non-float)", function()
        feed("<c-w>v")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:--------------------]{5:│}[2:-------------------]|*5
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
            [3:----------------------------------------]|
          ## grid 2
            x                  |
            {0:~                  }|*4
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^x                   |
            {0:~                   }|*4
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                   {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
                                                    |
          ]])
        end
      end)

      it(":vnew (non-float)", function()
        feed(":vnew<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:--------------------]{5:│}[2:-------------------]|*5
            {4:[No Name]            }{5:[No Name] [+]      }|
            [3:----------------------------------------]|
          ## grid 2
            x                  |
            {0:~                  }|*4
          ## grid 3
            :vnew                                   |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                    |
            {0:~                   }|*4
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                    {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name]            }{5:[No Name] [+]      }|
            :vnew                                   |
          ]])
        end
      end)

      it(":vnew (float)", function()
        feed("<c-w>w:vnew<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:--------------------]{5:│}[2:-------------------]|*5
            {4:[No Name]            }{5:[No Name] [+]      }|
            [3:----------------------------------------]|
          ## grid 2
            x                  |
            {0:~                  }|*4
          ## grid 3
            :vnew                                   |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                    |
            {0:~                   }|*4
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                    {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name]            }{5:[No Name] [+]      }|
            :vnew                                   |
          ]])
        end
      end)

      it("q (:quit) last non-float exits nvim", function()
        command('autocmd VimLeave    * call rpcrequest(1, "exit")')
        -- avoid unsaved change in other buffer
        feed("<c-w><c-w>:w Xtest_written2<cr><c-w><c-w>")
        -- quit in last non-float
        feed(":wq Xtest_written<cr>")
        local exited = false
        local function on_request(name, args)
          eq("exit", name)
          eq({}, args)
          exited = true
          return 0
        end
        local function on_setup()
          feed(":wq Xtest_written<cr>")
        end
        run(on_request, nil, on_setup)
        os.remove('Xtest_written')
        os.remove('Xtest_written2')
        eq(exited, true)
      end)

      it(':quit two floats in a row', function()
        -- enter first float
        feed('<c-w><c-w>')
        -- enter second float
        api.nvim_open_win(0, true, {relative='editor', width=20, height=2, row=4, col=8})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true},
            [5] = {1002, "NW", 1, 4, 8, true}
          }}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~       }{1:^y                   }{0:            }|
            {0:~       }{2:~                   }{0:            }|
                                                    |
          ]])
        end

        feed(':quit<cr>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
            :quit                                   |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos={
            [4] = {1001, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
            :quit                                   |
          ]])
        end

        feed(':quit<cr>')
        if multigrid then
          screen:expect([[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
            :quit                                   |
          ]])
         else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|*5
            :quit                                   |
          ]])
        end

        assert_alive()
      end)

      it("o (:only) non-float", function()
        feed("<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ]]}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|*5
                                                    |
          ]])
        end
      end)

      it("o (:only) float fails", function()
        feed("<c-w>w<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*4
            [3:----------------------------------------]|*3
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {4:                                        }|
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ]])
        end

        -- test message clear
        feed('<cr>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
                                                    |
          ]])
        end
      end)

      it("o (:only) non-float with split", function()
        feed("<c-w>s")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 3
                                                    |
          ## grid 5
            ^x                                       |
            {0:~                                       }|*5
          ]]}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|*5
                                                    |
          ]])
        end
      end)

      it("o (:only) float with split", function()
        feed("<c-w>s<c-w>W")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ## grid 5
            x                                       |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:^y                   }{5:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [3:----------------------------------------]|*3
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            x                                       |
            {0:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            {4:                                        }|
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ]])
        end
      end)

      it("J (float)", function()
        feed("<c-w>w<c-w>J")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [4:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            ^y                                       |
            {0:~                                       }|
          ]]}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            ^y                                       |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end

        if multigrid then
          api.nvim_win_set_config(0, {external=true, width=30, height=2})
          expected_pos = {[4]={external=true}}
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*5
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|*4
          ## grid 3
                                                    |
          ## grid 4
            ^y                             |
            {0:~                             }|
          ]], float_pos=expected_pos}
        else
          eq("UI doesn't support external windows",
             pcall_err(api.nvim_win_set_config, 0, {external=true, width=30, height=2}))
          return
        end

        feed("<c-w>J")
        if multigrid then
          screen:expect([[
          ## grid 1
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [4:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            ^y                                       |
            {0:~                                       }|
          ]])
        end
      end)

      it('J (float with border)', function()
        api.nvim_win_set_config(win, {relative='editor', width=20, height=2, row=2, col=5, border='single'})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {5:┌────────────────────┐}|
            {5:│}{1:y                   }{5:│}|
            {5:│}{2:~                   }{5:│}|
            {5:└────────────────────┘}|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{5:┌────────────────────┐}{0:             }|
            {0:~    }{5:│}{1:y                   }{5:│}{0:             }|
            {0:~    }{5:│}{2:~                   }{5:│}{0:             }|
            {0:~    }{5:└────────────────────┘}{0:             }|
                                                    |
          ]])
        end

        feed("<c-w>w<c-w>J")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*2
            {5:[No Name] [+]                           }|
            [4:----------------------------------------]|*2
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            ^y                                       |
            {0:~                                       }|
          ]]}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            ^y                                       |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end
      end)

      it('movements with nested split layout', function()
        command("set hidden")
        feed("<c-w>s<c-w>v<c-w>b<c-w>v")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [6:--------------------]{5:│}[5:-------------------]|*2
            {5:[No Name] [+]        [No Name] [+]      }|
            [7:--------------------]{5:│}[2:-------------------]|*2
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
            [3:----------------------------------------]|
          ## grid 2
            x                  |
            {0:~                  }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            x                  |
            {0:~                  }|
          ## grid 6
            x                   |
            {0:~                   }|
          ## grid 7
            ^x                   |
            {0:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                   {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {5:[No N}{1:y                   }{5:Name] [+]      }|
            ^x    {2:~                   }               |
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
                                                    |
          ]])
        end

        -- verify that N<c-w>w works
        for i = 1,5 do
          feed(i.."<c-w>w")
          feed_command("enew")
          api.nvim_buf_set_lines(0, 0,-1,true,{tostring(i)})
        end

        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [6:-------------------]{5:│}[5:--------------------]|*2
            {5:[No Name] [+]       [No Name] [+]       }|
            [7:-------------------]{5:│}[2:--------------------]|*2
            {5:[No Name] [+]       [No Name] [+]       }|
            [3:----------------------------------------]|
          ## grid 2
            4                   |
            {0:~                   }|
          ## grid 3
            :enew                                   |
          ## grid 4
            {1:^5                   }|
            {2:~                   }|
          ## grid 5
            2                   |
            {0:~                   }|
          ## grid 6
            1                  |
            {0:~                  }|
          ## grid 7
            3                  |
            {0:~                  }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            1                  {5:│}2                   |
            {0:~                  }{5:│}{0:~                   }|
            {5:[No N}{1:^5                   }{5:ame] [+]       }|
            3    {2:~                   }               |
            {0:~                  }{5:│}{0:~                   }|
            {5:[No Name] [+]       [No Name] [+]       }|
            :enew                                   |
          ]])
        end

        local movements = {
          w={2,3,4,5,1},
          W={5,1,2,3,4},
          h={1,1,3,3,3},
          j={3,3,3,4,4},
          k={1,2,1,1,1},
          l={2,2,4,4,4},
          t={1,1,1,1,1},
          b={4,4,4,4,4},
        }

        for k,v in pairs(movements) do
          for i = 1,5 do
            feed(i.."<c-w>w")
            feed('<c-w>'..k)
            local nr = fn.winnr()
            eq(v[i],nr, "when using <c-w>"..k.." from window "..i)
          end
        end

        for i = 1,5 do
          feed(i.."<c-w>w")
          for j = 1,5 do
            if j ~= i then
              feed(j.."<c-w>w")
              feed('<c-w>p')
              local nr = fn.winnr()
              eq(i,nr, "when using <c-w>p to window "..i.." from window "..j)
            end
          end
        end

      end)

      it(":tabnew and :tabnext", function()
        feed(":tabnew<cr>")
        if multigrid then
          -- grid is not freed, but float is marked as closed (should it rather be "invisible"?)
          screen:expect{grid=[[
          ## grid 1
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            [5:----------------------------------------]|*5
            [3:----------------------------------------]|
          ## grid 2 (hidden)
            x                                       |
            {0:~                                       }|*5
          ## grid 3
            :tabnew                                 |
          ## grid 4 (hidden)
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                                        |
            {0:~                                       }|*4
          ]]}
        else
          screen:expect([[
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            ^                                        |
            {0:~                                       }|*4
            :tabnew                                 |
          ]])
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {3: }{11:2}{3:+ [No Name] }{9: [No Name] }{5:              }{9:X}|
            [2:----------------------------------------]|*5
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*4
          ## grid 3
            :tabnext                                |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5 (hidden)
                                                    |
            {0:~                                       }|*4
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            {3: }{11:2}{3:+ [No Name] }{9: [No Name] }{5:              }{9:X}|
            ^x                                       |
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|*2
            :tabnext                                |
          ]])
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            [5:----------------------------------------]|*5
            [3:----------------------------------------]|
          ## grid 2 (hidden)
            x                                       |
            {0:~                                       }|*4
          ## grid 3
            :tabnext                                |
          ## grid 4 (hidden)
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                                        |
            {0:~                                       }|*4
        ]]}
        else
          screen:expect([[
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            ^                                        |
            {0:~                                       }|*4
            :tabnext                                |
          ]])
        end
      end)

      it(":tabnew and :tabnext (external)", function()
        if multigrid then
          -- also test external window wider than main screen
          api.nvim_win_set_config(win, {external=true, width=65, height=4})
          expected_pos = {[4]={external=true}}
          feed(":tabnew<cr>")
          screen:expect{grid=[[
          ## grid 1
            {9: + [No Name] }{3: }{11:2}{3:+ [No Name] }{5:            }{9:X}|
            [5:----------------------------------------]|*5
            [3:----------------------------------------]|
          ## grid 2 (hidden)
            x                                       |
            {0:~                                       }|*5
          ## grid 3
            :tabnew                                 |
          ## grid 4
            y                                                                |
            {0:~                                                                }|*3
          ## grid 5
            ^                                        |
            {0:~                                       }|*4
        ]], float_pos=expected_pos}
        else
          eq("UI doesn't support external windows",
             pcall_err(api.nvim_win_set_config, 0, {external=true, width=65, height=4}))
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {3: }{11:2}{3:+ [No Name] }{9: [No Name] }{5:              }{9:X}|
            [2:----------------------------------------]|*5
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|*4
          ## grid 3
            :tabnext                                |
          ## grid 4
            y                                                                |
            {0:~                                                                }|*3
          ## grid 5 (hidden)
                                                    |
            {0:~                                       }|*4
        ]], float_pos=expected_pos}
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {9: + [No Name] }{3: }{11:2}{3:+ [No Name] }{5:            }{9:X}|
            [5:----------------------------------------]|*5
            [3:----------------------------------------]|
          ## grid 2 (hidden)
            x                                       |
            {0:~                                       }|*4
          ## grid 3
            :tabnext                                |
          ## grid 4
            y                                                                |
            {0:~                                                                }|*3
          ## grid 5
            ^                                        |
            {0:~                                       }|*4
        ]], float_pos=expected_pos}
        end
      end)
    end)

    it("left drag changes visual selection in float window", function()
      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'foo', 'bar', 'baz'})
      api.nvim_open_win(buf, false, {relative='editor', width=20, height=3, row=2, col=5})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:foo                 }|
          {1:bar                 }|
          {1:baz                 }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 2, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}

        api.nvim_input_mouse('left', 'press', '', 4, 0, 0)
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {1:^foo                 }|
          {1:bar                 }|
          {1:baz                 }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 2, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}

        api.nvim_input_mouse('left', 'drag', '', 4, 1, 2)
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
          {3:-- VISUAL --}                            |
        ## grid 4
          {27:foo}{1:                 }|
          {27:ba}{1:^r                 }|
          {1:baz                 }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 2, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 1, curcol = 2, linecount = 3, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{1:foo                 }{0:               }|
          {0:~    }{1:bar                 }{0:               }|
          {0:~    }{1:baz                 }{0:               }|
          {0:~                                       }|
                                                  |
        ]]}

        api.nvim_input_mouse('left', 'press', '', 0, 2, 5)
        screen:expect{grid=[[
                                                  |
          {0:~                                       }|
          {0:~    }{1:^foo                 }{0:               }|
          {0:~    }{1:bar                 }{0:               }|
          {0:~    }{1:baz                 }{0:               }|
          {0:~                                       }|
                                                  |
        ]]}

        api.nvim_input_mouse('left', 'drag', '', 0, 3, 7)
        screen:expect{grid=[[
                                                  |
          {0:~                                       }|
          {0:~    }{27:foo}{1:                 }{0:               }|
          {0:~    }{27:ba}{1:^r                 }{0:               }|
          {0:~    }{1:baz                 }{0:               }|
          {0:~                                       }|
          {3:-- VISUAL --}                            |
        ]]}
      end
    end)

    it("left drag changes visual selection in float window with border", function()
      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'foo', 'bar', 'baz'})
      api.nvim_open_win(buf, false, {relative='editor', width=20, height=3, row=0, col=5, border='single'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌────────────────────┐}|
          {5:│}{1:foo                 }{5:│}|
          {5:│}{1:bar                 }{5:│}|
          {5:│}{1:baz                 }{5:│}|
          {5:└────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}

        api.nvim_input_mouse('left', 'press', '', 4, 1, 1)
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌────────────────────┐}|
          {5:│}{1:^foo                 }{5:│}|
          {5:│}{1:bar                 }{5:│}|
          {5:│}{1:baz                 }{5:│}|
          {5:└────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}

        api.nvim_input_mouse('left', 'drag', '', 4, 2, 3)
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
          {3:-- VISUAL --}                            |
        ## grid 4
          {5:┌────────────────────┐}|
          {5:│}{27:foo}{1:                 }{5:│}|
          {5:│}{27:ba}{1:^r                 }{5:│}|
          {5:│}{1:baz                 }{5:│}|
          {5:└────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 1, curcol = 2, linecount = 3, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^     {5:┌────────────────────┐}             |
          {0:~    }{5:│}{1:foo                 }{5:│}{0:             }|
          {0:~    }{5:│}{1:bar                 }{5:│}{0:             }|
          {0:~    }{5:│}{1:baz                 }{5:│}{0:             }|
          {0:~    }{5:└────────────────────┘}{0:             }|
          {0:~                                       }|
                                                  |
        ]]}

        api.nvim_input_mouse('left', 'press', '', 0, 1, 6)
        screen:expect{grid=[[
               {5:┌────────────────────┐}             |
          {0:~    }{5:│}{1:^foo                 }{5:│}{0:             }|
          {0:~    }{5:│}{1:bar                 }{5:│}{0:             }|
          {0:~    }{5:│}{1:baz                 }{5:│}{0:             }|
          {0:~    }{5:└────────────────────┘}{0:             }|
          {0:~                                       }|
                                                  |
        ]]}

        api.nvim_input_mouse('left', 'drag', '', 0, 2, 8)
        screen:expect{grid=[[
               {5:┌────────────────────┐}             |
          {0:~    }{5:│}{27:foo}{1:                 }{5:│}{0:             }|
          {0:~    }{5:│}{27:ba}{1:^r                 }{5:│}{0:             }|
          {0:~    }{5:│}{1:baz                 }{5:│}{0:             }|
          {0:~    }{5:└────────────────────┘}{0:             }|
          {0:~                                       }|
          {3:-- VISUAL --}                            |
        ]]}
      end
    end)

    it("left drag changes visual selection in float window with winbar", function()
      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'foo', 'bar', 'baz'})
      local float_win = api.nvim_open_win(buf, false, {relative='editor', width=20, height=4, row=1, col=5})
      api.nvim_set_option_value('winbar', 'floaty bar', {win=float_win})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {3:floaty bar          }|
          {1:foo                 }|
          {1:bar                 }|
          {1:baz                 }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}

        api.nvim_input_mouse('left', 'press', '', 4, 1, 0)
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {3:floaty bar          }|
          {1:^foo                 }|
          {1:bar                 }|
          {1:baz                 }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}

        api.nvim_input_mouse('left', 'drag', '', 4, 2, 2)
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
          {3:-- VISUAL --}                            |
        ## grid 4
          {3:floaty bar          }|
          {27:foo}{1:                 }|
          {27:ba}{1:^r                 }|
          {1:baz                 }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 1, curcol = 2, linecount = 3, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~    }{3:floaty bar          }{0:               }|
          {0:~    }{1:foo                 }{0:               }|
          {0:~    }{1:bar                 }{0:               }|
          {0:~    }{1:baz                 }{0:               }|
          {0:~                                       }|
                                                  |
        ]]}

        api.nvim_input_mouse('left', 'press', '', 0, 2, 5)
        screen:expect{grid=[[
                                                  |
          {0:~    }{3:floaty bar          }{0:               }|
          {0:~    }{1:^foo                 }{0:               }|
          {0:~    }{1:bar                 }{0:               }|
          {0:~    }{1:baz                 }{0:               }|
          {0:~                                       }|
                                                  |
        ]]}

        api.nvim_input_mouse('left', 'drag', '', 0, 3, 7)
        screen:expect{grid=[[
                                                  |
          {0:~    }{3:floaty bar          }{0:               }|
          {0:~    }{27:foo}{1:                 }{0:               }|
          {0:~    }{27:ba}{1:^r                 }{0:               }|
          {0:~    }{1:baz                 }{0:               }|
          {0:~                                       }|
          {3:-- VISUAL --}                            |
        ]]}
      end
    end)

    it('left drag changes visual selection if float window is turned into a split', function()
      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'foo', 'bar', 'baz'})
      api.nvim_open_win(buf, true, {relative='editor', width=20, height=3, row=2, col=5})
      command('wincmd L')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:-------------------]{5:│}[4:--------------------]|*5
          {5:[No Name]           }{4:[No Name] [+]       }|
          [3:----------------------------------------]|
        ## grid 2
                             |
          {0:~                  }|*4
        ## grid 3
                                                  |
        ## grid 4
          ^foo                 |
          bar                 |
          baz                 |
          {0:~                   }|*2
        ]])

        api.nvim_input_mouse('left', 'press', '', 4, 2, 2)
        screen:expect([[
        ## grid 1
          [2:-------------------]{5:│}[4:--------------------]|*5
          {5:[No Name]           }{4:[No Name] [+]       }|
          [3:----------------------------------------]|
        ## grid 2
                             |
          {0:~                  }|*4
        ## grid 3
                                                  |
        ## grid 4
          foo                 |
          bar                 |
          ba^z                 |
          {0:~                   }|*2
        ]])

        api.nvim_input_mouse('left', 'drag', '', 4, 1, 1)
        screen:expect([[
        ## grid 1
          [2:-------------------]{5:│}[4:--------------------]|*5
          {5:[No Name]           }{4:[No Name] [+]       }|
          [3:----------------------------------------]|
        ## grid 2
                             |
          {0:~                  }|*4
        ## grid 3
          {3:-- VISUAL --}                            |
        ## grid 4
          foo                 |
          b^a{27:r}                 |
          {27:baz}                 |
          {0:~                   }|*2
        ]])
      else
        screen:expect([[
                             {5:│}^foo                 |
          {0:~                  }{5:│}bar                 |
          {0:~                  }{5:│}baz                 |
          {0:~                  }{5:│}{0:~                   }|*2
          {5:[No Name]           }{4:[No Name] [+]       }|
                                                  |
        ]])

        api.nvim_input_mouse('left', 'press', '', 0, 2, 22)
        screen:expect([[
                             {5:│}foo                 |
          {0:~                  }{5:│}bar                 |
          {0:~                  }{5:│}ba^z                 |
          {0:~                  }{5:│}{0:~                   }|*2
          {5:[No Name]           }{4:[No Name] [+]       }|
                                                  |
        ]])

        api.nvim_input_mouse('left', 'drag', '', 0, 1, 21)
        screen:expect([[
                             {5:│}foo                 |
          {0:~                  }{5:│}b^a{27:r}                 |
          {0:~                  }{5:│}{27:baz}                 |
          {0:~                  }{5:│}{0:~                   }|*2
          {5:[No Name]           }{4:[No Name] [+]       }|
          {3:-- VISUAL --}                            |
        ]])
      end
    end)

    it('left click sets correct curswant in float window with border', function()
      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'', '', ''})
      api.nvim_open_win(buf, false, {relative='editor', width=20, height=3, row=0, col=5, border='single'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌────────────────────┐}|
          {5:│}{1:                    }{5:│}|*3
          {5:└────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^     {5:┌────────────────────┐}             |
          {0:~    }{5:│}{1:                    }{5:│}{0:             }|*3
          {0:~    }{5:└────────────────────┘}{0:             }|
          {0:~                                       }|
                                                  |
        ]]}
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 3, 1)
      else
        api.nvim_input_mouse('left', 'press', '', 0, 3, 6)
      end
      eq({0, 3, 1, 0, 1}, fn.getcurpos())

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 3, 2)
      else
        api.nvim_input_mouse('left', 'press', '', 0, 3, 7)
      end
      eq({0, 3, 1, 0, 2}, fn.getcurpos())

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 3, 10)
      else
        api.nvim_input_mouse('left', 'press', '', 0, 3, 15)
      end
      eq({0, 3, 1, 0, 10}, fn.getcurpos())

      command('setlocal foldcolumn=1')
      feed('zfkgg')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌────────────────────┐}|
          {5:│}{19: }{1:^                   }{5:│}|
          {5:│}{19:+}{28:+--  2 lines: ·····}{5:│}|
          {5:│}{2:~                   }{5:│}|
          {5:└────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 4, curline = 0, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
               {5:┌────────────────────┐}             |
          {0:~    }{5:│}{19: }{1:^                   }{5:│}{0:             }|
          {0:~    }{5:│}{19:+}{28:+--  2 lines: ·····}{5:│}{0:             }|
          {0:~    }{5:│}{2:~                   }{5:│}{0:             }|
          {0:~    }{5:└────────────────────┘}{0:             }|
          {0:~                                       }|
                                                  |
        ]]}
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 2, 1)
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌────────────────────┐}|
          {5:│}{19: }{1:^                   }{5:│}|
          {5:│}{19:-}{1:                   }{5:│}|
          {5:│}{19:│}{1:                   }{5:│}|
          {5:└────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 0, curcol = 0, linecount = 3, sum_scroll_delta = 0};
        }}
      else
        api.nvim_input_mouse('left', 'press', '', 0, 2, 6)
        screen:expect{grid=[[
               {5:┌────────────────────┐}             |
          {0:~    }{5:│}{19: }{1:^                   }{5:│}{0:             }|
          {0:~    }{5:│}{19:-}{1:                   }{5:│}{0:             }|
          {0:~    }{5:│}{19:│}{1:                   }{5:│}{0:             }|
          {0:~    }{5:└────────────────────┘}{0:             }|
          {0:~                                       }|
                                                  |
        ]]}
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 2, 2)
      else
        api.nvim_input_mouse('left', 'press', '', 0, 2, 7)
      end
      eq({0, 2, 1, 0, 1}, fn.getcurpos())

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 2, 3)
      else
        api.nvim_input_mouse('left', 'press', '', 0, 2, 8)
      end
      eq({0, 2, 1, 0, 2}, fn.getcurpos())

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 2, 11)
      else
        api.nvim_input_mouse('left', 'press', '', 0, 2, 16)
      end
      eq({0, 2, 1, 0, 10}, fn.getcurpos())
    end)

    it("'winblend' option", function()
      screen:try_resize(50,9)
      screen:set_default_attr_ids({
        [1] = {background = Screen.colors.LightMagenta},
        [2] = {foreground = Screen.colors.Grey0, background = tonumber('0xffcfff')},
        [3] = {foreground = tonumber('0xb282b2'), background = tonumber('0xffcfff')},
        [4] = {foreground = Screen.colors.Red, background = Screen.colors.LightMagenta},
        [5] = {foreground = tonumber('0x990000'), background = tonumber('0xfff1ff')},
        [6] = {foreground = tonumber('0x332533'), background = tonumber('0xfff1ff')},
        [7] = {background = tonumber('0xffcfff'), bold = true, foreground = tonumber('0x0000d8')},
        [8] = {background = Screen.colors.LightMagenta, bold = true, foreground = Screen.colors.Blue1},
        [9] = {background = Screen.colors.LightMagenta, blend = 30},
        [10] = {foreground = Screen.colors.Red, background = Screen.colors.LightMagenta, blend = 0},
        [11] = {foreground = Screen.colors.Red, background = Screen.colors.LightMagenta, blend = 80},
        [12] = {background = Screen.colors.LightMagenta, bold = true, foreground = Screen.colors.Blue1, blend = 30},
        [13] = {foreground = Screen.colors.Black, background = Screen.colors.LightGray, blend = 30},
        [14] = {foreground = Screen.colors.Black, background = Screen.colors.Grey88},
        [15] = {foreground = tonumber('0x939393'), background = Screen.colors.Grey88},
        [16] = {background = Screen.colors.Grey90};
        [17] = {blend = 100};
        [18] = {background = Screen.colors.LightMagenta, blend = 100};
        [19] = {background = Screen.colors.LightMagenta, bold = true, blend = 100, foreground = Screen.colors.Blue1};
        [20] = {background = Screen.colors.White, foreground = Screen.colors.Gray0};
        [21] = {background = Screen.colors.White, bold = true, foreground = tonumber('0x00007f')};
        [22] = {background = Screen.colors.Gray90, foreground = Screen.colors.Gray0};
        [23] = {blend = 100, bold = true, foreground = Screen.colors.Magenta};
        [24] = {foreground = tonumber('0x7f007f'), bold = true, background = Screen.colors.White};
        [25] = {foreground = tonumber('0x7f007f'), bold = true, background = Screen.colors.Grey90};
      })
      insert([[
        Lorem ipsum dolor sit amet, consectetur
        adipisicing elit, sed do eiusmod tempor
        incididunt ut labore et dolore magna aliqua.
        Ut enim ad minim veniam, quis nostrud
        exercitation ullamco laboris nisi ut aliquip ex
        ea commodo consequat. Duis aute irure dolor in
        reprehenderit in voluptate velit esse cillum
        dolore eu fugiat nulla pariatur. Excepteur sint
        occaecat cupidatat non proident, sunt in culpa
        qui officia deserunt mollit anim id est
        laborum.]])
      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {"test", "", "popup    text"})
      local win = api.nvim_open_win(buf, false, {relative='editor', width=15, height=3, row=2, col=5})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|*8
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 4
          {1:test           }|
          {1:               }|
          {1:popup    text  }|
        ]], float_pos={[4] = {1001, "NW", 1, 2, 5, true}}}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{1:test           }. Duis aute irure dolor in    |
          repre{1:               }uptate velit esse cillum      |
          dolor{1:popup    text  }la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      api.nvim_set_option_value("winblend", 30, {win=win})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|*8
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 4
          {9:test           }|
          {9:               }|
          {9:popup    text  }|
        ]], float_pos={[4] = {1001, "NW", 1, 2, 5, true}}, unchanged=true}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{2:test}{3:o consequat}. Duis aute irure dolor in    |
          repre{3:henderit in vol}uptate velit esse cillum      |
          dolor{2:popup}{3:fugi}{2:text}{3:ul}la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      -- Check that 'winblend' works with NormalNC highlight
      api.nvim_set_option_value('winhighlight', 'NormalNC:Visual', {win = win})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|*8
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 4
          {13:test           }|
          {13:               }|
          {13:popup    text  }|
        ]], float_pos={[4] = {1001, "NW", 1, 2, 5, true}}}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{14:test}{15:o consequat}. Duis aute irure dolor in    |
          repre{15:henderit in vol}uptate velit esse cillum      |
          dolor{14:popup}{15:fugi}{14:text}{15:ul}la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      -- Also test with global NormalNC highlight
      exec_lua([[
        vim.api.nvim_set_option_value('winhighlight', '', {win = ...})
        vim.api.nvim_set_hl(0, 'NormalNC', {link = 'Visual'})
      ]], win)
      screen:expect_unchanged()
      command('hi clear NormalNC')

      command('hi SpecialRegion guifg=Red blend=0')
      api.nvim_buf_add_highlight(buf, -1, "SpecialRegion", 2, 0, -1)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|*8
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 4
          {9:test           }|
          {9:               }|
          {10:popup    text}{9:  }|
        ]], float_pos={[4] = {1001, "NW", 1, 2, 5, true}}}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{2:test}{3:o consequat}. Duis aute irure dolor in    |
          repre{3:henderit in vol}uptate velit esse cillum      |
          dolor{10:popup    text}{3:ul}la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      command('hi SpecialRegion guifg=Red blend=80')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|*8
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 4
          {9:test           }|
          {9:               }|
          {11:popup    text}{9:  }|
        ]], float_pos={[4] = {1001, "NW", 1, 2, 5, true}}, unchanged=true}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{2:test}{3:o consequat}. Duis aute irure dolor in    |
          repre{3:henderit in vol}uptate velit esse cillum      |
          dolor{5:popup}{6:fugi}{5:text}{3:ul}la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      -- Test scrolling by mouse
      if multigrid then
        api.nvim_input_mouse('wheel', 'down', '', 4, 2, 2)
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|*8
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 4
          {11:popup    text}{9:  }|
          {12:~              }|*2
        ]], float_pos={[4] = {1001, "NW", 1, 2, 5, true}}}
      else
        api.nvim_input_mouse('wheel', 'down', '', 0, 4, 7)
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{5:popup}{6: con}{5:text}{3:at}. Duis aute irure dolor in    |
          repre{7:~}{3:enderit in vol}uptate velit esse cillum      |
          dolor{7:~}{3: eu fugiat nul}la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      -- Check that 'winblend' applies to border/title/footer
      api.nvim_win_set_config(win, {border='single', title='Title', footer='Footer'})
      api.nvim_set_option_value('winblend', 100, {win=win})
      api.nvim_set_option_value("cursorline", true, {win=0})
      command('hi clear VertSplit')
      feed('k0')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|*8
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          {16:^qui officia deserunt mollit anim id est           }|
          laborum.                                          |
        ## grid 3
                                                            |
        ## grid 4
          {17:┌}{23:Title}{17:──────────┐}|
          {17:│}{11:popup    text}{18:  }{17:│}|
          {17:│}{19:~              }{17:│}|*2
          {17:└}{23:Footer}{17:─────────┘}|
        ]], float_pos={[4] = {1001, "NW", 1, 2, 5, true}}}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{20:┌}{24:Title}{20:──────────┐}Duis aute irure dolor in    |
          repre{20:│}{5:popup}{6:it i}{5:text}{20:lu│}tate velit esse cillum      |
          dolor{20:│}{21:~}{20:eu fugiat null│} pariatur. Excepteur sint   |
          occae{20:│}{21:~}{20:t cupidatat no│} proident, sunt in culpa    |
          {16:^qui o}{22:└}{25:Footer}{22:─────────┘}{16:ollit anim id est           }|
          laborum.                                          |
                                                            |
        ]])
      end
    end)

    it('can overlap doublewidth chars', function()
      insert([[
        # TODO: 测试字典信息的准确性
        # FIXME: 测试字典信息的准确性]])
      local buf = api.nvim_create_buf(false,false)
      api.nvim_buf_set_lines(buf, 0, -1, true, {'口', '口'})
      local win = api.nvim_open_win(buf, false, {relative='editor', width=5, height=3, row=0, col=11, style='minimal'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {0:~                                       }|*4
        ## grid 3
                                                  |
        ## grid 4
          {1:口   }|*2
          {1:     }|
        ]], float_pos={ [4] = { 1001, "NW", 1, 0, 11, true } }}
      else
        screen:expect([[
          # TODO: 测 {1:口   }信息的准确性            |
          # FIXME: 测{1:口   } 信息的准确^性           |
          {0:~          }{1:     }{0:                        }|
          {0:~                                       }|*3
                                                  |
        ]])
      end

      api.nvim_win_close(win, false)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {0:~                                       }|*4
        ## grid 3
                                                  |
        ]])
      else
        screen:expect([[
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {0:~                                       }|*4
                                                  |
        ]])
      end

      -- The interaction between 'winblend' and doublewidth chars in the background
      -- does not look very good. But check no chars get incorrectly placed
      -- at least. Also check invisible EndOfBuffer region blends correctly.
      api.nvim_buf_set_lines(buf, 0, -1, true, {" x x  x   xx", "  x x  x   x"})
      win = api.nvim_open_win(buf, false, {relative='editor', width=12, height=3, row=0, col=11, style='minimal'})
      api.nvim_set_option_value('winblend', 30, {win=win})
      screen:set_default_attr_ids({
        [1] = {foreground = tonumber('0xb282b2'), background = tonumber('0xffcfff')},
        [2] = {foreground = Screen.colors.Grey0, background = tonumber('0xffcfff')},
        [3] = {bold = true, foreground = Screen.colors.Blue1},
        [4] = {background = tonumber('0xffcfff'), bold = true, foreground = tonumber('0xb282ff')},
        [5] = {background = Screen.colors.LightMagenta, blend=30},
      })
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {3:~                                       }|*4
        ## grid 3
                                                  |
        ## grid 5
          {5: x x  x   xx}|
          {5:  x x  x   x}|
          {5:            }|
        ]], float_pos={
          [5] = { 1002, "NW", 1, 0, 11, true }
        }}
      else
        screen:expect([[
          # TODO: 测 {2: x x  x}{1:息}{2: xx} 确性            |
          # FIXME: 测{1:试}{2:x x  x}{1:息}{2: x}准确^性           |
          {3:~          }{4:            }{3:                 }|
          {3:~                                       }|*3
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {relative='editor', row=0, col=12})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {3:~                                       }|*4
        ## grid 3
                                                  |
        ## grid 5
          {5: x x  x   xx}|
          {5:  x x  x   x}|
          {5:            }|
        ]], float_pos={
          [5] = { 1002, "NW", 1, 0, 12, true }
        }}
      else
        screen:expect([[
          # TODO: 测试{2: x x}{1:信}{2:x }{1:的}{2:xx}确性            |
          # FIXME: 测 {2:  x x}{1:信}{2:x }{1:的}{2:x} 确^性           |
          {3:~           }{4:            }{3:                }|
          {3:~                                       }|*3
                                                  |
        ]])
      end
    end)

    it("correctly redraws when overlaid windows are resized #13991", function()
	  helpers.source([[
        let popup_config = {"relative" : "editor",
                    \ "width" : 7,
                    \ "height" : 3,
                    \ "row" : 1,
                    \ "col" : 1,
                    \ "style" : "minimal"}

        let border_config = {"relative" : "editor",
                    \ "width" : 9,
                    \ "height" : 5,
                    \ "row" : 0,
                    \ "col" : 0,
                    \ "style" : "minimal"}

        let popup_buffer = nvim_create_buf(v:false, v:true)
        let border_buffer = nvim_create_buf(v:false, v:true)
        let popup_win = nvim_open_win(popup_buffer, v:true, popup_config)
        let border_win = nvim_open_win(border_buffer, v:false, border_config)

        call nvim_buf_set_lines(popup_buffer, 0, -1, v:true,
                    \ ["long", "longer", "longest"])

        call nvim_buf_set_lines(border_buffer, 0, -1, v:true,
                    \ ["---------", "-       -", "-       -"])
      ]])

      if multigrid then
        screen:expect{grid=[[
		## grid 1
		  [2:----------------------------------------]|*6
		  [3:----------------------------------------]|
		## grid 2
		                                          |
		  {1:~                                       }|*5
		## grid 3
		                                          |
		## grid 4
		  {2:^long   }|
		  {2:longer }|
		  {2:longest}|
		## grid 5
		  {2:---------}|
		  {2:-       -}|*2
		  {2:         }|*2
		]], attr_ids={
          [1] = {foreground = Screen.colors.Blue1, bold = true};
          [2] = {background = Screen.colors.LightMagenta};
        }, float_pos={
           [4] = { 1001, "NW", 1, 1, 1, true },
           [5] = { 1002, "NW", 1, 0, 0, true }
        }}
      else
        screen:expect([[
        {1:---------}                               |
        {1:-^long   -}{0:                               }|
        {1:-longer -}{0:                               }|
        {1: longest }{0:                               }|
        {1:         }{0:                               }|
        {0:~                                       }|
                                                |
        ]])
      end

      helpers.source([[
        let new_popup_config = {"width" : 1, "height" : 3}
        let new_border_config = {"width" : 3, "height" : 5}

        function! Resize()
            call nvim_win_set_config(g:popup_win, g:new_popup_config)
            call nvim_win_set_config(g:border_win, g:new_border_config)

            call nvim_buf_set_lines(g:border_buffer, 0, -1, v:true,
                        \ ["---", "- -", "- -"])
        endfunction

        nnoremap zz <cmd>call Resize()<cr>
      ]])

      helpers.feed("zz")
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {1:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {2:^l}|
          {2:o}|
          {2:n}|
        ## grid 5
          {2:---}|
          {2:- -}|*2
          {2:   }|*2
        ]], attr_ids={
          [1] = {foreground = Screen.colors.Blue1, bold = true};
          [2] = {background = Screen.colors.LightMagenta};
        }, float_pos={
          [4] = { 1001, "NW", 1, 1, 1, true },
          [5] = { 1002, "NW", 1, 0, 0, true }
        }}
      else
        screen:expect([[
        {1:---}                                     |
        {1:-^l-}{0:                                     }|
        {1:-o-}{0:                                     }|
        {1: n }{0:                                     }|
        {1:   }{0:                                     }|
        {0:~                                       }|
                                                |
        ]])
      end
    end)

    it("correctly orders multiple opened floats (current last)", function()
      local buf = api.nvim_create_buf(false,false)
      local win = api.nvim_open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
      api.nvim_set_option_value("winhl", "Normal:ErrorMsg,EndOfBuffer:ErrorMsg", {win=win})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {7:                    }|
          {7:~                   }|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true };
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{7:                    }{0:               }|
          {0:~    }{7:~                   }{0:               }|
          {0:~                                       }|*2
                                                  |
        ]]}
      end

      exec_lua [[
        local buf = vim.api.nvim_create_buf(false,false)
        local win = vim.api.nvim_open_win(buf, false, {relative='editor', width=16, height=2, row=3, col=8})
        vim.wo[win].winhl = "EndOfBuffer:Normal"
        buf = vim.api.nvim_create_buf(false,false)
        win = vim.api.nvim_open_win(buf, true, {relative='editor', width=12, height=2, row=4, col=10})
        vim.wo[win].winhl = "Normal:Search,EndOfBuffer:Search"
      ]]

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {7:                    }|
          {7:~                   }|
        ## grid 5
          {1:                }|
          {1:~               }|
        ## grid 6
          {17:^            }|
          {17:~           }|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true };
          [5] = { 1002, "NW", 1, 3, 8, true };
          [6] = { 1003, "NW", 1, 4, 10, true };
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount=1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount=1, sum_scroll_delta = 0};
          [5] = {win = 1002, topline = 0, botline = 2, curline = 0, curcol = 0, linecount=1, sum_scroll_delta = 0};
          [6] = {win = 1003, topline = 0, botline = 2, curline = 0, curcol = 0, linecount=1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~                                       }|
          {0:~    }{7:                    }{0:               }|
          {0:~    }{7:~  }{1:                }{7: }{0:               }|
          {0:~       }{1:~ }{17:^            }{1:  }{0:                }|
          {0:~         }{17:~           }{0:                  }|
                                                  |
        ]]}
      end
    end)

    it("correctly orders multiple opened floats (non-current last)", function()
      local buf = api.nvim_create_buf(false,false)
      local win = api.nvim_open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
      api.nvim_set_option_value("winhl", "Normal:ErrorMsg,EndOfBuffer:ErrorMsg", {win=win})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {7:                    }|
          {7:~                   }|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true };
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {0:~    }{7:                    }{0:               }|
          {0:~    }{7:~                   }{0:               }|
          {0:~                                       }|*2
                                                  |
        ]]}
      end

      exec_lua [[
        local buf = vim.api.nvim_create_buf(false,false)
        local win = vim.api.nvim_open_win(buf, true, {relative='editor', width=12, height=2, row=4, col=10})
        vim.wo[win].winhl = "Normal:Search,EndOfBuffer:Search"
        buf = vim.api.nvim_create_buf(false,false)
        win = vim.api.nvim_open_win(buf, false, {relative='editor', width=16, height=2, row=3, col=8})
        vim.wo[win].winhl = "EndOfBuffer:Normal"
      ]]

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {7:                    }|
          {7:~                   }|
        ## grid 5
          {17:^            }|
          {17:~           }|
        ## grid 6
          {1:                }|
          {1:~               }|
        ]], float_pos={
          [4] = { 1001, "NW", 1, 2, 5, true };
          [5] = { 1002, "NW", 1, 4, 10, true };
          [6] = { 1003, "NW", 1, 3, 8, true };
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [5] = {win = 1002, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [6] = {win = 1003, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~                                       }|
          {0:~    }{7:                    }{0:               }|
          {0:~    }{7:~  }{1:                }{7: }{0:               }|
          {0:~       }{1:~ }{17:^            }{1:  }{0:                }|
          {0:~         }{17:~           }{0:                  }|
                                                  |
        ]]}
      end
    end)

    it('can use z-index', function()
      local buf = api.nvim_create_buf(false,false)
      local win1 = api.nvim_open_win(buf, false, {relative='editor', width=20, height=3, row=1, col=5, zindex=30})
      api.nvim_set_option_value("winhl", "Normal:ErrorMsg,EndOfBuffer:ErrorMsg", {win=win1})
      local win2 = api.nvim_open_win(buf, false, {relative='editor', width=20, height=3, row=2, col=6, zindex=50})
      api.nvim_set_option_value("winhl", "Normal:Search,EndOfBuffer:Search", {win=win2})
      local win3 = api.nvim_open_win(buf, false, {relative='editor', width=20, height=3, row=3, col=7, zindex=40})
      api.nvim_set_option_value("winhl", "Normal:Question,EndOfBuffer:Question", {win=win3})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {7:                    }|
          {7:~                   }|*2
        ## grid 5
          {17:                    }|
          {17:~                   }|*2
        ## grid 6
          {8:                    }|
          {8:~                   }|*2
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 5, true, 30};
          [5] = {1002, "NW", 1, 2, 6, true, 50};
          [6] = {1003, "NW", 1, 3, 7, true, 40};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [5] = {win = 1002, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [6] = {win = 1003, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~    }{7:                    }{0:               }|
          {0:~    }{7:~}{17:                    }{0:              }|
          {0:~    }{7:~}{17:~                   }{8: }{0:             }|
          {0:~     }{17:~                   }{8: }{0:             }|
          {0:~      }{8:~                   }{0:             }|
                                                  |
        ]]}
      end
    end)

    it('can use winbar', function()
      local buf = api.nvim_create_buf(false,false)
      local win1 = api.nvim_open_win(buf, false, {relative='editor', width=15, height=3, row=1, col=5})
      api.nvim_set_option_value('winbar', 'floaty bar', {win=win1})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {3:floaty bar     }|
          {1:               }|
          {2:~              }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 5, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~    }{3:floaty bar     }{0:                    }|
          {0:~    }{1:               }{0:                    }|
          {0:~    }{2:~              }{0:                    }|
          {0:~                                       }|*2
                                                  |
        ]]}
      end

      -- resize and add a border
      api.nvim_win_set_config(win1, {relative='editor', width=15, height=4, row=0, col=4, border = 'single'})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌───────────────┐}|
          {5:│}{3:floaty bar     }{5:│}|
          {5:│}{1:               }{5:│}|
          {5:│}{2:~              }{5:│}|*2
          {5:└───────────────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 0, 4, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^    {5:┌───────────────┐}                   |
          {0:~   }{5:│}{3:floaty bar     }{5:│}{0:                   }|
          {0:~   }{5:│}{1:               }{5:│}{0:                   }|
          {0:~   }{5:│}{2:~              }{5:│}{0:                   }|*2
          {0:~   }{5:└───────────────┘}{0:                   }|
                                                  |
        ]]}
      end
    end)

    it('it can be resized with messages and cmdheight=0 #20106', function()
      screen:try_resize(40,9)
      command 'set cmdheight=0'
      local buf = api.nvim_create_buf(false,true)
      local win = api.nvim_open_win(buf, false, {relative='editor', width=40, height=4, anchor='SW', row=9, col=0, style='minimal', border="single", noautocmd=true})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*9
        ## grid 2
          ^                                        |
          {0:~                                       }|*8
        ## grid 3
        ## grid 4
          {5:┌────────────────────────────────────────┐}|
          {5:│}{1:                                        }{5:│}|*4
          {5:└────────────────────────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "SW", 1, 9, 0, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|*2
          {5:┌──────────────────────────────────────┐}|
          {5:│}{1:                                      }{5:│}|*4
          {5:└──────────────────────────────────────┘}|
        ]]}
      end

      exec_lua([[
        local win = ...
        vim.api.nvim_win_set_height(win, 2)
        vim.api.nvim_echo({ { "" } }, false, {})
      ]], win)

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*9
        ## grid 2
          ^                                        |
          {0:~                                       }|*8
        ## grid 3
        ## grid 4
          {5:┌────────────────────────────────────────┐}|
          {5:│}{1:                                        }{5:│}|*2
          {5:└────────────────────────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "SW", 1, 9, 0, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|*4
          {5:┌──────────────────────────────────────┐}|
          {5:│}{1:                                      }{5:│}|*2
          {5:└──────────────────────────────────────┘}|
        ]]}

      end

      api.nvim_win_close(win, true)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*9
        ## grid 2
          ^                                        |
          {0:~                                       }|*8
        ## grid 3
        ]], win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|*8
        ]]}
      end
    end)

    it('it can be resized with messages and cmdheight=1', function()
      screen:try_resize(40,9)
      local buf = api.nvim_create_buf(false,true)
      local win = api.nvim_open_win(buf, false, {relative='editor', width=40, height=4, anchor='SW', row=8, col=0, style='minimal', border="single", noautocmd=true})

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*8
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*7
        ## grid 3
                                                  |
        ## grid 4
          {5:┌────────────────────────────────────────┐}|
          {5:│}{1:                                        }{5:│}|*4
          {5:└────────────────────────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "SW", 1, 8, 0, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|
          {5:┌──────────────────────────────────────┐}|
          {5:│}{1:                                      }{5:│}|*4
          {5:└──────────────────────────────────────┘}|
                                                  |
        ]]}
      end

      exec_lua([[
        -- echo prompt is blocking, so schedule
        local win = ...
        vim.schedule(function()
          vim.api.nvim_win_set_height(win, 2)
          vim.api.nvim_echo({ { "\n" } }, false, {})
        end)
      ]], win)

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*7
          [3:----------------------------------------]|*2
        ## grid 2
                                                  |
          {0:~                                       }|*7
        ## grid 3
                                                  |
          {8:Press ENTER or type command to continue}^ |
        ## grid 4
          {5:┌────────────────────────────────────────┐}|
          {5:│}{1:                                        }{5:│}|*4
          {5:└────────────────────────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "SW", 1, 8, 0, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~                                       }|
          {5:┌──────────────────────────────────────┐}|
          {5:│}{1:                                      }{5:│}|*3
          {4:                                        }|
                                                  |
          {8:Press ENTER or type command to continue}^ |
        ]]}
      end

      feed('<cr>')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*8
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*7
        ## grid 3
                                                  |
        ## grid 4
          {5:┌────────────────────────────────────────┐}|
          {5:│}{1:                                        }{5:│}|*2
          {5:└────────────────────────────────────────┘}|
        ]], float_pos={
          [4] = {1001, "SW", 1, 8, 0, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|*3
          {5:┌──────────────────────────────────────┐}|
          {5:│}{1:                                      }{5:│}|*2
          {5:└──────────────────────────────────────┘}|
                                                  |
        ]]}
      end

      api.nvim_win_close(win, true)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*8
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*7
        ## grid 3
                                                  |
        ]], win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
          ^                                        |
          {0:~                                       }|*7
                                                  |
        ]]}
      end
    end)

    describe('no crash after moving and closing float window #21547', function()
      local function test_float_move_close(cmd)
        local float_opts = {relative = 'editor', row = 1, col = 1, width = 10, height = 10}
        api.nvim_open_win(api.nvim_create_buf(false, false), true, float_opts)
        if multigrid then
          screen:expect({float_pos = {[4] = {1001, 'NW', 1, 1, 1, true}}})
        end
        command(cmd)
        exec_lua([[
          vim.api.nvim_win_set_config(0, {relative = 'editor', row = 2, col = 2})
          vim.api.nvim_win_close(0, {})
          vim.api.nvim_echo({{''}}, false, {})
        ]])
        if multigrid then
          screen:expect({float_pos = {}})
        end
        assert_alive()
      end

      it('if WinClosed autocommand flushes UI', function()
        test_float_move_close('autocmd WinClosed * ++once redraw')
      end)

      it('if closing buffer flushes UI', function()
        test_float_move_close('autocmd BufWinLeave * ++once redraw')
      end)
    end)

    it(':sleep cursor placement #22639', function()
      local float_opts = {relative = 'editor', row = 1, col = 1, width = 4, height = 3}
      local win = api.nvim_open_win(api.nvim_create_buf(false, false), true, float_opts)
      feed('iab<CR>cd<Esc>')
      feed(':sleep 100')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
          :sleep 100^                              |
        ## grid 4
          {1:ab  }|
          {1:cd  }|
          {2:~   }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 1, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 1, curcol = 1, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~}{1:ab  }{0:                                   }|
          {0:~}{1:cd  }{0:                                   }|
          {0:~}{2:~   }{0:                                   }|
          {0:~                                       }|*2
          :sleep 100^                              |
        ]]}
      end

      feed('<CR>')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
          :sleep 100                              |
        ## grid 4
          {1:ab  }|
          {1:c^d  }|
          {2:~   }|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 1, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 1, curcol = 1, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~}{1:ab  }{0:                                   }|
          {0:~}{1:c^d  }{0:                                   }|
          {0:~}{2:~   }{0:                                   }|
          {0:~                                       }|*2
          :sleep 100                              |
        ]]}
      end
      feed('<C-C>')
      screen:expect_unchanged()

      api.nvim_win_set_config(win, {border = 'single'})
      feed(':sleep 100')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
          :sleep 100^                              |
        ## grid 4
          {5:┌────┐}|
          {5:│}{1:ab  }{5:│}|
          {5:│}{1:cd  }{5:│}|
          {5:│}{2:~   }{5:│}|
          {5:└────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 1, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 1, curcol = 1, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~}{5:┌────┐}{0:                                 }|
          {0:~}{5:│}{1:ab  }{5:│}{0:                                 }|
          {0:~}{5:│}{1:cd  }{5:│}{0:                                 }|
          {0:~}{5:│}{2:~   }{5:│}{0:                                 }|
          {0:~}{5:└────┘}{0:                                 }|
          :sleep 100^                              |
        ]]}
      end

      feed('<CR>')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
          :sleep 100                              |
        ## grid 4
          {5:┌────┐}|
          {5:│}{1:ab  }{5:│}|
          {5:│}{1:c^d  }{5:│}|
          {5:│}{2:~   }{5:│}|
          {5:└────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 1, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 1, curcol = 1, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~}{5:┌────┐}{0:                                 }|
          {0:~}{5:│}{1:ab  }{5:│}{0:                                 }|
          {0:~}{5:│}{1:c^d  }{5:│}{0:                                 }|
          {0:~}{5:│}{2:~   }{5:│}{0:                                 }|
          {0:~}{5:└────┘}{0:                                 }|
          :sleep 100                              |
        ]]}
      end
      feed('<C-C>')
      screen:expect_unchanged()

      command('setlocal winbar=foo')
      feed(':sleep 100')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
          :sleep 100^                              |
        ## grid 4
          {5:┌────┐}|
          {5:│}{3:foo }{5:│}|
          {5:│}{1:ab  }{5:│}|
          {5:│}{1:cd  }{5:│}|
          {5:└────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 1, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 1, curcol = 1, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~}{5:┌────┐}{0:                                 }|
          {0:~}{5:│}{3:foo }{5:│}{0:                                 }|
          {0:~}{5:│}{1:ab  }{5:│}{0:                                 }|
          {0:~}{5:│}{1:cd  }{5:│}{0:                                 }|
          {0:~}{5:└────┘}{0:                                 }|
          :sleep 100^                              |
        ]]}
      end

      feed('<CR>')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
          :sleep 100                              |
        ## grid 4
          {5:┌────┐}|
          {5:│}{3:foo }{5:│}|
          {5:│}{1:ab  }{5:│}|
          {5:│}{1:c^d  }{5:│}|
          {5:└────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 1, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 2, curline = 1, curcol = 1, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~}{5:┌────┐}{0:                                 }|
          {0:~}{5:│}{3:foo }{5:│}{0:                                 }|
          {0:~}{5:│}{1:ab  }{5:│}{0:                                 }|
          {0:~}{5:│}{1:c^d  }{5:│}{0:                                 }|
          {0:~}{5:└────┘}{0:                                 }|
          :sleep 100                              |
        ]]}
      end
      feed('<C-C>')
      screen:expect_unchanged()
    end)

    it('with rightleft and border #22640', function()
      local float_opts = {relative='editor', width=5, height=3, row=1, col=1, border='single'}
      api.nvim_open_win(api.nvim_create_buf(false, false), true, float_opts)
      command('setlocal rightleft')
      feed('iabc<CR>def<Esc>')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌─────┐}|
          {5:│}{1:  cba}{5:│}|
          {5:│}{1:  ^fed}{5:│}|
          {5:│}{2:    ~}{5:│}|
          {5:└─────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 1, 1, true, 50};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 3, curline = 1, curcol = 2, linecount = 2, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~}{5:┌─────┐}{0:                                }|
          {0:~}{5:│}{1:  cba}{5:│}{0:                                }|
          {0:~}{5:│}{1:  ^fed}{5:│}{0:                                }|
          {0:~}{5:│}{2:    ~}{5:│}{0:                                }|
          {0:~}{5:└─────┘}{0:                                }|
                                                  |
        ]]}
      end
    end)

    it('float window with hide option', function()
      local buf = api.nvim_create_buf(false,false)
      local win = api.nvim_open_win(buf, false, {relative='editor', width=10, height=2, row=2, col=5, hide = true})
      local expected_pos = {
          [4]={1001, 'NW', 1, 2, 5, true},
      }

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |

        ## grid 4 (hidden)
          {1:          }|
          {2:~         }|
        ]], float_pos = {}}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|*5
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {hide = false})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |

        ## grid 4
          {1:          }|
          {2:~         }|
        ]], float_pos = expected_pos}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~    }{1:          }{0:                         }|
          {0:~    }{2:~         }{0:                         }|
          {0:~                                       }|*2
                                                  |
        ]])
      end

      api.nvim_win_set_config(win, {hide=true})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |

        ## grid 4 (hidden)
          {1:          }|
          {2:~         }|
        ]], float_pos = {}}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|*5
                                                  |
        ]])
      end
    end)

    it(':fclose command #9663', function()
      local buf_a = api.nvim_create_buf(false,false)
      local buf_b = api.nvim_create_buf(false,false)
      local buf_c = api.nvim_create_buf(false,false)
      local buf_d = api.nvim_create_buf(false,false)
      local config_a = {relative='editor', width=11, height=11, row=5, col=5, border ='single', zindex=50}
      local config_b = {relative='editor', width=8, height=8, row=7, col=7, border ='single', zindex=70}
      local config_c = {relative='editor', width=4, height=4, row=9, col=9, border ='single',zindex=90}
      local config_d = {relative='editor', width=2, height=2, row=10, col=10, border ='single',zindex=100}
      api.nvim_open_win(buf_a, false, config_a)
      api.nvim_open_win(buf_b, false, config_b)
      api.nvim_open_win(buf_c, false, config_c)
      api.nvim_open_win(buf_d, false, config_d)
      local expected_pos = {
          [4]={1001, 'NW', 1, 5, 5, true, 50},
          [5]={1002, 'NW', 1, 7, 7, true, 70},
          [6]={1003, 'NW', 1, 9, 9, true, 90},
          [7]={1004, 'NW', 1, 10, 10, true, 100},
      }
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |
        ## grid 4
          {5:┌───────────┐}|
          {5:│}{1:           }{5:│}|
          {5:│}{2:~          }{5:│}|*10
          {5:└───────────┘}|
        ## grid 5
          {5:┌────────┐}|
          {5:│}{1:        }{5:│}|
          {5:│}{2:~       }{5:│}|*7
          {5:└────────┘}|
        ## grid 6
          {5:┌────┐}|
          {5:│}{1:    }{5:│}|
          {5:│}{2:~   }{5:│}|*3
          {5:└────┘}|
        ## grid 7
          {5:┌──┐}|
          {5:│}{1:  }{5:│}|
          {5:│}{2:~ }{5:│}|
          {5:└──┘}|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^     {5:┌─┌─┌────┐─┐┐}                      |
          {0:~    }{5:│}{1: }{5:│}{1: }{5:│}{1:    }{5:│}{1: }{5:││}{0:                      }|
          {0:~    }{5:│}{2:~}{5:│}{2:~}{5:│┌──┐│}{2: }{5:││}{0:                      }|
          {0:~    }{5:│}{2:~}{5:│}{2:~}{5:││}{1:  }{5:││}{2: }{5:││}{0:                      }|
          {0:~    }{5:│}{2:~}{5:│}{2:~}{5:││}{2:~ }{5:││}{2: }{5:││}{0:                      }|
          {0:~    }{5:│}{2:~}{5:│}{2:~}{5:└└──┘┘}{2: }{5:││}{0:                      }|
                                                  |
        ]])
      end
      -- close the window with the highest zindex value
      command('fclose')
      expected_pos[7] = nil
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |

        ## grid 4
          {5:┌───────────┐}|
          {5:│}{1:           }{5:│}|
          {5:│}{2:~          }{5:│}|*10
          {5:└───────────┘}|
        ## grid 5
          {5:┌────────┐}|
          {5:│}{1:        }{5:│}|
          {5:│}{2:~       }{5:│}|*7
          {5:└────────┘}|
        ## grid 6
          {5:┌────┐}|
          {5:│}{1:    }{5:│}|
          {5:│}{2:~   }{5:│}|*3
          {5:└────┘}|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^     {5:┌─┌─┌────┐─┐┐}                      |
          {0:~    }{5:│}{1: }{5:│}{1: }{5:│}{1:    }{5:│}{1: }{5:││}{0:                      }|
          {0:~    }{5:│}{2:~}{5:│}{2:~}{5:│}{2:~   }{5:│}{2: }{5:││}{0:                      }|*3
          {0:~    }{5:│}{2:~}{5:│}{2:~}{5:└────┘}{2: }{5:││}{0:                      }|
                                                  |
        ]])
      end
      -- with range
      command('1fclose')
      expected_pos[6] = nil
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |

        ## grid 4
          {5:┌───────────┐}|
          {5:│}{1:           }{5:│}|
          {5:│}{2:~          }{5:│}|*10
          {5:└───────────┘}|
        ## grid 5
          {5:┌────────┐}|
          {5:│}{1:        }{5:│}|
          {5:│}{2:~       }{5:│}|*7
          {5:└────────┘}|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^     {5:┌─┌────────┐┐}                      |
          {0:~    }{5:│}{1: }{5:│}{1:        }{5:││}{0:                      }|
          {0:~    }{5:│}{2:~}{5:│}{2:~       }{5:││}{0:                      }|*4
                                                  |
        ]])
      end
      -- with bang
      command('fclose!')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*6
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|*5
        ## grid 3
                                                  |

        ]], float_pos={}}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|*5
                                                  |
        ]])
      end
    end)

    it('correctly placed in or above message area', function()
      local float_opts = {relative='editor', width=5, height=1, row=100, col=1, border = 'single'}
      api.nvim_set_option_value('cmdheight', 3, {})
      command("echo 'cmdline'")
      local win = api.nvim_open_win(api.nvim_create_buf(false, false), true, float_opts)
      -- Not hidden behind message area but placed above it.
      if multigrid then
        screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|*4
            [3:----------------------------------------]|*3
          ## grid 2
                                                    |
            {0:~                                       }|*3
          ## grid 3
            cmdline                                 |
                                                    |*2
          ## grid 4
            {5:┌─────┐}|
            {5:│}{1:^     }{5:│}|
            {5:└─────┘}|
          ]], float_pos={
            [4] = {1001, "NW", 1, 100, 1, true, 50};
          }, win_viewport={
            [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
            [4] = {win = 1001, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~}{5:┌─────┐}{0:                                }|
          {0:~}{5:│}{1:^     }{5:│}{0:                                }|
          {0:~}{5:└─────┘}{0:                                }|
          cmdline                                 |
                                                  |*2
        ]]}
      end
      -- Not placed above message area and visible on top of it.
      api.nvim_win_set_config(win, {zindex = 300})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|*4
          [3:----------------------------------------]|*3
        ## grid 2
                                                  |
          {0:~                                       }|*3
        ## grid 3
          cmdline                                 |
                                                  |*2
        ## grid 4
          {5:┌─────┐}|
          {5:│}{1:^     }{5:│}|
          {5:└─────┘}|
        ]], float_pos={
          [4] = {1001, "NW", 1, 100, 1, true, 300};
        }, win_viewport={
          [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
          [4] = {win = 1001, topline = 0, botline = 1, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
        }}
      else
        screen:expect{grid=[[
                                                  |
          {0:~                                       }|*3
          c{5:┌─────┐}                                |
           {5:│}{1:^     }{5:│}                                |
           {5:└─────┘}                                |
        ]]}
      end
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)
  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)

