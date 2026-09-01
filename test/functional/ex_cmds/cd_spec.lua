-- Specs for :cd, :tcd, :lcd and getcwd()

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local eq = t.eq
local neq = t.neq
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err
local call = n.call
local clear = n.clear
local command = n.command
local pathsep = n.get_pathsep()
local skip = t.skip
local is_os = t.is_os
local mkdir = t.mkdir

-- These directories will be created for testing
local directories = {
  tab = 'Xtest-functional-ex_cmds-cd_spec.tab', -- Tab
  window = 'Xtest-functional-ex_cmds-cd_spec.window', -- Window
  buffer = 'Xtest-functional-ex_cmds-cd_spec.buffer', -- Buffer
  global = 'Xtest-functional-ex_cmds-cd_spec.global', -- New global
}

local tmpfile = 'Xtest-functional-ex_cmds-cd_spec-tmpfile'
local startdir ---@type string `getcwd()` at session start (set by `before_each`)

local function join(...)
  return table.concat({ ... }, pathsep)
end

-- Get the current working directory.
local cwd = function(...)
  return call('getcwd', ...)
end -- effective working dir
local wcwd = function()
  return cwd(0)
end -- window dir
local bcwd = function()
  return cwd(-1, -1, 0)
end -- buffer dir
local tcwd = function()
  return cwd(-1, 0)
end -- tab dir

-- Same, except these tell us if there is a working directory at all
local lwd = function(...)
  return call('haslocaldir', ...)
end -- effective working dir
local wlwd = function()
  return lwd(0)
end -- window dir
local blwd = function()
  return lwd(-1, -1, 0)
end -- buffer dir
local tlwd = function()
  return lwd(-1, 0)
end -- tab dir
--local glwd = function() return eval('haslocaldir(-1, -1)') end  -- global dir

before_each(function()
  clear()
  for _, d in pairs(directories) do
    mkdir(d)
  end
  startdir = cwd()
end)

after_each(function()
  for _, d in pairs(directories) do
    n.rmdir(d)
  end
end)

-- Test both the `cd` and `chdir` variants
for _, cmd in ipairs { 'cd', 'chdir' } do
  describe(':' .. cmd, function()
    describe('using explicit scope', function()
      it('for window', function()
        local globalDir = startdir
        local globalwin = call('winnr')
        local tabnr = call('tabpagenr')

        -- Everything matches globalDir to start
        eq(globalDir, cwd(globalwin))
        eq(globalDir, cwd(globalwin, tabnr))
        eq(0, lwd(globalwin))
        eq(0, lwd(globalwin, tabnr))

        command('bot split')
        local localwin = call('winnr')
        -- Initial window is still using globalDir
        eq(globalDir, cwd(localwin))
        eq(globalDir, cwd(localwin, tabnr))
        eq(0, lwd(globalwin))
        eq(0, lwd(globalwin, tabnr))

        command('silent l' .. cmd .. ' ' .. directories.window)
        -- From window with local dir, the original window
        -- is still reporting the global dir
        eq(globalDir, cwd(globalwin))
        eq(globalDir, cwd(globalwin, tabnr))
        eq(0, lwd(globalwin))
        eq(0, lwd(globalwin, tabnr))

        -- Window with local dir reports as such
        eq(globalDir .. pathsep .. directories.window, cwd(localwin))
        eq(globalDir .. pathsep .. directories.window, cwd(localwin, tabnr))
        eq(1, lwd(localwin))
        eq(1, lwd(localwin, tabnr))

        command('tabnew')
        -- From new tabpage, original window reports global dir
        eq(globalDir, cwd(globalwin, tabnr))
        eq(0, lwd(globalwin, tabnr))

        -- From new tabpage, local window reports as such
        eq(globalDir .. pathsep .. directories.window, cwd(localwin, tabnr))
        eq(1, lwd(localwin, tabnr))
      end)

      it('for tabpage', function()
        local globalDir = startdir
        local globaltab = call('tabpagenr')

        -- Everything matches globalDir to start
        eq(globalDir, cwd(-1, 0))
        eq(globalDir, cwd(-1, globaltab))
        eq(0, lwd(-1, 0))
        eq(0, lwd(-1, globaltab))

        command('tabnew')
        command('silent t' .. cmd .. ' ' .. directories.tab)
        local localtab = call('tabpagenr')

        -- From local tabpage, original tab reports globalDir
        eq(globalDir, cwd(-1, globaltab))
        eq(0, lwd(-1, globaltab))

        -- new tab reports local
        eq(globalDir .. pathsep .. directories.tab, cwd(-1, 0))
        eq(globalDir .. pathsep .. directories.tab, cwd(-1, localtab))
        eq(1, lwd(-1, 0))
        eq(1, lwd(-1, localtab))

        command('tabnext')
        -- From original tabpage, local reports as such
        eq(globalDir .. pathsep .. directories.tab, cwd(-1, localtab))
        eq(1, lwd(-1, localtab))
      end)

      it('for buffer', function()
        local globalDir = startdir
        -- Create two buffers
        command(('e %s1'):format(tmpfile))
        command(('e %s%s%s2'):format(directories.buffer, pathsep, tmpfile))

        -- Initially matches globalDir
        eq(globalDir, cwd())
        eq(0, lwd())

        -- Change buffer-local directory to subdirectory
        command('bcd ' .. directories.buffer)
        eq(join(globalDir, directories.buffer), cwd())
        eq(1, blwd())

        -- ":bcd -" changes to the previous directory, still buffer-scoped.
        command('bcd -')
        eq(globalDir, cwd())
        eq(1, blwd())
        command('bcd -')
        eq(join(globalDir, directories.buffer), cwd())
        eq(1, blwd())

        -- Verify Other buffer is unchanged
        command('b# ')
        eq(globalDir, cwd())
        eq(0, blwd())

        -- A new buffer created with :edit does not inherit the buffer-local directory.
        command('b# ')
        command(('e %s3'):format(tmpfile))
        eq(0, blwd())
        eq(globalDir, cwd())

        -- getcwd({winnr}) reports the window's own scope chain: the buffer scope is separate, and
        -- visible only via the {bufnr} form.
        command(('split %s%s%s2'):format(directories.buffer, pathsep, tmpfile))
        local bufnr = call('winbufnr', 1)
        command('wincmd p')
        eq(globalDir, cwd())
        eq({ globalDir, globalDir }, { cwd(1), cwd(2) })
        eq(join(globalDir, directories.buffer), cwd(-1, -1, bufnr))

        -- The {bufnr} form skips window and tab: a buffer belongs to no particular window/tabpage.
        command('lcd ' .. directories.window)
        command('tcd ' .. join('..', directories.tab))
        eq(
          { join(globalDir, directories.tab), join(globalDir, directories.tab) },
          { cwd(0), tcwd() }
        )
        eq(globalDir, cwd(-1, -1, 0))
      end)
    end)

    describe('getcwd(-1, -1)', function()
      it('works', function()
        eq(startdir, cwd(-1, -1))
        eq(0, lwd(-1, -1))
      end)

      it('with tab-local dir', function()
        command('silent t' .. cmd .. ' ' .. directories.tab)
        eq(startdir, cwd(-1, -1))
        eq(0, lwd(-1, -1))
      end)

      it('with window-local dir', function()
        command('silent l' .. cmd .. ' ' .. directories.window)
        eq(startdir, cwd(-1, -1))
        eq(0, lwd(-1, -1))
      end)

      it('with buffer-local dir', function()
        command(('silent b%s %s'):format(cmd, directories.buffer))
        eq(startdir, cwd(-1, -1))
        eq(0, lwd(-1, -1))

        -- Must behave the same if bufnr is -1
        eq(startdir, cwd(-1, -1, -1))
        eq(0, lwd(-1, -1, -1))
      end)
    end)

    describe('Local directory gets inherited', function()
      it('by tabs', function()
        local globalDir = startdir

        -- Create a new tab and change directory
        command('tabnew')
        command('silent t' .. cmd .. ' ' .. directories.tab)
        eq(globalDir .. pathsep .. directories.tab, tcwd())

        -- Create a new tab and verify it has inherited the directory
        command('tabnew')
        eq(globalDir .. pathsep .. directories.tab, tcwd())

        -- Change tab and change back, verify that directories are correct
        command('tabnext')
        eq(globalDir, tcwd())
        command('tabprevious')
        eq(globalDir .. pathsep .. directories.tab, tcwd())
      end)
    end)

    it('works', function()
      local globalDir = startdir
      -- Create a new tab first and verify that is has the same working dir
      command('tabnew')
      eq(globalDir, cwd())
      eq(globalDir, tcwd()) -- has no tab-local directory
      eq(0, tlwd())
      eq(globalDir, wcwd()) -- has no window-local directory
      eq(0, wlwd())

      -- Change tab-local working directory and verify it is different
      command('silent t' .. cmd .. ' ' .. directories.tab)
      eq(globalDir .. pathsep .. directories.tab, cwd())
      eq(cwd(), tcwd()) -- working directory matches tab directory
      eq(1, tlwd())
      eq(cwd(), wcwd()) -- still no window-directory
      eq(0, wlwd())

      -- Create a new window in this tab to test `:lcd`
      command('new')
      eq(1, tlwd()) -- Still tab-local working directory
      eq(0, wlwd()) -- Still no window-local working directory
      eq(globalDir .. pathsep .. directories.tab, cwd())
      command('silent l' .. cmd .. ' ../' .. directories.window)
      eq(globalDir .. pathsep .. directories.window, cwd())
      eq(globalDir .. pathsep .. directories.tab, tcwd())
      eq(1, wlwd())

      -- Verify the first window still has the tab local directory
      command('wincmd w')
      eq(globalDir .. pathsep .. directories.tab, cwd())
      eq(globalDir .. pathsep .. directories.tab, tcwd())
      eq(0, wlwd()) -- No window-local directory

      -- Change back to initial tab and verify working directory has stayed
      command('tabnext')
      eq(globalDir, cwd())
      eq(0, tlwd())
      eq(0, wlwd())

      -- Verify global changes don't affect local ones
      command('silent ' .. cmd .. ' ' .. directories.global)
      eq(globalDir .. pathsep .. directories.global, cwd())
      command('tabnext')
      eq(globalDir .. pathsep .. directories.tab, cwd())
      eq(globalDir .. pathsep .. directories.tab, tcwd())
      eq(0, wlwd()) -- Still no window-local directory in this window

      -- Unless the global change happened in a tab with local directory
      command('silent ' .. cmd .. ' ..')
      eq(globalDir, cwd())
      eq(0, tlwd())
      eq(0, wlwd())
      -- Which also affects the first tab
      command('tabnext')
      eq(globalDir, cwd())

      -- But not in a window with its own local directory
      command('tabnext | wincmd w')
      eq(globalDir .. pathsep .. directories.window, cwd())
      eq(0, tlwd())
      eq(globalDir .. pathsep .. directories.window, wcwd())
    end)

    it('works when mixing tab-local and buffer-local directories', function()
      local globalDir = startdir

      -- Create two buffers for testing. One in each tab
      command(('e %s1'):format(tmpfile))
      command('tabnew')
      command(('e %s2'):format(tmpfile))

      -- Verify that buffer 2 has the same working directory
      eq(globalDir, cwd())
      eq(globalDir, tcwd()) -- Has no tab-local directory
      eq(0, tlwd())
      eq(globalDir, bcwd()) -- Has no buffer-local directory
      eq(0, blwd())

      -- Change tab-local working directory and verify it is different
      command(('silent t%s %s'):format(cmd, directories.tab))
      eq(join(globalDir, directories.tab), cwd())
      eq(cwd(), tcwd()) -- Working directory matches tab directory
      eq(1, tlwd())
      eq(globalDir, bcwd()) -- Still no buffer-directory: the buffer form skips the tab scope
      eq(0, blwd())

      -- Change buffer 2's buffer-local directory
      command(('silent b%s ..%s%s'):format(cmd, pathsep, directories.buffer))
      eq(join(globalDir, directories.buffer), cwd())
      eq(join(globalDir, directories.tab), tcwd())
      eq(cwd(), bcwd()) -- Has no buffer-directory
      eq(1, blwd())

      -- Verify the first tab has no local-directory
      command('tabfirst')
      eq(0, tlwd())

      -- Verify buffer 2 has buffer-local directory even in first tab
      command(('b %s2'):format(tmpfile)) -- Switch to buffer 2
      eq(join(globalDir, directories.buffer), bcwd())
      eq(0, tlwd()) -- Still no tab-local directory

      -- Verify buffer 1 did not have its directory changed
      command('b#') -- Switch to buffer 1
      eq(globalDir, cwd())
      eq(0, blwd()) -- No window-buffer directory
    end)
    it('works when mixing window local and buffer local directories', function()
      local globalDir = startdir
      -- Create a new window first and verify that is has the same working directory
      command('new')
      eq(globalDir, cwd())
      eq(globalDir, wcwd()) -- Has no window-local directory
      eq(0, tlwd())
      eq(globalDir, bcwd()) -- Has no buffer-local directory
      eq(0, blwd())

      -- Create a buffer in current window
      command('e ' .. tmpfile)

      -- Change buffer-local working directory and verify it is different
      command(('silent b%s %s'):format(cmd, directories.buffer))
      eq(join(globalDir, directories.buffer), cwd())
      eq(cwd(), bcwd()) -- Working directory matches buffer directory
      eq(1, blwd())
      eq(globalDir, wcwd()) -- Still no window-directory
      eq(0, wlwd())

      -- :lcd sets the window-local dir WITHOUT clearing the narrower buffer-local one.
      command(('silent l%s ../%s'):format(cmd, directories.window))
      eq(join(globalDir, directories.buffer), cwd())
      eq({ 1, 1 }, { blwd(), wlwd() })
      eq(join(globalDir, directories.window), wcwd())

      -- Window-local dir applies if the buffer-local one is unset.
      command(('silent b%s!'):format(cmd))
      eq(0, blwd())
      eq(join(globalDir, directories.window), cwd())

      -- Verify other window is unaffected.
      command('wincmd w')
      command('b ' .. tmpfile)
      eq(globalDir, cwd())
      command('wincmd w')
      eq(join(globalDir, directories.window), cwd())
    end)
  end)
end

for _, cmd in ipairs { 'bcd', 'bchdir' } do
  describe(':' .. cmd, function()
    it('works after deleting the only buffer', function()
      command(('%s %s'):format(cmd, directories.buffer))
      command('bd') -- delete buffer
    end)

    it('buffer-local directory is NOT sticky/inherited', function()
      local bufdir = join(startdir, directories.buffer)

      command('edit ' .. tmpfile)
      command(('%s %s'):format(cmd, directories.buffer))
      eq(bufdir, cwd())

      -- A new buffer starts without a buffer-local directory.
      command('new')
      eq(startdir, cwd())
      eq(0, blwd())
      command('close')
      eq(bufdir, cwd())
      command('enew')
      eq(startdir, cwd())
      eq(0, blwd())
      command('b# ')
      eq(bufdir, cwd())

      -- Recycling an empty unnamed buffer (:edit) drops its directory with it.
      command('enew')
      command(('%s %s'):format(cmd, directories.buffer))
      eq(bufdir, cwd())
      command('edit ' .. tmpfile .. '2')
      eq(startdir, cwd())
      eq(0, blwd())

      -- But re-editing the same buffer keeps it, like any other buffer-local state. #41213
      command(('%s %s'):format(cmd, directories.buffer))
      command('let b:kept = 1')
      command('edit!')
      eq({ 1, bufdir, 1 }, { blwd(), cwd(), n.eval('get(b:, "kept", 0)') })
    end)

    it('is not cleared or overridden by :lcd/:tcd/:cd', function()
      local bufdir = join(startdir, directories.buffer)

      command('edit ' .. tmpfile)
      command(('%s %s'):format(cmd, directories.buffer))
      -- Paths are relative to `bufdir`, which stays in effect throughout.
      command('lcd ' .. join('..', directories.window))
      eq({ 1, bufdir, join(startdir, directories.window) }, { blwd(), cwd(), wcwd() })

      command('tcd ' .. join('..', directories.tab))
      eq({ 1, bufdir, join(startdir, directories.tab) }, { blwd(), cwd(), tcwd() })

      command('cd ..')
      eq({ 1, bufdir, startdir }, { blwd(), cwd(), cwd(-1, -1) })

      -- The overridden ":cd" still reset the window/tab scopes, so ":bcd!" lands on the global dir.
      command(('%s!'):format(cmd))
      eq({ 0, 0, 0, startdir }, { blwd(), wlwd(), tlwd(), cwd() })
    end)
  end)
end

describe(':lcd!/:tcd!/:bcd! (bang)', function()
  it('clear only their own scope', function()
    local bufdir = join(startdir, directories.buffer)
    local windir = join(startdir, directories.window)
    local tabdir = join(startdir, directories.tab)

    command('tcd ' .. directories.tab)
    command('lcd ' .. join('..', directories.window))
    command('bcd ' .. join('..', directories.buffer))
    eq({ 1, 1, 1 }, { blwd(), wlwd(), tlwd() })
    eq(bufdir, cwd())

    command('bcd!') -- Buffer scope gone: the window-local dir applies.
    eq({ 0, 1, 1 }, { blwd(), wlwd(), tlwd() })
    eq(windir, cwd())

    command('lcd!') -- Window scope gone: the tab-local dir applies.
    eq({ 0, 0, 1 }, { blwd(), wlwd(), tlwd() })
    eq(tabdir, cwd())

    command('tcd!') -- Tab scope gone: back to the global dir.
    eq({ 0, 0, 0 }, { blwd(), wlwd(), tlwd() })
    eq(startdir, cwd())

    command('lcd!') -- No-op when the scope has no local directory.
    eq(startdir, cwd())

    -- :cd! does not unset.
    command('lcd ' .. directories.window)
    command('cd! ' .. join('..', directories.global))
    eq(join(startdir, directories.global), cwd())
    eq(0, wlwd()) -- ":cd" cleared it, as always.

    -- Legacy: bang WITH arg ":lcd! {path}" is just ":lcd {path}".
    command('lcd! ' .. join('..', directories.window))
    eq({ 1, join(startdir, directories.window) }, { wlwd(), cwd() })
  end)
end)

describe('cd during temp context-switch', function()
  it(':bcd/:tcd/:lcd persists in target scope, does not leak into original context', function()
    local exec_lua = n.exec_lua
    local bufdir = join(startdir, directories.buffer)
    local windir = join(startdir, directories.window)
    local tabdir = join(startdir, directories.tab)

    --- Creates a loaded, hidden buffer.
    local function hidden_buf(name)
      local b = call('bufadd', name)
      call('bufload', b)
      return b
    end

    --- Runs `vim.cmd[cmd](dir)` with buffer `b` as temporary curbuf.
    local function cd_in_buf_call(b, cmd, dir)
      exec_lua(function(b_, cmd_, d)
        vim.api.nvim_buf_call(b_, function()
          vim.cmd[cmd_](d)
        end)
      end, b, cmd, dir)
    end

    -- :bcd on a hidden buffer via nvim_buf_call() persists; the caller's cwd is unchanged.
    local hidden = hidden_buf('Xtest-cd-hidden')
    cd_in_buf_call(hidden, 'bcd', bufdir)
    eq({ 1, bufdir, startdir }, { lwd(-1, -1, hidden), cwd(-1, -1, hidden), cwd() })

    -- :lcd targets the temporary window, which is discarded; the caller's cwd is unchanged.
    cd_in_buf_call(hidden, 'lcd', windir)
    eq({ 0, startdir }, { wlwd(), cwd() })

    -- :lcd via win_execute() persists on the target window; the CWD outside it is unchanged.
    command('split')
    call('win_execute', call('win_getid', 2), ('lcd %s'):format(windir))
    eq({ 1, windir, startdir }, { lwd(2), cwd(2), cwd() })
    command('only')

    -- Entering a hidden buffer must not consume the global dir.
    command('lcd ' .. windir)
    exec_lua(function(b)
      vim.api.nvim_buf_call(b, function() end)
    end, hidden)
    eq({ windir, startdir }, { cwd(), cwd(-1, -1) })
    command('lcd!')

    -- An autocmd handler targeting a hidden buffer can set its buffer-local dir; the caller's
    -- cwd is unchanged.
    local hidden2 = hidden_buf('Xtest-cd-hidden2')
    exec_lua(function(b, d)
      vim.api.nvim_create_autocmd('TermRequest', {
        buffer = b,
        once = true,
        callback = function()
          vim.cmd.bcd(d)
        end,
      })
      vim.api.nvim_exec_autocmds('TermRequest', { buffer = b, data = { sequence = 'x' } })
    end, hidden2, bufdir)
    eq({ 1, bufdir, startdir }, { lwd(-1, -1, hidden2), cwd(-1, -1, hidden2), cwd() })

    -- :tcd targets the tabpage, shared with the temp context: it persists and changes the caller's
    -- cwd. `globaldir` (the pre-switch cwd, set by :tcd) is kept, so :tcd! can return to it.
    cd_in_buf_call(hidden, 'tcd', tabdir)
    eq({ 1, tabdir, tabdir, startdir }, { tlwd(), tcwd(), cwd(), cwd(-1, -1) })
  end)

  it('buffer names/statusline updated after switch back #41424', function()
    local screen = Screen.new(40, 8)
    local bufdir = join(startdir, directories.buffer)
    command('edit ' .. join(bufdir, tmpfile))
    command('bcd ' .. bufdir)
    command('split Xtest-cd-other') -- Buffer with no local dir.
    local otherwin = call('win_getid')
    command('wincmd p')
    eq({ bufdir, tmpfile }, { cwd(), call('bufname', '%') })

    -- 'statusline' shows buffer names, so it must be redrawn exactly when they change.
    exec_lua([[
      _G.evals = 0
      function _G.stl()
        _G.evals = _G.evals + 1
        return 'STL'
      end
      vim.o.laststatus = 2
      vim.o.statusline = '%!v:lua.stl()'
    ]])
    screen:expect({ any = 'STL' })

    -- Entering a window leaves `bufdir`, since the buffer there has no local dir.
    exec_lua(
      [[
      vim._with({ win = ... }, function()
        vim.cmd('split | close')
        vim.api.nvim__redraw({ flush = true }) -- Paints the names relative to the other CWD.
        _G.inner = _G.evals
      end)
      vim.api.nvim__redraw({ flush = true })
    ]],
      otherwin
    )

    -- Names relative to the old CWD would cause ":write" to target nonsense.
    eq({ bufdir, tmpfile }, { cwd(), call('bufname', '%') })
    command('write')

    -- The switch moved the CWD, so the names changed and back: 'statusline' follows them.
    neq(exec_lua('return _G.inner'), exec_lua('return _G.evals'))

    -- Without a local dir the switch doesn't move the CWD, so nothing needs a redraw. #41561
    command('bcd!')
    exec_lua('vim.api.nvim__redraw({ flush = true })')
    local evals = exec_lua('return _G.evals')
    call('win_execute', otherwin, 'let g:x = 1')
    exec_lua('vim.api.nvim__redraw({ flush = true })')
    eq(evals, exec_lua('return _G.evals'))
  end)

  it("nvim_open_win / nvim_win_set_buf keep the caller's cwd", function()
    local bufdir = join(startdir, directories.buffer)
    command('bcd ' .. bufdir)
    eq(bufdir, cwd())

    -- A transient switch to a scratch float must not reset the caller's cwd.
    local float = call('nvim_open_win', call('nvim_create_buf', true, true), false, {
      relative = 'editor',
      width = 20,
      height = 5,
      row = 1,
      col = 1,
    })
    eq(bufdir, cwd())

    call('nvim_win_set_buf', float, call('nvim_create_buf', true, true))
    eq(bufdir, cwd())

    call('nvim_win_close', float, true)
    eq(bufdir, cwd())
    command('bcd!')

    -- Switching to a window with no local dir must not consume the global dir. #41238
    local windir = join(startdir, directories.window)
    command('split')
    command('lcd ' .. windir)
    call('nvim_win_set_buf', call('win_getid', 2), call('nvim_create_buf', true, true))
    eq({ windir, startdir }, { cwd(), cwd(-1, -1) })
    command('wincmd w')
    eq({ startdir, startdir }, { cwd(), cwd(-1, -1) })
    command('only')

    -- Setting a :bcd buffer into another window, should not modify the caller's CWD.
    local bcdbuf = call('nvim_create_buf', true, true)
    n.exec_lua(function(b, d)
      vim.api.nvim_buf_call(b, function()
        vim.cmd.bcd(d)
      end)
    end, bcdbuf, bufdir)
    command('split')
    call('nvim_win_set_buf', call('win_getid', 2), bcdbuf)
    eq({ bufdir, startdir, startdir }, { cwd(-1, -1, bcdbuf), cwd(), cwd(-1, -1) })
    command('only')
  end)
end)

-- Test legal parameters for 'getcwd' and 'haslocaldir'
for _, cmd in ipairs { 'getcwd', 'haslocaldir' } do
  describe(cmd .. '()', function()
    it('validation', function()
      local err474 = 'Vim:E474: Invalid argument'
      eq(err474, pcall_err(call, cmd, 'some string'))
      eq(err474, pcall_err(call, cmd, 1.5))
      eq(err474, pcall_err(call, cmd, { 1, 2 }))
      eq(err474, pcall_err(call, cmd, { key = 'value' }))
      eq(err474, pcall_err(call, cmd, -2))
      -- Funcref is not representable over RPC.
      eq(
        'Vim(call):E474: Invalid argument',
        pcall_err(command, ('call %s(function("tr"))'):format(cmd))
      )

      -- -1 preceded by an argument >= 0
      local err5001 = 'Vim:E5001: Argument cannot be -1 if preceding argument is >= 0.'
      eq(err5001, pcall_err(call, cmd, 0, -1))
      eq(err5001, pcall_err(call, cmd, 2, 3, -1))
      eq(err5001, pcall_err(call, cmd, -1, 0, -1))
      eq(err5001, pcall_err(call, cmd, 0, -1, 0))
      -- Buffer scope requires window and tab args to be -1.
      local err5006 = 'Vim:E5006: Window and tab scope must be -1 when using buffer scope'
      eq(err5006, pcall_err(call, cmd, 0, 0, 0))
      eq(err5006, pcall_err(call, cmd, 1, 2, 3))
      eq('Vim:E5007: Cannot find buffer number.', pcall_err(call, cmd, -1, -1, 99999))
      eq(
        ('Vim:E118: Too many arguments for function: %s'):format(cmd),
        pcall_err(call, cmd, 0, 0, 0, 0)
      )
    end)
  end)
end

describe('getcwd()', function()
  it('returns empty string if working directory does not exist', function()
    skip(is_os('win'), 'N/A for Windows')
    command('cd ' .. directories.global)
    command("call delete('../" .. directories.global .. "', 'd')")
    eq('', n.eval('getcwd()'))
  end)

  it("works with 'autochdir' after local directory was set (#9892)", function()
    local curdir = cwd()
    command('lcd ' .. directories.global)
    command('lcd -')
    command('set autochdir')
    command('edit ' .. directories.global .. '/foo')
    eq(curdir .. pathsep .. directories.global, cwd())
    eq(curdir, wcwd())
    call('mkdir', 'bar')
    command('edit ' .. 'bar/foo')
    eq(curdir .. pathsep .. directories.global .. pathsep .. 'bar', cwd())
    eq(curdir, wcwd())
    command('lcd ..')
    eq(curdir .. pathsep .. directories.global, cwd())
    eq(curdir .. pathsep .. directories.global, wcwd())
    command('edit')
    eq(curdir .. pathsep .. directories.global .. pathsep .. 'bar', cwd())
    eq(curdir .. pathsep .. directories.global, wcwd())
  end)
end)
