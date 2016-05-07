local lfs = require 'lfs'
local helpers = require 'test.unit.helpers'

local os = helpers.cimport './src/nvim/os/os.h'
local tempfile = helpers.cimport './src/nvim/fileio.h'

describe('tempfile related functions', function()
  before_each(function()
    tempfile.vim_deltempdir()
  end)
  after_each(function()
    tempfile.vim_deltempdir()
  end)

  local vim_gettempdir = function()
    return helpers.ffi.string(tempfile.vim_gettempdir())
  end

  describe('vim_gettempdir', function()
    it('returns path to Neovim own temp directory', function()
      local dir = vim_gettempdir()
      assert.True(dir ~= nil and dir:len() > 0)
      -- os_file_is_writable returns 2 for a directory which we have rights
      -- to write into.
      assert.equals(os.os_file_is_writable(helpers.to_cstr(dir)), 2)
      for entry in lfs.dir(dir) do
        assert.True(entry == '.' or entry == '..')
      end
    end)

    it('returns the same directory on each call', function()
      local dir1 = vim_gettempdir()
      local dir2 = vim_gettempdir()
      assert.equals(dir1, dir2)
    end)
  end)

  describe('vim_tempname', function()
    local vim_tempname = function()
      return helpers.ffi.string(tempfile.vim_tempname())
    end

    it('generate name of non-existing file', function()
      local file = vim_tempname()
      assert.truthy(file)
      assert.False(os.os_file_exists(file))
    end)

    it('generate different names on each call', function()
      local fst = vim_tempname()
      local snd = vim_tempname()
      assert.not_equals(fst, snd)
    end)

    it('generate file name in Neovim own temp directory', function()
      local dir = vim_gettempdir()
      local file = vim_tempname()
      assert.truthy(file:find('^' .. dir .. '[^/]*$'))
    end)
  end)
end)
