local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local mkdir_p = helpers.mkdir_p
local rmdir = helpers.rmdir
local nvim_dir = helpers.nvim_dir
local test_build_dir = helpers.test_build_dir

before_each(clear)

describe('vim.fs', function()
  describe('parents()', function()
    it('works', function()
      local test_dir = nvim_dir .. '/test'
      mkdir_p(test_dir)
      local dirs = exec_lua([[
        local test_dir, test_build_dir = ...
        local dirs = {}
        for dir in vim.fs.parents(test_dir .. "/foo.txt") do
          dirs[#dirs + 1] = dir
          if dir == test_build_dir then
            break
          end
        end
        return dirs
      ]], test_dir, test_build_dir)
      eq({test_dir, nvim_dir, test_build_dir}, dirs)
      rmdir(test_dir)
    end)
  end)

  describe('dirname()', function()
    it('works', function()
      eq(test_build_dir, exec_lua([[
        local nvim_dir = ...
        return vim.fs.dirname(nvim_dir)
      ]], nvim_dir))
    end)
  end)
end)
