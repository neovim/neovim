-- Specs for :cd, :tcd, :lcd and getcwd()

local lfs = require('lfs')
local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local call = helpers.call
local clear = helpers.clear
local execute = helpers.execute
local exc_exec = helpers.exc_exec

-- These directories will be created for testing
local directories = {
  tab = 'Xtest-functional-ex_cmds-cd_spec.tab', -- Tab
  window = 'Xtest-functional-ex_cmds-cd_spec.window', -- Window
  global = 'Xtest-functional-ex_cmds-cd_spec.global', -- New global
}

-- Shorthand writing to get the current working directory
local  cwd = function(...) return call('getcwd', ...) end  -- effective working dir
local wcwd = function() return cwd(0) end  -- window dir
local tcwd = function() return cwd(-1, 0) end  -- tab dir

-- Same, except these tell us if there is a working directory at all
local  lwd = function(...) return call('haslocaldir', ...) end  -- effective working dir
local wlwd = function() return lwd(0) end  -- window dir
local tlwd = function() return lwd(-1,  0) end  -- tab dir
--local glwd = function() return eval('haslocaldir(-1, -1)') end  -- global dir

-- Test both the `cd` and `chdir` variants
for _, cmd in ipairs {'cd', 'chdir'} do
  describe(':' .. cmd, function()
    before_each(function()
      clear()
      for _, d in pairs(directories) do
        lfs.mkdir(d)
      end
      directories.start = cwd()
    end)

    after_each(function()
      for _, d in pairs(directories) do
        lfs.rmdir(d)
      end
    end)

    describe('using explicit scope', function()
      it('for window', function()
        local globalDir = directories.start
        local globalwin = call('winnr')
        local tabnr = call('tabpagenr')

        -- Everything matches globalDir to start
        eq(globalDir, cwd(globalwin))
        eq(globalDir, cwd(globalwin, tabnr))
        eq(0, lwd(globalwin))
        eq(0, lwd(globalwin, tabnr))

        execute('bot split')
        local localwin = call('winnr')
        -- Initial window is still using globalDir
        eq(globalDir, cwd(localwin))
        eq(globalDir, cwd(localwin, tabnr))
        eq(0, lwd(globalwin))
        eq(0, lwd(globalwin, tabnr))

        execute('silent l' .. cmd .. ' ' .. directories.window)
        -- From window with local dir, the original window
        -- is still reporting the global dir
        eq(globalDir, cwd(globalwin))
        eq(globalDir, cwd(globalwin, tabnr))
        eq(0, lwd(globalwin))
        eq(0, lwd(globalwin, tabnr))

        -- Window with local dir reports as such
        eq(globalDir .. '/' .. directories.window, cwd(localwin))
        eq(globalDir .. '/' .. directories.window, cwd(localwin, tabnr))
        eq(1, lwd(localwin))
        eq(1, lwd(localwin, tabnr))

        execute('tabnew')
        -- From new tab page, original window reports global dir
        eq(globalDir, cwd(globalwin, tabnr))
        eq(0, lwd(globalwin, tabnr))

        -- From new tab page, local window reports as such
        eq(globalDir .. '/' .. directories.window, cwd(localwin, tabnr))
        eq(1, lwd(localwin, tabnr))
      end)

      it('for tab page', function()
        local globalDir = directories.start
        local globaltab = call('tabpagenr')

        -- Everything matches globalDir to start
        eq(globalDir, cwd(-1, 0))
        eq(globalDir, cwd(-1, globaltab))
        eq(0, lwd(-1, 0))
        eq(0, lwd(-1, globaltab))

        execute('tabnew')
        execute('silent t' .. cmd .. ' ' .. directories.tab)
        local localtab = call('tabpagenr')

        -- From local tab page, original tab reports globalDir
        eq(globalDir, cwd(-1, globaltab))
        eq(0, lwd(-1, globaltab))

        -- new tab reports local
        eq(globalDir .. '/' .. directories.tab, cwd(-1, 0))
        eq(globalDir .. '/' .. directories.tab, cwd(-1, localtab))
        eq(1, lwd(-1, 0))
        eq(1, lwd(-1, localtab))

        execute('tabnext')
        -- From original tab page, local reports as such
        eq(globalDir .. '/' .. directories.tab, cwd(-1, localtab))
        eq(1, lwd(-1, localtab))
      end)
    end)

    describe('getcwd(-1, -1)', function()
      it('works', function()
        eq(directories.start, cwd(-1, -1))
        eq(0, lwd(-1, -1))
      end)

      it('works with tab-local pwd', function()
        execute('silent t' .. cmd .. ' ' .. directories.tab)
        eq(directories.start, cwd(-1, -1))
        eq(0, lwd(-1, -1))
      end)

      it('works with window-local pwd', function()
        execute('silent l' .. cmd .. ' ' .. directories.window)
        eq(directories.start, cwd(-1, -1))
        eq(0, lwd(-1, -1))
      end)
    end)

    it('works', function()
      local globalDir = directories.start
      -- Create a new tab first and verify that is has the same working dir
      execute('tabnew')
      eq(globalDir, cwd())
      eq(globalDir, tcwd())  -- has no tab-local directory
      eq(0, tlwd())
      eq(globalDir, wcwd())  -- has no window-local directory
      eq(0, wlwd())

      -- Change tab-local working directory and verify it is different
      execute('silent t' .. cmd .. ' ' .. directories.tab)
      eq(globalDir .. '/' .. directories.tab, cwd())
      eq(cwd(), tcwd())  -- working directory maches tab directory
      eq(1, tlwd())
      eq(cwd(), wcwd())  -- still no window-directory
      eq(0, wlwd())

      -- Create a new window in this tab to test `:lcd`
      execute('new')
      eq(1, tlwd())  -- Still tab-local working directory
      eq(0, wlwd())  -- Still no window-local working directory
      eq(globalDir .. '/' .. directories.tab, cwd())
      execute('silent l' .. cmd .. ' ../' .. directories.window)
      eq(globalDir .. '/' .. directories.window, cwd())
      eq(globalDir .. '/' .. directories.tab, tcwd())
      eq(1, wlwd())

      -- Verify the first window still has the tab local directory
      execute('wincmd w')
      eq(globalDir .. '/' .. directories.tab,  cwd())
      eq(globalDir .. '/' .. directories.tab, tcwd())
      eq(0, wlwd())  -- No window-local directory

      -- Change back to initial tab and verify working directory has stayed
      execute('tabnext')
      eq(globalDir, cwd() )
      eq(0, tlwd())
      eq(0, wlwd())

      -- Verify global changes don't affect local ones
      execute('silent ' .. cmd .. ' ' .. directories.global)
      eq(globalDir .. '/' .. directories.global, cwd())
      execute('tabnext')
      eq(globalDir .. '/' .. directories.tab,  cwd())
      eq(globalDir .. '/' .. directories.tab, tcwd())
      eq(0, wlwd())  -- Still no window-local directory in this window

      -- Unless the global change happened in a tab with local directory
      execute('silent ' .. cmd .. ' ..')
      eq(globalDir, cwd() )
      eq(0 , tlwd())
      eq(0 , wlwd())
      -- Which also affects the first tab
      execute('tabnext')
      eq(globalDir, cwd())

      -- But not in a window with its own local directory
      execute('tabnext | wincmd w')
      eq(globalDir .. '/' .. directories.window, cwd() )
      eq(0 , tlwd())
      eq(globalDir .. '/' .. directories.window, wcwd())
    end)
  end)
end

-- Test legal parameters for 'getcwd' and 'haslocaldir'
for _, cmd in ipairs {'getcwd', 'haslocaldir'} do
  describe(cmd..'()', function()
    before_each(function()
      clear()
    end)

    -- Test invalid argument types
    local err474 = 'Vim(call):E474: Invalid argument'
    it('fails on string', function()
      eq(err474, exc_exec('call ' .. cmd .. '("some string")'))
    end)
    it('fails on float', function()
      eq(err474, exc_exec('call ' .. cmd .. '(1.0)'))
    end)
    it('fails on list', function()
      eq(err474, exc_exec('call ' .. cmd .. '([1, 2])'))
    end)
    it('fails on dictionary', function()
      eq(err474, exc_exec('call ' .. cmd .. '({"key": "value"})'))
    end)
    it('fails on funcref', function()
      eq(err474, exc_exec('call ' .. cmd .. '(function("tr"))'))
    end)

    -- Test invalid numbers
    it('fails on number less than -1', function()
      eq(err474, exc_exec('call ' .. cmd .. '(-2)'))
    end)
    local err5001 = 'Vim(call):E5001: Higher scope cannot be -1 if lower scope is >= 0.'
    it('fails on -1 if previous arg is >=0', function()
      eq(err5001, exc_exec('call ' .. cmd .. '(0, -1)'))
    end)

    -- Test wrong number of arguments
    local err118 = 'Vim(call):E118: Too many arguments for function: ' .. cmd
    it('fails to parse more than one argument', function()
      eq(err118, exc_exec('call ' .. cmd .. '(0, 0, 0)'))
    end)
  end)
end

