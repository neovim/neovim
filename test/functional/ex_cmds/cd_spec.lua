-- Specs for :cd, :tcd, :lcd and getcwd()

local helpers = require('test.functional.helpers')
local execute, eq, clear, eval, exc_exec =
  helpers.execute, helpers.eq, helpers.clear, helpers.eval, helpers.exc_exec
local lfs = require('lfs')

-- These directories will be created for testing
local directories = {
  'Xtest-functional-ex_cmds-cd_spec.1', -- Tab
  'Xtest-functional-ex_cmds-cd_spec.2', -- Window
  'Xtest-functional-ex_cmds-cd_spec.3', -- New global
}

-- Shorthand writing to get the current working directory
local  cwd = function() return eval('getcwd(      )') end  -- effective working dir
local wcwd = function() return eval('getcwd( 0    )') end  -- window dir
local tcwd = function() return eval('getcwd(-1,  0)') end  -- tab dir
--local gcwd = function() return eval('getcwd(-1, -1)') end  -- global dir

-- Same, except these tell us if there is a working directory at all
--local  lwd = function() return eval('haslocaldir(      )') end  -- effective working dir
local wlwd = function() return eval('haslocaldir( 0    )') end  -- window dir
local tlwd = function() return eval('haslocaldir(-1,  0)') end  -- tab dir
--local glwd = function() return eval('haslocaldir(-1, -1)') end  -- global dir

-- Test both the `cd` and `chdir` variants
for _, cmd in ipairs {'cd', 'chdir'} do
  describe(':*' .. cmd, function()
    before_each(function()
      clear()
      for _, d in ipairs(directories) do
        lfs.mkdir(d)
      end
    end)

    after_each(function()
      for _, d in ipairs(directories) do
        lfs.rmdir(d)
      end
    end)

    it('works', function()
      -- Store the initial working directory
      local globalDir = cwd()

      -- Create a new tab first and verify that is has the same working dir
      execute('tabnew')
      eq(globalDir, cwd())
      eq(globalDir, tcwd())  -- has no tab-local directory
      eq(0, tlwd())
      eq(globalDir, wcwd())  -- has no window-local directory
      eq(0, wlwd())

      -- Change tab-local working directory and verify it is different
      execute('silent t' .. cmd .. ' ' .. directories[1])
      eq(globalDir .. '/' .. directories[1], cwd())
      eq(cwd(), tcwd())  -- working directory maches tab directory
      eq(1, tlwd())
      eq(cwd(), wcwd())  -- still no window-directory
      eq(0, wlwd())

      -- Create a new window in this tab to test `:lcd`
      execute('new')
      eq(1, tlwd())  -- Still tab-local working directory
      eq(0, wlwd())  -- Still no window-local working directory
      eq(globalDir .. '/' .. directories[1], cwd())
      execute('silent l' .. cmd .. ' ../' .. directories[2])
      eq(globalDir .. '/' .. directories[2], cwd())
      eq(globalDir .. '/' .. directories[1], tcwd())
      eq(1, wlwd())

      -- Verify the first window still has the tab local directory
      execute('wincmd w')
      eq(globalDir .. '/' .. directories[1],  cwd())
      eq(globalDir .. '/' .. directories[1], tcwd())
      eq(0, wlwd())  -- No window-local directory

      -- Change back to initial tab and verify working directory has stayed
      execute('tabnext')
      eq(globalDir, cwd() )
      eq(0, tlwd())
      eq(0, wlwd())

      -- Verify global changes don't affect local ones
      execute('silent ' .. cmd .. ' ' .. directories[3])
      eq(globalDir .. '/' .. directories[3], cwd())
      execute('tabnext')
      eq(globalDir .. '/' .. directories[1],  cwd())
      eq(globalDir .. '/' .. directories[1], tcwd())
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
      eq(globalDir .. '/' .. directories[2], cwd() )
      eq(0 , tlwd())
      eq(globalDir .. '/' .. directories[2], wcwd())
    end)
  end)
end

-- Test legal parameters for 'getcwd' and 'haslocaldir'
for _, cmd in ipairs {'getcwd', 'haslocaldir'} do
  describe(cmd..'()', function()
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

