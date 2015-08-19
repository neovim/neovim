-- Specs for :cd, :tcd, :lcd

local helpers = require('test.functional.helpers')
local nvim, execute, eq, clear, eval, feed =
  helpers.nvim, helpers.execute, helpers.eq, helpers.clear, helpers.eval, helpers.feed

describe(':cd :tcd', function()
  before_each(clear)

  --it('sets to local directory for the program, tabs and windows', function()
    local wd = function()
      return eval('getcwd()')
    end

    -- Test both spellings: cd and chdir
    -- Their variants differ in prefix (none, 't' and 'l')
    for _, cmd in ipairs({'cd', 'chdir'}) do
      describe('*' .. cmd, function()
        it('works', function()
          -- Store the initial working directory
          local globalDir = wd()

          -- Make tree of directories
          local directories = {
            {name = 'lua_test_dir_1', children =  {
                {name = 'dir_a', children = nil},
                {name = 'dir_b', children = nil},
              },
            },
            {name = 'lua_test_dir_2', children =  nil},
          }

          local buildDirectoryTree
          buildDirectoryTree = function(tree, prefix)
            for _, v in ipairs(tree) do
              os.execute('mkdir ' .. prefix .. v.name)
              if v.children then
                for _, w in ipairs(v.children) do
                  buildDirectoryTree(w, prefix .. v.name .. '/')
                end
              end
            end
          end
          
          buildDirectoryTree(directories, '')

          --os.execute('mkdir ' .. directories[1].name)
          --os.execute('mkdir ' .. directories[1])
          --os.execute('mkdir ' .. directories[2])
          --os.execute('mkdir ' .. directories[3])

          -- Create a new tab first and verify that is has the same working dir
          execute('tabnew')
          eq(wd(), globalDir)

          -- Change tab-local working directory and verify it is different
          execute('t' .. cmd .. ' ' .. directories[1].name)
          eq(wd(), globalDir .. '/' .. directories[1].name)

          -- Create a new window in this tab to test `:lcd`
          execute('new')
          eq(wd(), globalDir .. '/test')
          execute('l' .. cmd .. ' benchmark')
          eq(wd(), globalDir .. '/test/benchmark')
          -- Verify the first window still has the tab local directory
          execute('wincmd w')
          eq(wd(), globalDir .. '/test')

          -- Change back to initial tab and verify working directory has stayed
          feed('gt')
          eq(wd(), globalDir)

          -- Verify global changes don't affect local ones
          execute('' .. cmd .. ' build')
          eq(wd(), globalDir .. '/build')
          feed('gt')
          eq(wd(), globalDir .. '/test')

          -- Unless the global change happened in a tab with local directory
          execute('' .. cmd .. ' ..')
          eq(wd(), globalDir)
          -- Which also affects the first tab
          feed('gt')
          eq(wd(), globalDir)

          -- But not in a window with its own local directory
          feed('gt')
          execute('wincmd w')
          eq(wd(), globalDir .. '/test/benchmark')
        end)
      end)
    end
  --end)
end)

