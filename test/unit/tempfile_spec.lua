local lfs = require 'lfs'

local helpers = require 'test.unit.helpers'
local cimport, vim_init, ffi, to_cstr =
  helpers.cimport, helpers.vim_init, helpers.ffi, helpers.to_cstr

local os = helpers.cimport './src/nvim/os/os.h'
local os_isdir, os_file_is_writable, os_file_exists =
  os.os_isdir, os.os_file_is_writable, os.os_file_exists

local is_dir = function(x) return os_isdir(x) end

-- os_file_is_writable returns 2 for a directory which we have rights
-- to write into.
local is_writable = function(x) return os_file_is_writable(to_cstr(x)) == 2 end

local is_empty = function(x)
  local r = true
  for f in lfs.dir(x) do
    r = r and (f == '.' or f == '..')
  end
  return r
end

local file_exists = function(x) return os_file_exists(x) end

local path_contains_dir = function(path, dir)
  return (path ~= nil) and (path:find("^" .. tostring(dir) .. "[^/]*$") ~= nil)
end

local dir_of_path = function(path)
  return path:match('(.-)[^/]+$') or ''
end

local ok = function(x) return assert.True(x) end
local notok = function(x) return assert.False(x) end

local tempfile = helpers.cimport './src/nvim/tempfile.h'
local vim_gettempdir = function() return ffi.string(tempfile.vim_gettempdir()) end
local vim_tempname = function() return ffi.string(tempfile.vim_tempname()) end
local vim_deltempdir = function() return tempfile.vim_deltempdir() end

vim_init()

describe('tempfile module:', function()

  after_each(function() vim_deltempdir() end)

  describe('vim_gettempdir', function()

    it('generates directory name to a writable, empty directory on first call', function()
      local dir = vim_gettempdir()
      ok(dir ~= nil and dir:len() > 0)
      ok((is_dir(dir)) and (is_writable(dir)) and (is_empty(dir)))
    end)

    it('generates a directory which can be later deleted', function()
      local dir = vim_gettempdir()
      ok(is_dir(dir))
      vim_deltempdir()
      notok(is_dir(dir))
    end)

    context('called successively', function()

      it('generates the same directory name', function()
        local dir1, dir2
        dir1 = vim_gettempdir()
        dir2 = vim_gettempdir()
        ok(dir1 == dir2)
      end)

      it('interrupted by generating a file name, generates the same directory name', function()
        local dir1, dir2
        dir1 = vim_gettempdir()
        vim_tempname()
        dir2 = vim_gettempdir()
        ok(dir1 == dir2)
      end)

      it('interrupted by deleting the temp directory, generates different directory names with corresponding directories', function()
        local dir1, dir2
        dir1 = vim_gettempdir()
        ok(is_dir(dir1))
        vim_deltempdir()
        dir2 = vim_gettempdir()
        ok(is_dir(dir2))
        ok(dir1 ~= dir2)
      end)

      it('interrupted by externally deleting the temp directory, generates the same directory name and with no corresponding director ', function()
        local dir1, dir2
        dir1 = vim_gettempdir()
        ok(is_dir(dir1))
        ok(lfs.rmdir(dir1))
        dir2 = vim_gettempdir()
        notok(is_dir(dir2))
        notok(dir1 ~= dir2)
      end)
    end)
  end)

  describe('vim_tempname', function()

    it('generates path name of a non-existing file in temp directory', function()
      local path, dir = vim_tempname(), vim_gettempdir()
      ok(path_contains_dir(path, dir))
      notok(file_exists(path))
    end)

    context('called successively', function()

      it('generates different paths with a common temp directory', function()
        local path1, path2 = vim_tempname(), vim_tempname()
        ok(path1 ~= path2)
        ok(dir_of_path(path1) == dir_of_path(path2))
      end)

      it('interrupted by generating a directory name, generates different paths with a common temp directory', function()
        local path1, path2
        path1 = vim_tempname()
        vim_gettempdir()
        path2 = vim_tempname()
        ok(path1 ~= path2)
        ok(dir_of_path(path1) == dir_of_path(path2))
      end)

      it('interrupted by deleting the temp directory, generates paths with different temp directories', function()
        local path1, path2
        path1 = vim_tempname()
        vim_deltempdir()
        path2 = vim_tempname()
        ok(path1 ~= path2)
        notok(dir_of_path(path1) == dir_of_path(path2))
      end)

      it('interrupted by externally deleting the temp directory, generates a path that is no longer useful', function()
        local path1, path2
        local dir1, dir2
        path1 = vim_tempname()
        dir1 = dir_of_path(path1)
        ok(lfs.rmdir(dir1))
        path2 = vim_tempname()
        dir2 = dir_of_path(path2)
        ok(path1 ~= path2)
        ok(dir1 == dir2)
        ok(path_contains_dir(path2, dir1))
      end)
    end)
  end)
end)
