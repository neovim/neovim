local cimport, vim_init, ffi, to_cstr, eq, neq = (function()
  local _ = require 'test.unit.helpers'
  return _.cimport, _.vim_init, _.ffi, _.to_cstr, _.eq, _.neq
end)()

local lfs = require 'lfs'

local os = cimport './src/nvim/os/os.h'

-- is_dir('/a/b/') will return true if '/a/b/' is a directory name
local is_dir = function(x) return 'directory' == lfs.attributes(x, 'mode') end

-- os_file_is_writable returns 2 for a directory which we have rights
-- to write into.
local is_writable = function(x) return os.os_file_is_writable(to_cstr(x)) == 2 end

-- is_empty('/a/b/') will return true if 'a/b/' is a directory linking only to itself and the parent dir
local is_empty = function(x)
  for f in lfs.dir(x) do
    if f ~= '.' and f ~= '..' then return false end
  end
  return true
end

-- file_exists('/a/b/c') will return true if '/a/b/c' is an existing file
local file_exists = os.os_file_exists

-- path_contains_dir('/a/b/c', '/a/b/') will return true
local path_contains_dir = function(path, dir)
  return (path ~= nil) and (path:find("^" .. tostring(dir) .. "[^/]*$") ~= nil)
end

-- dir_of_path('/a/b/c') will return '/a/b/'
local dir_of_path = function(path)
  return path:match('(.-)[^/]+$') or ''
end

local ok = function(x) return assert.True(x) end

local tempfile = cimport './src/nvim/tempfile.h'
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
      ok(is_dir(dir))
      ok(is_writable(dir))
      ok(is_empty(dir))
    end)

    it('generates a directory which can be later deleted', function()
      local dir = vim_gettempdir()
      ok(is_dir(dir))
      vim_deltempdir()
      ok(not is_dir(dir))
    end)

    context('called successively', function()

      it('generates the same directory name', function()
        local dir1 = vim_gettempdir()
        local dir2 = vim_gettempdir()
        eq(dir1, dir2)
      end)

      it('interrupted by generating a file name, generates the same directory name', function()
        local dir1 = vim_gettempdir()
        vim_tempname()
        local dir2 = vim_gettempdir()
        eq(dir1, dir2)
      end)

      it('interrupted by deleting the temp directory, generates different directory names with corresponding directories', function()
        local dir1 = vim_gettempdir()
        ok(is_dir(dir1))
        vim_deltempdir()
        local dir2 = vim_gettempdir()
        ok(is_dir(dir2))
        neq(dir1, dir2)
      end)

      it('interrupted by externally deleting the temp directory, generates the same directory name and with no corresponding director ', function()
        local dir1 = vim_gettempdir()
        ok(is_dir(dir1))
        ok(lfs.rmdir(dir1))
        local dir2 = vim_gettempdir()
        ok(not is_dir(dir2))
        eq(dir1, dir2)
      end)
    end)
  end)

  describe('vim_tempname', function()

    it('generates path name of a non-existing file in temp directory', function()
      local path, dir = vim_tempname(), vim_gettempdir()
      ok(path_contains_dir(path, dir))
      ok(not file_exists(path))
    end)

    context('called successively', function()

      it('generates different paths with a common temp directory', function()
        local path1, path2 = vim_tempname(), vim_tempname()
        neq(path1, path2)
        eq(dir_of_path(path1), dir_of_path(path2))
      end)

      it('interrupted by generating a directory name, generates different paths with a common temp directory', function()
        local path1 = vim_tempname()
        vim_gettempdir()
        local path2 = vim_tempname()
        neq(path1, path2)
        eq(dir_of_path(path1), dir_of_path(path2))
      end)

      it('interrupted by deleting the temp directory, generates paths with different temp directories', function()
        local path1 = vim_tempname()
        vim_deltempdir()
        local path2 = vim_tempname()
        neq(path1, path2)
        neq(dir_of_path(path1), dir_of_path(path2))
      end)

      it('interrupted by externally deleting the temp directory, generates a path that is no longer useful', function()
        local path1 = vim_tempname()
        local dir1 = dir_of_path(path1)
        ok(lfs.rmdir(dir1))
        local path2 = vim_tempname()
        local dir2 = dir_of_path(path2)
        neq(path1, path2)
        eq(dir1, dir2)
        ok(path_contains_dir(path2, dir1))
      end)
    end)
  end)
end)
