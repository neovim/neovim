-- Specs for :cd, :tcd, :lcd and hastabdir(), haslocaldir()

local helpers = require('test.functional.helpers')
local execute, eq, clear, eval, feed =
  helpers.execute, helpers.eq, helpers.clear, helpers.eval, helpers.feed


-- These directories will be created for testing
local directories = {
  'Xtest-functional-ex_cmds-cd_spec.1', -- Tab
  'Xtest-functional-ex_cmds-cd_spec.2', -- Window
  'Xtest-functional-ex_cmds-cd_spec.3', -- New global
}

-- Shorthand writing to get the current working directory
local wd  = function() return eval('getcwd()'     ) end
local htd = function() return eval('hastabdir()'  ) end
local hld = function() return eval('haslocaldir()') end

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
      local globalDir = wd()

      -- Create a new tab first and verify that is has the same working dir
      execute('tabnew')
      eq(globalDir, wd())
      eq(0, htd())
      eq(0, hld())

      -- Change tab-local working directory and verify it is different
      execute('t' .. cmd .. ' ' .. directories[1])
      eq(globalDir .. '/' .. directories[1], wd())
      eq(1, htd())
      eq(0, hld())

      -- Create a new window in this tab to test `:lcd`
      execute('new')
      eq(1, htd())
      eq(0, hld())
      eq(globalDir .. '/' .. directories[1], wd())
      execute('l' .. cmd .. ' ../' .. directories[2])
      eq(globalDir .. '/' .. directories[2], wd())
      eq(1, htd())
      eq(1, hld())
      -- Verify the first window still has the tab local directory
      execute('wincmd w')
      eq(globalDir .. '/' .. directories[1], wd())
      eq(1, htd())
      eq(0, hld())

      -- Change back to initial tab and verify working directory has stayed
      feed('gt')
      eq(globalDir, wd())
      eq(0, htd())
      eq(0, hld())

      -- Verify global changes don't affect local ones
      execute('' .. cmd .. ' ' .. directories[3])
      eq(globalDir .. '/' .. directories[3], wd())
      feed('gt')
      eq(globalDir .. '/' .. directories[1], wd())
      eq(1, htd())
      eq(0, hld())

      -- Unless the global change happened in a tab with local directory
      execute('' .. cmd .. ' ..')
      eq(globalDir, wd())
      eq(0, htd())
      eq(0, hld())
      -- Which also affects the first tab
      feed('gt')
      eq(globalDir, wd())

      -- But not in a window with its own local directory
      feed('gt')
      execute('wincmd w')
      eq(globalDir .. '/' .. directories[2], wd())
      eq(0, htd())
      eq(1, hld())
    end)
  end)
end

