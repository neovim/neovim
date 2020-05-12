local lfs = require('lfs')
local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)

local eq = helpers.eq
local neq = helpers.neq
local cimport = helpers.cimport
local child_call_once = helpers.child_call_once
local child_cleanup_once = helpers.child_cleanup_once

local lib = cimport('./src/nvim/os/os.h', './src/nvim/fileio.h')

describe('tempfile related functions', function()
  before_each(function()
    local function vim_deltempdir()
      lib.vim_deltempdir()
    end
    child_call_once(vim_deltempdir)
    child_cleanup_once(vim_deltempdir)
  end)

  local vim_gettempdir = function()
    return helpers.ffi.string(lib.vim_gettempdir())
  end

  describe('vim_gettempdir', function()
    itp('returns path to Neovim own temp directory', function()
      local dir = vim_gettempdir()
      assert.True(dir ~= nil and dir:len() > 0)
      -- os_file_is_writable returns 2 for a directory which we have rights
      -- to write into.
      eq(lib.os_file_is_writable(helpers.to_cstr(dir)), 2)
      for entry in lfs.dir(dir) do
        assert.True(entry == '.' or entry == '..')
      end
    end)

    itp('returns the same directory on each call', function()
      local dir1 = vim_gettempdir()
      local dir2 = vim_gettempdir()
      eq(dir1, dir2)
    end)
  end)

  describe('vim_tempname', function()
    local vim_tempname = function()
      return helpers.ffi.string(lib.vim_tempname())
    end

    itp('generate name of non-existing file', function()
      local file = vim_tempname()
      assert.truthy(file)
      assert.False(lib.os_path_exists(file))
    end)

    itp('generate different names on each call', function()
      local fst = vim_tempname()
      local snd = vim_tempname()
      neq(fst, snd)
    end)

    itp('generate file name in Neovim own temp directory', function()
      local dir = vim_gettempdir()
      local file = vim_tempname()
      eq(string.sub(file, 1, string.len(dir)), dir)
    end)
  end)
end)
