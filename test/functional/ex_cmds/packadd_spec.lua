local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('packadd', function()
  before_each(function()
    -- Primarily taken from test/functional/legacy/packadd_spec.lua
    clear()
    exec_lua [[
      TopDirectory = vim.fn.expand(vim.fn.getcwd() .. '/Xdir_lua')
      PlugDirectory = TopDirectory .. '/pack/mine/opt/mytest'

      vim.o.packpath = TopDirectory

      function FindPathsContainingDir(dir)
        return vim.fn.filter(
          vim.split(package.path, ';'),
          function(k, v)
            return string.find(v, 'mytest') ~= nil
          end
        )
      end
    ]]
  end)

  after_each(function()
    exec_lua [[
      vim.fn.delete(TopDirectory, 'rf')
    ]]
  end)

  it('should immediately update package.path in lua', function()
    local count_of_paths = exec_lua [[
      vim.fn.mkdir(PlugDirectory .. '/lua/', 'p')

      local num_paths_before = #FindPathsContainingDir('mytest')

      vim.cmd("packadd mytest")

      local num_paths_after = #FindPathsContainingDir('mytest')

      return { num_paths_before, num_paths_after }
    ]]

    eq({0, 2}, count_of_paths)
  end)

  it('should immediately update package.path in lua even if lua directory does not exist', function()
    local count_of_paths = exec_lua [[
      vim.fn.mkdir(PlugDirectory .. '/plugin/', 'p')

      local num_paths_before = #FindPathsContainingDir('mytest')

      vim.cmd("packadd mytest")

      local num_paths_after = #FindPathsContainingDir('mytest')

      return { num_paths_before, num_paths_after }
    ]]

    eq({0, 2}, count_of_paths)
  end)

  it('should error for invalid paths', function()
    local count_of_paths = exec_lua [[
      local ok, err = pcall(vim.cmd, "packadd asdf")
      return ok
    ]]

    eq(false, count_of_paths)
  end)
end)
