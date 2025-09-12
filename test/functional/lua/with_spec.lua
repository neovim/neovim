local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local fn = n.fn
local api = n.api
local command = n.command
local eq = t.eq
local exec_lua = n.exec_lua
local exec_capture = n.exec_capture
local matches = t.matches
local pcall_err = t.pcall_err

describe('vim._with', function()
  before_each(function()
    n.clear()
    exec_lua([[
      _G.fn = vim.fn
      _G.api = vim.api

      _G.setup_buffers = function()
        return api.nvim_create_buf(false, true), api.nvim_get_current_buf()
      end

      _G.setup_windows = function()
        local other_win = api.nvim_get_current_win()
        vim.cmd.new()
        return other_win, api.nvim_get_current_win()
      end
    ]])
  end)

  local assert_events_trigger = function()
    local out = exec_lua [[
      -- Needs three global values defined:
      -- - `test_events` - array of events which are tested.
      -- - `test_context` - context to be tested.
      -- - `test_trig_event` - callable triggering at least one tested event.
      _G.n_events = 0
      local opts = { callback = function() _G.n_events = _G.n_events + 1 end }
      api.nvim_create_autocmd(_G.test_events, opts)

      local context = { bo = { commentstring = '-- %s' } }

      -- Should not trigger events on its own
      vim._with(_G.test_context, function() end)
      local is_no_events = _G.n_events == 0

      -- Should trigger events if specifically asked inside callback
      local is_events = vim._with(_G.test_context, function()
        _G.test_trig_event()
        return _G.n_events > 0
      end)
      return { is_no_events, is_events }
    ]]
    eq({ true, true }, out)
  end

  describe('`bo` context', function()
    before_each(function()
      exec_lua [[
        _G.other_buf, _G.cur_buf = setup_buffers()

        -- 'commentstring' is local to buffer and string
        vim.bo[other_buf].commentstring = '## %s'
        vim.bo[cur_buf].commentstring = '// %s'
        vim.go.commentstring = '$$ %s'

        -- 'undolevels' is global or local to buffer (global-local) and number
        vim.bo[other_buf].undolevels = 100
        vim.bo[cur_buf].undolevels = 250
        vim.go.undolevels = 500

        _G.get_state = function()
          return {
            bo = {
              cms_cur = vim.bo[cur_buf].commentstring,
              cms_other = vim.bo[other_buf].commentstring,
              ul_cur = vim.bo[cur_buf].undolevels,
              ul_other = vim.bo[other_buf].undolevels,
            },
            go = {
              cms = vim.go.commentstring,
              ul = vim.go.undolevels,
            },
          }
        end
      ]]
    end)

    it('works', function()
      local out = exec_lua [[
        local context = { bo = { commentstring = '-- %s', undolevels = 0 } }

        local before = get_state()
        local inner = vim._with(context, function()
          assert(api.nvim_get_current_buf() == cur_buf)
          return get_state()
        end)

        return { before = before, inner = inner, after = get_state() }
      ]]

      eq({
        bo = { cms_cur = '-- %s', cms_other = '## %s', ul_cur = 0, ul_other = 100 },
        go = { cms = '$$ %s', ul = 500 },
      }, out.inner)
      eq(out.before, out.after)
    end)

    it('sets options in `buf` context', function()
      local out = exec_lua [[
        local context = { buf = other_buf, bo = { commentstring = '-- %s', undolevels = 0 } }

        local before = get_state()
        local inner = vim._with(context, function()
          assert(api.nvim_get_current_buf() == other_buf)
          return get_state()
        end)

        return { before = before, inner = inner, after = get_state() }
      ]]

      eq({
        bo = { cms_cur = '// %s', cms_other = '-- %s', ul_cur = 250, ul_other = 0 },
        go = { cms = '$$ %s', ul = 500 },
      }, out.inner)
      eq(out.before, out.after)
    end)

    it('restores only options from context', function()
      local out = exec_lua [[
        local context = { bo = { commentstring = '-- %s' } }

        local inner = vim._with(context, function()
          assert(api.nvim_get_current_buf() == cur_buf)
          vim.bo[cur_buf].undolevels = 750
          vim.bo[cur_buf].commentstring = '!! %s'
          return get_state()
        end)

        return { inner = inner, after = get_state() }
      ]]

      eq({
        bo = { cms_cur = '!! %s', cms_other = '## %s', ul_cur = 750, ul_other = 100 },
        go = { cms = '$$ %s', ul = 500 },
      }, out.inner)
      eq({
        bo = { cms_cur = '// %s', cms_other = '## %s', ul_cur = 750, ul_other = 100 },
        go = { cms = '$$ %s', ul = 500 },
      }, out.after)
    end)

    it('does not trigger events', function()
      exec_lua [[
        _G.test_events = { 'BufEnter', 'BufLeave', 'BufWinEnter', 'BufWinLeave' }
        _G.test_context = { bo = { commentstring = '-- %s' } }
        _G.test_trig_event = function() vim.cmd.new() end
      ]]
      assert_events_trigger()
    end)

    it('can be nested', function()
      local out = exec_lua [[
        local before, before_inner, after_inner = get_state(), nil, nil
        vim._with({ bo = { commentstring = '-- %s', undolevels = 0 } }, function()
          before_inner = get_state()
          inner = vim._with({ bo = { commentstring = '!! %s' } }, get_state)
          after_inner = get_state()
        end)
        return {
          before = before, before_inner = before_inner,
          inner = inner,
          after_inner = after_inner, after = get_state(),
        }
      ]]
      eq('!! %s', out.inner.bo.cms_cur)
      eq(0, out.inner.bo.ul_cur)
      eq(out.before_inner, out.after_inner)
      eq(out.before, out.after)
    end)
  end)

  describe('`buf` context', function()
    it('works', function()
      local out = exec_lua [[
        local other_buf, cur_buf = setup_buffers()
        local inner = vim._with({ buf = other_buf }, function()
          return api.nvim_get_current_buf()
        end)
        return { inner == other_buf, api.nvim_get_current_buf() == cur_buf }
      ]]
      eq({ true, true }, out)
    end)

    it('does not trigger events', function()
      exec_lua [[
        _G.test_events = { 'BufEnter', 'BufLeave', 'BufWinEnter', 'BufWinLeave' }
        _G.test_context = { buf = other_buf }
        _G.test_trig_event = function() vim.cmd.new() end
      ]]
      assert_events_trigger()
    end)

    it('can access buffer options', function()
      local out = exec_lua [[
        other_buf, cur_buf = setup_buffers()
        vim.bo[other_buf].commentstring = '## %s'
        vim.bo[cur_buf].commentstring = '// %s'

        vim._with({ buf = other_buf }, function()
          vim.cmd.set('commentstring=--\\ %s')
        end)

        return vim.bo[other_buf].commentstring == '-- %s' and
          vim.bo[cur_buf].commentstring == '// %s'
      ]]
      eq(true, out)
    end)

    it('works with different kinds of buffers', function()
      exec_lua [[
        local assert_buf = function(buf)
          vim._with({ buf = buf }, function()
            assert(api.nvim_get_current_buf() == buf)
          end)
        end

        -- Current
        assert_buf(api.nvim_get_current_buf())

        -- Hidden listed
        local listed = api.nvim_create_buf(true, true)
        assert_buf(listed)

        -- Visible
        local other_win, cur_win = setup_windows()
        api.nvim_win_set_buf(other_win, listed)
        assert_buf(listed)

        -- Shown but not visible
        vim.cmd.tabnew()
        assert_buf(listed)

        -- Shown in several windows
        api.nvim_win_set_buf(0, listed)
        assert_buf(listed)

        -- Shown in floating window
        local float_buf = api.nvim_create_buf(false, true)
        local config = { relative = 'editor', row = 1, col = 1, width = 5, height = 5 }
        api.nvim_open_win(float_buf, false, config)
        assert_buf(float_buf)
      ]]
    end)

    it('does not cause ml_get errors with invalid visual selection', function()
      exec_lua [[
        api.nvim_buf_set_lines(0, 0, -1, true, { 'a', 'b', 'c' })
        api.nvim_feedkeys(vim.keycode('G<C-V>'), 'txn', false)
        local other_buf, _ = setup_buffers()
        vim._with({ buf = buf }, function() vim.cmd.redraw() end)
      ]]
    end)

    it('can be nested', function()
      exec_lua [[
        local other_buf, cur_buf = setup_buffers()
        vim._with({ buf = other_buf }, function()
          assert(api.nvim_get_current_buf() == other_buf)
          inner = vim._with({ buf = cur_buf }, function()
            assert(api.nvim_get_current_buf() == cur_buf)
          end)
          assert(api.nvim_get_current_buf() == other_buf)
        end)
        assert(api.nvim_get_current_buf() == cur_buf)
      ]]
    end)

    it('can be nested crazily with hidden buffers', function()
      local out = exec_lua([[
        local n = 0
        local function with_recursive_nested_bufs()
          n = n + 1
          if n > 20 then return true end

          local other_buf, _ = setup_buffers()
          vim.bo[other_buf].commentstring = '## %s'
          local callback = function()
            return api.nvim_get_current_buf() == other_buf
              and vim.bo[other_buf].commentstring == '## %s'
              and with_recursive_nested_bufs()
          end
          return vim._with({ buf = other_buf }, callback) and
            api.nvim_buf_delete(other_buf, {}) == nil
        end

        return with_recursive_nested_bufs()
      ]])
      eq(true, out)
    end)
  end)

  describe('`emsg_silent` context', function()
    pending('works', function()
      local ok = pcall(
        exec_lua,
        [[
          _G.f = function()
            error('This error should not interfer with execution', 0)
          end
          -- Should not produce error same as `vim.cmd('silent! lua _G.f()')`
          vim._with({ emsg_silent = true }, f)
        ]]
      )
      eq(true, ok)

      -- Should properly report errors afterwards
      ok = pcall(exec_lua, 'lua _G.f()')
      eq(false, ok)
    end)

    it('can be nested', function()
      local ok = pcall(
        exec_lua,
        [[
          _G.f = function()
            error('This error should not interfer with execution', 0)
          end
          -- Should produce error same as `_G.f()`
          vim._with({ emsg_silent = true }, function()
            vim._with( { emsg_silent = false }, f)
          end)
        ]]
      )
      eq(false, ok)
    end)
  end)

  describe('`env` context', function()
    before_each(function()
      exec_lua [[
        vim.fn.setenv('aaa', 'hello')
        _G.get_state = function()
          return { aaa = vim.fn.getenv('aaa'), bbb = vim.fn.getenv('bbb') }
        end
      ]]
    end)

    it('works', function()
      local out = exec_lua [[
        local context = { env = { aaa = 'inside', bbb = 'wow' } }
        local before = get_state()
        local inner = vim._with(context, get_state)
        return { before = before, inner = inner, after = get_state() }
      ]]

      eq({ aaa = 'inside', bbb = 'wow' }, out.inner)
      eq(out.before, out.after)
    end)

    it('restores only variables from context', function()
      local out = exec_lua [[
        local context = { env = { bbb = 'wow' } }
        local before = get_state()
        local inner = vim._with(context, function()
          vim.env.aaa = 'inside'
          return get_state()
        end)
        return { before = before, inner = inner, after = get_state() }
      ]]

      eq({ aaa = 'inside', bbb = 'wow' }, out.inner)
      eq({ aaa = 'inside', bbb = vim.NIL }, out.after)
    end)

    it('can be nested', function()
      local out = exec_lua [[
        local before, before_inner, after_inner = get_state(), nil, nil
        vim._with({ env = { aaa = 'inside', bbb = 'wow' } }, function()
          before_inner = get_state()
          inner = vim._with({ env = { aaa = 'more inside' } }, get_state)
          after_inner = get_state()
        end)
        return {
          before = before, before_inner = before_inner,
          inner = inner,
          after_inner = after_inner, after = get_state(),
        }
      ]]
      eq('more inside', out.inner.aaa)
      eq('wow', out.inner.bbb)
      eq(out.before_inner, out.after_inner)
      eq(out.before, out.after)
    end)
  end)

  describe('`go` context', function()
    before_each(function()
      exec_lua [[
        vim.bo.commentstring = '## %s'
        vim.go.commentstring = '$$ %s'
        vim.wo.winblend = 25
        vim.go.winblend = 50
        vim.go.langmap = 'xy,yx'

        _G.get_state = function()
          return {
            bo = { cms = vim.bo.commentstring },
            wo = { winbl = vim.wo.winblend },
            go = {
              cms = vim.go.commentstring,
              winbl = vim.go.winblend,
              lmap = vim.go.langmap,
            },
          }
        end
      ]]
    end)

    it('works', function()
      local out = exec_lua [[
        local context = {
          go = { commentstring = '-- %s', winblend = 75, langmap = 'ab,ba' },
        }
        local before = get_state()
        local inner = vim._with(context, get_state)
        return { before = before, inner = inner, after = get_state() }
      ]]

      eq({
        bo = { cms = '## %s' },
        wo = { winbl = 25 },
        go = { cms = '-- %s', winbl = 75, lmap = 'ab,ba' },
      }, out.inner)
      eq(out.before, out.after)
    end)

    it('works with `eventignore`', function()
      -- This might be an issue if saving and restoring option context is done
      -- to account for triggering `OptionSet`, but in not a good way
      local out = exec_lua [[
        vim.go.eventignore = 'ModeChanged'
        local inner = vim._with({ go = { eventignore = 'CursorMoved' } }, function()
          return vim.go.eventignore
        end)
        return { inner = inner, after = vim.go.eventignore }
      ]]
      eq({ inner = 'CursorMoved', after = 'ModeChanged' }, out)
    end)

    it('restores only options from context', function()
      local out = exec_lua [[
        local context = { go = { langmap = 'ab,ba' } }

        local inner = vim._with(context, function()
          vim.go.commentstring = '!! %s'
          vim.go.winblend = 75
          vim.go.langmap = 'uv,vu'
          return get_state()
        end)

        return { inner = inner, after = get_state() }
      ]]

      eq({
        bo = { cms = '## %s' },
        wo = { winbl = 25 },
        go = { cms = '!! %s', winbl = 75, lmap = 'uv,vu' },
      }, out.inner)
      eq({
        bo = { cms = '## %s' },
        wo = { winbl = 25 },
        go = { cms = '!! %s', winbl = 75, lmap = 'xy,yx' },
      }, out.after)
    end)

    it('does not trigger events', function()
      exec_lua [[
        _G.test_events = {
          'BufEnter', 'BufLeave', 'BufWinEnter', 'BufWinLeave', 'WinEnter', 'WinLeave'
        }
        _G.test_context = { go = { commentstring = '-- %s', winblend = 75, langmap = 'ab,ba' } }
        _G.test_trig_event = function() vim.cmd.new() end
      ]]
      assert_events_trigger()
    end)

    it('can be nested', function()
      local out = exec_lua [[
        local before, before_inner, after_inner = get_state(), nil, nil
        vim._with({ go = { langmap = 'ab,ba', commentstring = '-- %s' } }, function()
          before_inner = get_state()
          inner = vim._with({ go = { langmap = 'uv,vu' } }, get_state)
          after_inner = get_state()
        end)
        return {
          before = before, before_inner = before_inner,
          inner = inner,
          after_inner = after_inner, after = get_state(),
        }
      ]]
      eq('uv,vu', out.inner.go.lmap)
      eq('-- %s', out.inner.go.cms)
      eq(out.before_inner, out.after_inner)
      eq(out.before, out.after)
    end)
  end)

  describe('`hide` context', function()
    pending('works', function()
      local ok = pcall(
        exec_lua,
        [[
          vim.o.hidden = false
          vim.bo.modified = true
          local init_buf = api.nvim_get_current_buf()
          -- Should not produce error same as `vim.cmd('hide enew')`
          vim._with({ hide = true }, function()
            vim.cmd.enew()
          end)
          assert(api.nvim_get_current_buf() ~= init_buf)
        ]]
      )
      eq(true, ok)
    end)

    it('can be nested', function()
      local ok = pcall(
        exec_lua,
        [[
          vim.o.hidden = false
          vim.bo.modified = true
          -- Should produce error same as `vim.cmd.enew()`
          vim._with({ hide = true }, function()
            vim._with({ hide = false }, function()
              vim.cmd.enew()
            end)
          end)
        ]]
      )
      eq(false, ok)
    end)
  end)

  describe('`horizontal` context', function()
    local is_approx_eq = function(dim, id_1, id_2)
      local f = dim == 'height' and api.nvim_win_get_height or api.nvim_win_get_width
      return math.abs(f(id_1) - f(id_2)) <= 1
    end

    local win_id_1, win_id_2, win_id_3
    before_each(function()
      win_id_1 = api.nvim_get_current_win()
      command('wincmd v | wincmd 5>')
      win_id_2 = api.nvim_get_current_win()
      command('wincmd s | wincmd 5+')
      win_id_3 = api.nvim_get_current_win()

      eq(is_approx_eq('width', win_id_1, win_id_2), false)
      eq(is_approx_eq('height', win_id_3, win_id_2), false)
    end)

    pending('works', function()
      exec_lua [[
        -- Should be same as `vim.cmd('horizontal wincmd =')`
        vim._with({ horizontal = true }, function()
          vim.cmd.wincmd('=')
        end)
      ]]
      eq(is_approx_eq('width', win_id_1, win_id_2), true)
      eq(is_approx_eq('height', win_id_3, win_id_2), false)
    end)

    pending('can be nested', function()
      exec_lua [[
        -- Should be same as `vim.cmd.wincmd('=')`
        vim._with({ horizontal = true }, function()
          vim._with({ horizontal = false }, function()
            vim.cmd.wincmd('=')
          end)
        end)
      ]]
      eq(is_approx_eq('width', win_id_1, win_id_2), true)
      eq(is_approx_eq('height', win_id_3, win_id_2), true)
    end)
  end)

  describe('`keepalt` context', function()
    pending('works', function()
      local out = exec_lua [[
        vim.cmd('edit alt')
        vim.cmd('edit new')
        assert(fn.bufname('#') == 'alt')

        -- Should work as `vim.cmd('keepalt edit very-new')`
        vim._with({ keepalt = true }, function()
          vim.cmd.edit('very-new')
        end)
        return fn.bufname('#') == 'alt'
      ]]
      eq(true, out)
    end)

    it('can be nested', function()
      local out = exec_lua [[
        vim.cmd('edit alt')
        vim.cmd('edit new')
        assert(fn.bufname('#') == 'alt')

        -- Should work as `vim.cmd.edit('very-new')`
        vim._with({ keepalt = true }, function()
          vim._with({ keepalt = false }, function()
            vim.cmd.edit('very-new')
          end)
        end)
        return fn.bufname('#') == 'alt'
      ]]
      eq(false, out)
    end)
  end)

  describe('`keepjumps` context', function()
    pending('works', function()
      local out = exec_lua [[
        api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb', 'ccc' })
        local jumplist_before = fn.getjumplist()
        -- Should work as `vim.cmd('keepjumps normal! Ggg')`
        vim._with({ keepjumps = true }, function()
          vim.cmd('normal! Ggg')
        end)
        return vim.deep_equal(jumplist_before, fn.getjumplist())
      ]]
      eq(true, out)
    end)

    it('can be nested', function()
      local out = exec_lua [[
        api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb', 'ccc' })
        local jumplist_before = fn.getjumplist()
        vim._with({ keepjumps = true }, function()
          vim._with({ keepjumps = false }, function()
            vim.cmd('normal! Ggg')
          end)
        end)
        return vim.deep_equal(jumplist_before, fn.getjumplist())
      ]]
      eq(false, out)
    end)
  end)

  describe('`keepmarks` context', function()
    pending('works', function()
      local out = exec_lua [[
        vim.cmd('set cpoptions+=R')
        api.nvim_buf_set_lines(0, 0, -1, false, { 'bbb', 'ccc', 'aaa' })
        api.nvim_buf_set_mark(0, 'm', 2, 2, {})

        -- Should be the same as `vim.cmd('keepmarks %!sort')`
        vim._with({ keepmarks = true }, function()
          vim.cmd('%!sort')
        end)
        return api.nvim_buf_get_mark(0, 'm')
      ]]
      eq({ 2, 2 }, out)
    end)

    it('can be nested', function()
      local out = exec_lua [[
        vim.cmd('set cpoptions+=R')
        api.nvim_buf_set_lines(0, 0, -1, false, { 'bbb', 'ccc', 'aaa' })
        api.nvim_buf_set_mark(0, 'm', 2, 2, {})

        vim._with({ keepmarks = true }, function()
          vim._with({ keepmarks = false }, function()
            vim.cmd('%!sort')
          end)
        end)
        return api.nvim_buf_get_mark(0, 'm')
      ]]
      eq({ 0, 2 }, out)
    end)
  end)

  describe('`keepatterns` context', function()
    pending('works', function()
      local out = exec_lua [[
        api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb' })
        vim.cmd('/aaa')
        -- Should be the same as `vim.cmd('keeppatterns /bbb')`
        vim._with({ keeppatterns = true }, function()
          vim.cmd('/bbb')
        end)
        return fn.getreg('/')
      ]]
      eq('aaa', out)
    end)

    it('can be nested', function()
      local out = exec_lua [[
        api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb' })
        vim.cmd('/aaa')
        vim._with({ keeppatterns = true }, function()
          vim._with({ keeppatterns = false }, function()
            vim.cmd('/bbb')
          end)
        end)
        return fn.getreg('/')
      ]]
      eq('bbb', out)
    end)
  end)

  describe('`lockmarks` context', function()
    it('works', function()
      local mark = exec_lua [[
        api.nvim_buf_set_lines(0, 0, 0, false, { 'aaa', 'bbb', 'ccc' })
        api.nvim_buf_set_mark(0, 'm', 2, 2, {})
        -- Should be same as `:lockmarks lua api.nvim_buf_set_lines(...)`
        vim._with({ lockmarks = true }, function()
          api.nvim_buf_set_lines(0, 0, 2, false, { 'uuu', 'vvv', 'www' })
        end)
        return api.nvim_buf_get_mark(0, 'm')
      ]]
      eq({ 2, 2 }, mark)
    end)

    it('can be nested', function()
      local mark = exec_lua [[
        api.nvim_buf_set_lines(0, 0, 0, false, { 'aaa', 'bbb', 'ccc' })
        api.nvim_buf_set_mark(0, 'm', 2, 2, {})
        vim._with({ lockmarks = true }, function()
          vim._with({ lockmarks = false }, function()
            api.nvim_buf_set_lines(0, 0, 2, false, { 'uuu', 'vvv', 'www' })
          end)
        end)
        return api.nvim_buf_get_mark(0, 'm')
      ]]
      eq({ 0, 2 }, mark)
    end)
  end)

  describe('`noautocmd` context', function()
    it('works', function()
      local out = exec_lua [[
        _G.n_events = 0
        vim.cmd('au ModeChanged * lua _G.n_events = _G.n_events + 1')
        -- Should be the same as `vim.cmd('noautocmd normal! vv')`
        vim._with({ noautocmd = true }, function()
          vim.cmd('normal! vv')
        end)
        return _G.n_events
      ]]
      eq(0, out)
    end)

    it('works with User events', function()
      local out = exec_lua [[
        _G.n_events = 0
        vim.cmd('au User MyEvent lua _G.n_events = _G.n_events + 1')
        -- Should be the same as `vim.cmd('noautocmd doautocmd User MyEvent')`
        vim._with({ noautocmd = true }, function()
          api.nvim_exec_autocmds('User', { pattern = 'MyEvent' })
        end)
        return _G.n_events
      ]]
      eq(0, out)
    end)

    pending('can be nested', function()
      local out = exec_lua [[
        _G.n_events = 0
        vim.cmd('au ModeChanged * lua _G.n_events = _G.n_events + 1')
        vim._with({ noautocmd = true }, function()
          vim._with({ noautocmd = false }, function()
            vim.cmd('normal! vv')
          end)
        end)
        return _G.n_events
      ]]
      eq(2, out)
    end)
  end)

  describe('`o` context', function()
    before_each(function()
      exec_lua [[
        _G.other_win, _G.cur_win = setup_windows()
        _G.other_buf, _G.cur_buf = setup_buffers()

        vim.bo[other_buf].commentstring = '## %s'
        vim.bo[cur_buf].commentstring = '// %s'
        vim.go.commentstring = '$$ %s'

        vim.bo[other_buf].undolevels = 100
        vim.bo[cur_buf].undolevels = 250
        vim.go.undolevels = 500

        vim.wo[other_win].virtualedit = 'block'
        vim.wo[cur_win].virtualedit = 'insert'
        vim.go.virtualedit = 'none'

        vim.wo[other_win].winblend = 10
        vim.wo[cur_win].winblend = 25
        vim.go.winblend = 50

        vim.go.langmap = 'xy,yx'

        _G.get_state = function()
          return {
            bo = {
              cms_cur = vim.bo[cur_buf].commentstring,
              cms_other = vim.bo[other_buf].commentstring,
              ul_cur = vim.bo[cur_buf].undolevels,
              ul_other = vim.bo[other_buf].undolevels,
            },
            wo = {
              ve_cur = vim.wo[cur_win].virtualedit,
              ve_other = vim.wo[other_win].virtualedit,
              winbl_cur = vim.wo[cur_win].winblend,
              winbl_other = vim.wo[other_win].winblend,
            },
            go = {
              cms = vim.go.commentstring,
              ul = vim.go.undolevels,
              ve = vim.go.virtualedit,
              winbl = vim.go.winblend,
              lmap = vim.go.langmap,
            },
          }
        end
      ]]
    end)

    it('works', function()
      local out = exec_lua [[
        local context = {
          o = {
            commentstring = '-- %s',
            undolevels = 0,
            virtualedit = 'all',
            winblend = 75,
            langmap = 'ab,ba',
          },
        }

        local before = get_state()
        local inner = vim._with(context, function()
          assert(api.nvim_get_current_buf() == cur_buf)
          assert(api.nvim_get_current_win() == cur_win)
          return get_state()
        end)

        return { before = before, inner = inner, after = get_state() }
      ]]

      -- Options in context are set with `vim.o`, so usually both local
      -- and global values are affected. Yet all of them should be later
      -- restored to pre-context values.
      eq({
        bo = { cms_cur = '-- %s', cms_other = '## %s', ul_cur = -123456, ul_other = 100 },
        wo = { ve_cur = 'all', ve_other = 'block', winbl_cur = 75, winbl_other = 10 },
        go = { cms = '-- %s', ul = 0, ve = 'all', winbl = 75, lmap = 'ab,ba' },
      }, out.inner)
      eq(out.before, out.after)
    end)

    it('sets options in `buf` context', function()
      local out = exec_lua [[
        local context = { buf = other_buf, o = { commentstring = '-- %s', undolevels = 0 } }

        local before = get_state()
        local inner = vim._with(context, function()
          assert(api.nvim_get_current_buf() == other_buf)
          return get_state()
        end)

        return { before = before, inner = inner, after = get_state() }
      ]]

      eq({
        bo = { cms_cur = '// %s', cms_other = '-- %s', ul_cur = 250, ul_other = -123456 },
        wo = { ve_cur = 'insert', ve_other = 'block', winbl_cur = 25, winbl_other = 10 },
        -- Global `winbl` inside context ideally should be untouched and equal
        -- to 50. It seems to be equal to 0 because `context.buf` uses
        -- `aucmd_prepbuf` C approach which has no guarantees about window or
        -- window option values inside context.
        go = { cms = '-- %s', ul = 0, ve = 'none', winbl = 0, lmap = 'xy,yx' },
      }, out.inner)
      eq(out.before, out.after)
    end)

    it('sets options in `win` context', function()
      local out = exec_lua [[
        local context = { win = other_win, o = { winblend = 75, virtualedit = 'all' } }

        local before = get_state()
        local inner = vim._with(context, function()
          assert(api.nvim_get_current_win() == other_win)
          return get_state()
        end)

        return { before = before, inner = inner, after = get_state() }
      ]]

      eq({
        bo = { cms_cur = '// %s', cms_other = '## %s', ul_cur = 250, ul_other = 100 },
        wo = { winbl_cur = 25, winbl_other = 75, ve_cur = 'insert', ve_other = 'all' },
        go = { cms = '$$ %s', ul = 500, winbl = 75, ve = 'all', lmap = 'xy,yx' },
      }, out.inner)
      eq(out.before, out.after)
    end)

    it('restores only options from context', function()
      local out = exec_lua [[
        local context = { o = { undolevels = 0, winblend = 75, langmap = 'ab,ba' } }

        local inner = vim._with(context, function()
          assert(api.nvim_get_current_buf() == cur_buf)
          assert(api.nvim_get_current_win() == cur_win)

          vim.o.commentstring = '!! %s'
          vim.o.undolevels = 750
          vim.o.virtualedit = 'onemore'
          vim.o.winblend = 99
          vim.o.langmap = 'uv,vu'
          return get_state()
        end)

        return { inner = inner, after = get_state() }
      ]]

      eq({
        bo = { cms_cur = '!! %s', cms_other = '## %s', ul_cur = -123456, ul_other = 100 },
        wo = { ve_cur = 'onemore', ve_other = 'block', winbl_cur = 99, winbl_other = 10 },
        go = { cms = '!! %s', ul = 750, ve = 'onemore', winbl = 99, lmap = 'uv,vu' },
      }, out.inner)
      eq({
        bo = { cms_cur = '!! %s', cms_other = '## %s', ul_cur = 250, ul_other = 100 },
        wo = { ve_cur = 'onemore', ve_other = 'block', winbl_cur = 25, winbl_other = 10 },
        go = { cms = '!! %s', ul = 500, ve = 'onemore', winbl = 50, lmap = 'xy,yx' },
      }, out.after)
    end)

    it('does not trigger events', function()
      exec_lua [[
        _G.test_events = {
          'BufEnter', 'BufLeave', 'WinEnter', 'WinLeave', 'BufWinEnter', 'BufWinLeave'
        }
        _G.test_context = { o = { undolevels = 0, winblend = 75, langmap = 'ab,ba' } }
        _G.test_trig_event = function() vim.cmd.new() end
      ]]
      assert_events_trigger()
    end)

    it('can be nested', function()
      local out = exec_lua [[
        local before, before_inner, after_inner = get_state(), nil, nil
        local cxt_o = { commentstring = '-- %s', winblend = 75, langmap = 'ab,ba', undolevels = 0 }
        vim._with({ o = cxt_o }, function()
          before_inner = get_state()
          local inner_cxt_o = { commentstring = '!! %s', winblend = 99, langmap = 'uv,vu' }
          inner = vim._with({ o = inner_cxt_o }, get_state)
          after_inner = get_state()
        end)
        return {
          before = before, before_inner = before_inner,
          inner = inner,
          after_inner = after_inner, after = get_state(),
        }
      ]]
      eq('!! %s', out.inner.bo.cms_cur)
      eq(99, out.inner.wo.winbl_cur)
      eq('uv,vu', out.inner.go.lmap)
      eq(0, out.inner.go.ul)
      eq(out.before_inner, out.after_inner)
      eq(out.before, out.after)
    end)
  end)

  describe('`sandbox` context', function()
    it('works', function()
      local ok, err = pcall(
        exec_lua,
        [[
          -- Should work as `vim.cmd('sandbox call append(0, "aaa")')`
          vim._with({ sandbox = true }, function()
            fn.append(0, 'aaa')
          end)
        ]]
      )
      eq(false, ok)
      matches('Not allowed in sandbox', err)
    end)

    it('can NOT be nested', function()
      -- This behavior is intentionally different from other flags as allowing
      -- disabling `sandbox` from nested function seems to be against the point
      -- of using `sandbox` context in the first place
      local ok, err = pcall(
        exec_lua,
        [[
          vim._with({ sandbox = true }, function()
            vim._with({ sandbox = false }, function()
              fn.append(0, 'aaa')
            end)
          end)
        ]]
      )
      eq(false, ok)
      matches('Not allowed in sandbox', err)
    end)
  end)

  describe('`silent` context', function()
    it('works', function()
      exec_lua [[
        -- Should be same as `vim.cmd('silent lua print("aaa")')`
        vim._with({ silent = true }, function() print('aaa') end)
      ]]
      eq('', exec_capture('messages'))

      exec_lua [[ vim._with({ silent = true }, function() vim.cmd.echomsg('"bbb"') end) ]]
      eq('', exec_capture('messages'))

      local screen = Screen.new(20, 5)
      screen:set_default_attr_ids {
        [1] = { bold = true, reverse = true },
        [2] = { bold = true, foreground = Screen.colors.Blue },
      }
      exec_lua [[ vim._with({ silent = true }, function() vim.cmd.echo('"ccc"') end) ]]
      screen:expect [[
        ^                    |
        {2:~                   }|*3
                            |
      ]]
    end)

    pending('can be nested', function()
      exec_lua [[ vim._with({ silent = true }, function()
        vim._with({ silent = false }, function()
          print('aaa')
        end)
      end)]]
      eq('aaa', exec_capture('messages'))
    end)
  end)

  describe('`unsilent` context', function()
    it('works', function()
      exec_lua [[
        _G.f = function()
          -- Should be same as `vim.cmd('unsilent lua print("aaa")')`
          vim._with({ unsilent = true }, function() print('aaa') end)
        end
      ]]
      command('silent lua f()')
      eq('aaa', exec_capture('messages'))
    end)

    pending('can be nested', function()
      exec_lua [[
        _G.f = function()
          vim._with({ unsilent = true }, function()
            vim._with({ unsilent = false }, function() print('aaa') end)
          end)
        end
      ]]
      command('silent lua f()')
      eq('', exec_capture('messages'))
    end)
  end)

  describe('`win` context', function()
    it('works', function()
      local out = exec_lua [[
        local other_win, cur_win = setup_windows()
        local inner = vim._with({ win = other_win }, function()
          return api.nvim_get_current_win()
        end)
        return { inner == other_win, api.nvim_get_current_win() == cur_win }
      ]]
      eq({ true, true }, out)
    end)

    it('does not trigger events', function()
      exec_lua [[
        _G.test_events = { 'WinEnter', 'WinLeave', 'BufWinEnter', 'BufWinLeave' }
        _G.test_context = { win = other_win }
        _G.test_trig_event = function() vim.cmd.new() end
      ]]
      assert_events_trigger()
    end)

    it('can access window options', function()
      local out = exec_lua [[
        local other_win, cur_win = setup_windows()
        vim.wo[other_win].winblend = 10
        vim.wo[cur_win].winblend = 25

        vim._with({ win = other_win }, function()
          vim.cmd.setlocal('winblend=0')
        end)

        return vim.wo[other_win].winblend == 0 and vim.wo[cur_win].winblend == 25
      ]]
      eq(true, out)
    end)

    it('works with different kinds of windows', function()
      exec_lua [[
        local assert_win = function(win)
          vim._with({ win = win }, function()
            assert(api.nvim_get_current_win() == win)
          end)
        end

        -- Current
        assert_win(api.nvim_get_current_win())

        -- Not visible
        local other_win, cur_win = setup_windows()
        vim.cmd.tabnew()
        assert_win(other_win)

        -- Floating
        local float_win = api.nvim_open_win(
          api.nvim_create_buf(false, true),
          false,
          { relative = 'editor', row = 1, col = 1, height = 5, width = 5}
        )
        assert_win(float_win)
      ]]
    end)

    it('does not cause ml_get errors with invalid visual selection', function()
      exec_lua [[
        local feedkeys = function(keys) api.nvim_feedkeys(vim.keycode(keys), 'txn', false) end

        -- Add lines to the current buffer and make another window looking into an empty buffer.
        local win_empty, win_lines = setup_windows()
        api.nvim_buf_set_lines(0, 0, -1, true, { 'a', 'b', 'c' })

        -- Start Visual in current window, redraw in other window with fewer lines.
        -- Should be fixed by vim-patch:8.2.4018.
        feedkeys('G<C-V>')
        vim._with({ win = win_empty }, function() vim.cmd.redraw() end)

        -- Start Visual in current window, extend it in other window with more lines.
        -- Fixed for win_execute by vim-patch:8.2.4026, but nvim_win_call should also not be affected.
        feedkeys('<Esc>gg')
        api.nvim_set_current_win(win_empty)
        feedkeys('gg<C-V>')
        vim._with({ win = win_lines }, function() feedkeys('G<C-V>') end)
        vim.cmd.redraw()
      ]]
    end)

    it('can be nested', function()
      exec_lua [[
        local other_win, cur_win = setup_windows()
        vim._with({ win = other_win }, function()
          assert(api.nvim_get_current_win() == other_win)
          inner = vim._with({ win = cur_win }, function()
            assert(api.nvim_get_current_win() == cur_win)
          end)
          assert(api.nvim_get_current_win() == other_win)
        end)
        assert(api.nvim_get_current_win() == cur_win)
      ]]
    end)

    it('updates ruler if cursor moved', function()
      local screen = Screen.new(30, 5)
      screen:set_default_attr_ids {
        [1] = { reverse = true },
        [2] = { bold = true, reverse = true },
      }
      exec_lua [[
        vim.opt.ruler = true
        local lines = {}
        for i = 0, 499 do lines[#lines + 1] = tostring(i) end
        api.nvim_buf_set_lines(0, 0, -1, true, lines)
        api.nvim_win_set_cursor(0, { 20, 0 })
        vim.cmd 'split'
        _G.win = api.nvim_get_current_win()
        vim.cmd "wincmd w | redraw"
      ]]
      screen:expect [[
        19                            |
        {1:< Name] [+] 20,1            3%}|
        ^19                            |
        {2:< Name] [+] 20,1            3%}|
                                      |
      ]]
      exec_lua [[
        vim._with({ win = win }, function() api.nvim_win_set_cursor(0, { 100, 0 }) end)
        vim.cmd "redraw"
      ]]
      screen:expect [[
        99                            |
        {1:< Name] [+] 100,1          19%}|
        ^19                            |
        {2:< Name] [+] 20,1            3%}|
                                      |
      ]]
    end)

    it('layout in current tabpage does not affect windows in others', function()
      command('tab split')
      local t2_move_win = api.nvim_get_current_win()
      command('vsplit')
      local t2_other_win = api.nvim_get_current_win()
      command('tabprevious')
      matches('E36: Not enough room$', pcall_err(command, 'execute "split|"->repeat(&lines)'))
      command('vsplit')

      exec_lua('vim._with({ win = ... }, function() vim.cmd.wincmd "J" end)', t2_move_win)
      eq({ 'col', { { 'leaf', t2_other_win }, { 'leaf', t2_move_win } } }, fn.winlayout(2))
    end)
  end)

  describe('`wo` context', function()
    before_each(function()
      exec_lua [[
        _G.other_win, _G.cur_win = setup_windows()

        -- 'virtualedit' is global or local to window (global-local) and string
        vim.wo[other_win].virtualedit = 'block'
        vim.wo[cur_win].virtualedit = 'insert'
        vim.go.virtualedit = 'none'

        -- 'winblend' is local to window and number
        vim.wo[other_win].winblend = 10
        vim.wo[cur_win].winblend = 25
        vim.go.winblend = 50

        _G.get_state = function()
          return {
            wo = {
              ve_cur = vim.wo[cur_win].virtualedit,
              ve_other = vim.wo[other_win].virtualedit,
              winbl_cur = vim.wo[cur_win].winblend,
              winbl_other = vim.wo[other_win].winblend,
            },
            go = {
              ve = vim.go.virtualedit,
              winbl = vim.go.winblend,
            },
          }
        end
      ]]
    end)

    it('works', function()
      local out = exec_lua [[
        local context = { wo = { virtualedit = 'all', winblend = 75 } }

        local before = get_state()
        local inner = vim._with(context, function()
          assert(api.nvim_get_current_win() == cur_win)
          return get_state()
        end)

        return { before = before, inner = inner, after = get_state() }
      ]]

      eq({
        wo = { ve_cur = 'all', ve_other = 'block', winbl_cur = 75, winbl_other = 10 },
        go = { ve = 'none', winbl = 75 },
      }, out.inner)
      eq(out.before, out.after)
    end)

    it('sets options in `win` context', function()
      local out = exec_lua [[
        local context = { win = other_win, wo = { virtualedit = 'all', winblend = 75 } }

        local before = get_state()
        local inner = vim._with(context, function()
          assert(api.nvim_get_current_win() == other_win)
          return get_state()
        end)

        return { before = before, inner = inner, after = get_state() }
      ]]

      eq({
        wo = { ve_cur = 'insert', ve_other = 'all', winbl_cur = 25, winbl_other = 75 },
        go = { ve = 'none', winbl = 75 },
      }, out.inner)
      eq(out.before, out.after)
    end)

    it('restores only options from context', function()
      local out = exec_lua [[
        local context = { wo = { winblend = 75 } }

        local inner = vim._with(context, function()
          assert(api.nvim_get_current_win() == cur_win)
          vim.wo[cur_win].virtualedit = 'onemore'
          vim.wo[cur_win].winblend = 99
          return get_state()
        end)

        return { inner = inner, after = get_state() }
      ]]

      eq({
        wo = { ve_cur = 'onemore', ve_other = 'block', winbl_cur = 99, winbl_other = 10 },
        go = { ve = 'none', winbl = 99 },
      }, out.inner)
      eq({
        wo = { ve_cur = 'onemore', ve_other = 'block', winbl_cur = 25, winbl_other = 10 },
        go = { ve = 'none', winbl = 50 },
      }, out.after)
    end)

    it('does not trigger events', function()
      exec_lua [[
        _G.test_events = { 'WinEnter', 'WinLeave', 'BufWinEnter', 'BufWinLeave' }
        _G.test_context = { wo = { winblend = 75 } }
        _G.test_trig_event = function() vim.cmd.new() end
      ]]
      assert_events_trigger()
    end)

    it('can be nested', function()
      local out = exec_lua [[
        local before, before_inner, after_inner = get_state(), nil, nil
        vim._with({ wo = { winblend = 75, virtualedit = 'all' } }, function()
          before_inner = get_state()
          inner = vim._with({ wo = { winblend = 99 } }, get_state)
          after_inner = get_state()
        end)
        return {
          before = before, before_inner = before_inner,
          inner = inner,
          after_inner = after_inner, after = get_state(),
        }
      ]]
      eq(99, out.inner.wo.winbl_cur)
      eq('all', out.inner.wo.ve_cur)
      eq(out.before_inner, out.after_inner)
      eq(out.before, out.after)
    end)
  end)

  it('returns what callback returns', function()
    local out_verify = exec_lua [[
      out = { vim._with({}, function()
        return 'a', 2, nil, { 4 }, function() end
      end) }
      return {
        out[1] == 'a', out[2] == 2, out[3] == nil,
        vim.deep_equal(out[4], { 4 }),
        type(out[5]) == 'function',
        vim.tbl_count(out),
      }
    ]]
    eq({ true, true, true, true, true, 4 }, out_verify)
  end)

  it('can return values by reference', function()
    local out = exec_lua [[
      local val = { 4, 10 }
      local ref = vim._with({}, function() return val end)
      ref[1] = 7
      return val
    ]]
    eq({ 7, 10 }, out)
  end)

  it('can not work with conflicting `buf` and `win`', function()
    local out = exec_lua [[
      local other_buf, cur_buf = setup_buffers()
      local other_win, cur_win = setup_windows()
      assert(api.nvim_win_get_buf(other_win) ~= other_buf)
      local _, err = pcall(vim._with, { buf = other_buf, win = other_win }, function() end)
      return err
    ]]
    matches('Can not set both `buf` and `win`', out)
  end)

  it('works with several contexts at once', function()
    local out = exec_lua [[
      local other_buf, cur_buf = setup_buffers()
      vim.bo[other_buf].commentstring = '## %s'
      api.nvim_buf_set_lines(other_buf, 0, -1, false, { 'aaa', 'bbb', 'ccc' })
      api.nvim_buf_set_mark(other_buf, 'm', 2, 2, {})

      vim.go.commentstring = '// %s'
      vim.go.langmap = 'xy,yx'

      local context = {
        buf = other_buf,
        bo = { commentstring = '-- %s' },
        go = { langmap = 'ab,ba' },
        lockmarks = true,
      }

      local inner = vim._with(context, function()
        api.nvim_buf_set_lines(0, 0, -1, false, { 'uuu', 'vvv', 'www' })
        return {
          buf = api.nvim_get_current_buf(),
          bo = { cms = vim.bo.commentstring },
          go = { cms = vim.go.commentstring, lmap = vim.go.langmap },
          mark = api.nvim_buf_get_mark(0, 'm')
        }
      end)

      local after = {
        buf = api.nvim_get_current_buf(),
        bo = { cms = vim.bo[other_buf].commentstring },
        go = { cms = vim.go.commentstring, lmap = vim.go.langmap },
        mark = api.nvim_buf_get_mark(other_buf, 'm')
      }

      return {
        context_buf = other_buf, cur_buf = cur_buf,
        inner = inner, after = after
      }
    ]]

    eq({
      buf = out.context_buf,
      bo = { cms = '-- %s' },
      go = { cms = '// %s', lmap = 'ab,ba' },
      mark = { 2, 2 },
    }, out.inner)
    eq({
      buf = out.cur_buf,
      bo = { cms = '## %s' },
      go = { cms = '// %s', lmap = 'xy,yx' },
      mark = { 2, 2 },
    }, out.after)
  end)

  it('works with same option set in different contexts', function()
    local out = exec_lua [[
      local get_state = function()
        return {
          bo = { cms = vim.bo.commentstring },
          wo = { ve = vim.wo.virtualedit },
          go = { cms = vim.go.commentstring, ve = vim.go.virtualedit },
        }
      end

      vim.bo.commentstring = '// %s'
      vim.go.commentstring = '$$ %s'
      vim.wo.virtualedit = 'insert'
      vim.go.virtualedit = 'none'

      local before = get_state()
      local context_no_go = {
        o = { commentstring = '-- %s', virtualedit = 'all' },
        bo = { commentstring = '!! %s' },
        wo = { virtualedit = 'onemore' },
      }
      local inner_no_go = vim._with(context_no_go, get_state)
      local middle = get_state()
      local context_with_go = {
        o = { commentstring = '-- %s', virtualedit = 'all' },
        bo = { commentstring = '!! %s' },
        wo = { virtualedit = 'onemore' },
        go = { commentstring = '@@ %s', virtualedit = 'block' },
      }
      local inner_with_go = vim._with(context_with_go, get_state)
      return {
        before = before,
        inner_no_go = inner_no_go,
        middle = middle,
        inner_with_go = inner_with_go,
        after = get_state(),
      }
    ]]

    -- Should prefer explicit local scopes instead of `o`
    eq({
      bo = { cms = '!! %s' },
      wo = { ve = 'onemore' },
      go = { cms = '-- %s', ve = 'all' },
    }, out.inner_no_go)
    eq(out.before, out.middle)

    -- Should prefer explicit global scopes instead of `o`
    eq({
      bo = { cms = '!! %s' },
      wo = { ve = 'onemore' },
      go = { cms = '@@ %s', ve = 'block' },
    }, out.inner_with_go)
    eq(out.middle, out.after)
  end)

  pending('can forward command modifiers to user command', function()
    local out = exec_lua [[
      local test_flags = {
        'emsg_silent',
        'hide',
        'keepalt',
        'keepjumps',
        'keepmarks',
        'keeppatterns',
        'lockmarks',
        'noautocmd',
        'silent',
        'unsilent',
      }

      local used_smods
      local command = function(data)
        used_smods = data.smods
      end
      api.nvim_create_user_command('DummyLog', command, {})

      local res = {}
      for _, flag in ipairs(test_flags) do
        used_smods = nil
        vim._with({ [flag] = true }, function() vim.cmd('DummyLog') end)
        res[flag] = used_smods[flag]
      end
      return res
    ]]
    for k, v in pairs(out) do
      eq({ k, true }, { k, v })
    end
  end)

  it('handles error in callback', function()
    -- Should still restore initial context
    local out_buf = exec_lua [[
      local other_buf, cur_buf = setup_buffers()
      vim.bo[other_buf].commentstring = '## %s'

      local context = { buf = other_buf, bo = { commentstring = '-- %s' } }
      local ok, err = pcall(vim._with, context, function() error('Oops buf', 0) end)

      return {
        ok,
        err,
        api.nvim_get_current_buf() == cur_buf,
        vim.bo[other_buf].commentstring,
      }
    ]]
    eq({ false, 'Oops buf', true, '## %s' }, out_buf)

    local out_win = exec_lua [[
      local other_win, cur_win = setup_windows()
      vim.wo[other_win].winblend = 25

      local context = { win = other_win, wo = { winblend = 50 } }
      local ok, err = pcall(vim._with, context, function() error('Oops win', 0) end)

      return {
        ok,
        err,
        api.nvim_get_current_win() == cur_win,
        vim.wo[other_win].winblend,
      }
    ]]
    eq({ false, 'Oops win', true, 25 }, out_win)
  end)

  it('handles not supported option', function()
    local out = exec_lua [[
      -- Should still restore initial state
      vim.bo.commentstring = '## %s'

      local context = { o = { commentstring = '-- %s' }, bo = { winblend = 10 } }
      local ok, err = pcall(vim._with, context, function() end)

      return { ok = ok, err = err, cms = vim.bo.commentstring }
    ]]
    eq(false, out.ok)
    matches('window.*option.*winblend', out.err)
    eq('## %s', out.cms)
  end)

  it('validates arguments', function()
    exec_lua [[
      _G.get_error = function(...)
        local _, err = pcall(vim._with, ...)
        return err or ''
      end
    ]]
    local get_error = function(string_args)
      return exec_lua('return get_error(' .. string_args .. ')')
    end

    matches('context.*table', get_error("'a', function() end"))
    matches('f.*function', get_error('{}, 1'))

    local assert_context = function(bad_context, expected_type)
      local bad_field = vim.tbl_keys(bad_context)[1]
      matches(
        'context%.' .. bad_field .. '.*' .. expected_type,
        get_error(vim.inspect(bad_context) .. ', function() end')
      )
    end

    assert_context({ bo = 1 }, 'table')
    assert_context({ buf = 'a' }, 'number')
    assert_context({ emsg_silent = 1 }, 'boolean')
    assert_context({ env = 1 }, 'table')
    assert_context({ go = 1 }, 'table')
    assert_context({ hide = 1 }, 'boolean')
    assert_context({ keepalt = 1 }, 'boolean')
    assert_context({ keepjumps = 1 }, 'boolean')
    assert_context({ keepmarks = 1 }, 'boolean')
    assert_context({ keeppatterns = 1 }, 'boolean')
    assert_context({ lockmarks = 1 }, 'boolean')
    assert_context({ noautocmd = 1 }, 'boolean')
    assert_context({ o = 1 }, 'table')
    assert_context({ sandbox = 1 }, 'boolean')
    assert_context({ silent = 1 }, 'boolean')
    assert_context({ unsilent = 1 }, 'boolean')
    assert_context({ win = 'a' }, 'number')
    assert_context({ wo = 1 }, 'table')

    matches('Invalid buffer', get_error('{ buf = -1 }, function() end'))
    matches('Invalid window', get_error('{ win = -1 }, function() end'))
  end)

  it('no double-free when called from :filter browse oldfiles #31501', function()
    exec_lua([=[
      vim.api.nvim_create_autocmd('BufEnter', {
        callback = function()
          vim._with({ lockmarks = true }, function() end)
        end,
      })
      vim.cmd([[
        let v:oldfiles = ['Xoldfile']
        call nvim_input('1<CR>')
        noswapfile filter /Xoldfile/ browse oldfiles
      ]])
    ]=])
    n.assert_alive()
    eq('Xoldfile', fn.bufname('%'))
  end)
end)
