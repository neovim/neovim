-- Specs for :cd, :tcd, :lcd and getcwd()

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local eq = t.eq
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

-- Shorthand writing to get the current working directory
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
        -- From new tab page, original window reports global dir
        eq(globalDir, cwd(globalwin, tabnr))
        eq(0, lwd(globalwin, tabnr))

        -- From new tab page, local window reports as such
        eq(globalDir .. pathsep .. directories.window, cwd(localwin, tabnr))
        eq(1, lwd(localwin, tabnr))
      end)

      it('for tab page', function()
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

        -- From local tab page, original tab reports globalDir
        eq(globalDir, cwd(-1, globaltab))
        eq(0, lwd(-1, globaltab))

        -- new tab reports local
        eq(globalDir .. pathsep .. directories.tab, cwd(-1, 0))
        eq(globalDir .. pathsep .. directories.tab, cwd(-1, localtab))
        eq(1, lwd(-1, 0))
        eq(1, lwd(-1, localtab))

        command('tabnext')
        -- From original tab page, local reports as such
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

        -- getcwd({winnr}) falls through to the buffer shown in that window, not the current
        -- buffer.
        command(('split %s%s%s2'):format(directories.buffer, pathsep, tmpfile))
        command('wincmd p')
        eq(globalDir, cwd())
        eq(join(globalDir, directories.buffer), cwd(1))
        eq(globalDir, cwd(2))
      end)
    end)

    describe('getcwd(-1, -1)', function()
      it('works', function()
        eq(startdir, cwd(-1, -1))
        eq(0, lwd(-1, -1))
      end)

      it('works with tab-local pwd', function()
        command('silent t' .. cmd .. ' ' .. directories.tab)
        eq(startdir, cwd(-1, -1))
        eq(0, lwd(-1, -1))
      end)

      it('works with window-local pwd', function()
        command('silent l' .. cmd .. ' ' .. directories.window)
        eq(startdir, cwd(-1, -1))
        eq(0, lwd(-1, -1))
      end)

      it('works with buffer-local pwd', function()
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
      eq(cwd(), bcwd()) -- Still no buffer-directory
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
      eq(cwd(), wcwd()) -- Still no window-directory
      eq(0, wlwd())

      -- Change window-local directory to test `:lcd`
      command(('silent l%s ../%s'):format(cmd, directories.window))
      eq(join(globalDir, directories.window), cwd())
      eq(join(globalDir, directories.buffer), bcwd())
      eq(1, blwd())

      -- Verify buffer has buffer-local directory in original window
      command('wincmd w')
      command('b ' .. tmpfile)
      eq(join(globalDir, directories.buffer), cwd())

      -- Verify going to second window uses window-local directory
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
    end)
  end)
end

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

    -- :tcd via nvim_buf_call() persists, and the tab scope claims the new cwd.
    cd_in_buf_call(hidden, 'tcd', tabdir)
    eq({ 1, tabdir, tabdir }, { tlwd(), tcwd(), cwd() })
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
      local err5001 = 'Vim:E5001: Higher scope cannot be -1 if lower scope is >= 0.'
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
