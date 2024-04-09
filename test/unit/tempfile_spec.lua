local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local eq = t.eq
local neq = t.neq
local cimport = t.cimport
local child_call_once = t.child_call_once
local child_cleanup_once = t.child_cleanup_once

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
    return t.ffi.string(lib.vim_gettempdir())
  end

  describe('vim_gettempdir', function()
    itp('returns path to Nvim own temp directory', function()
      local dir = vim_gettempdir()
      assert.True(dir ~= nil and dir:len() > 0)
      -- os_file_is_writable returns 2 for a directory which we have rights
      -- to write into.
      eq(2, lib.os_file_is_writable(t.to_cstr(dir)))
      for entry in vim.fs.dir(dir) do
        assert.True(entry == '.' or entry == '..')
      end
    end)

    itp('returns the same directory on each call', function()
      eq(vim_gettempdir(), vim_gettempdir())
    end)
  end)

  describe('vim_tempname', function()
    local vim_tempname = function()
      return t.ffi.string(lib.vim_tempname())
    end

    itp('generate name of non-existing file', function()
      local file = vim_tempname()
      assert.truthy(file)
      assert.False(lib.os_path_exists(file))
    end)

    itp('generate different names on each call', function()
      neq(vim_tempname(), vim_tempname())
    end)

    itp('generate file name in Nvim own temp directory', function()
      local dir = vim_gettempdir()
      local file = vim_tempname()
      eq(dir, string.sub(file, 1, string.len(dir)))
    end)
  end)
end)
