local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local mkdir_p = helpers.mkdir_p
local rmdir = helpers.rmdir
local nvim_dir = helpers.nvim_dir
local test_build_dir = helpers.test_build_dir
local iswin = helpers.iswin
local nvim_prog = helpers.nvim_prog

local nvim_prog_basename = iswin() and 'nvim.exe' or 'nvim'

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

  describe('basename()', function()
    it('works', function()
      eq(nvim_prog_basename, exec_lua([[
        local nvim_prog = ...
        return vim.fs.basename(nvim_prog)
      ]], nvim_prog))
    end)
  end)

  describe('dir()', function()
    it('works', function()
      eq(true, exec_lua([[
        local dir, nvim = ...
        for name, type in vim.fs.dir(dir) do
          if name == nvim and type == 'file' then
            return true
          end
        end
        return false
      ]], nvim_dir, nvim_prog_basename))
    end)
  end)

  describe('find()', function()
    it('works', function()
      eq({test_build_dir}, exec_lua([[
        local dir = ...
        return vim.fs.find('build', { path = dir, upward = true, type = 'directory' })
      ]], nvim_dir))
      eq({nvim_prog}, exec_lua([[
        local dir, nvim = ...
        return vim.fs.find(nvim, { path = dir, type = 'file' })
      ]], test_build_dir, nvim_prog_basename))
    end)
  end)

  describe('normalize()', function()
    it('works with backward slashes', function()
      eq('C:/Users/jdoe', exec_lua [[ return vim.fs.normalize('C:\\Users\\jdoe') ]])
    end)
    it('works with ~', function()
      if iswin() then
        pending([[$HOME does not exist on Windows ¯\_(ツ)_/¯]])
      end
      eq(os.getenv('HOME') .. '/src/foo', exec_lua [[ return vim.fs.normalize('~/src/foo') ]])
    end)
    it('works with environment variables', function()
      local xdg_config_home = test_build_dir .. '/.config'
      eq(xdg_config_home .. '/nvim', exec_lua([[
        vim.env.XDG_CONFIG_HOME = ...
        return vim.fs.normalize('$XDG_CONFIG_HOME/nvim')
      ]], xdg_config_home))
    end)
  end)
end)
