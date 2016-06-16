local helpers = require("test.unit.helpers")
local lfs     = require("lfs")
--{:cimport, :internalize, :eq, :neq, :ffi, :lib, :cstr, :to_cstr} = require 'test.unit.helpers'

local eq      = helpers.eq
local neq     = helpers.neq
local ffi     = helpers.ffi
local to_cstr = helpers.to_cstr

local file_search = helpers.cimport("./src/nvim/file_search.h")
local event = helpers.cimport("./src/nvim/os/event.h")

local string_eq = function(lua_str, c_str)
  neq(NULL, c_str)
  eq(lua_str, ffi.string(c_str))
end

describe('vim_findfile functions', function()
  local vim_findfile_init = function(path, filename, find_what, tagfile)
    local find_file = 0
    local res = file_search.vim_findfile_init(to_cstr(path),
        to_cstr(filename), find_file, NULL, false, NULL)
    return res
  end

  describe('vim_findfile_init', function()
    it('returns a ff_seach_ctx_T with correct values', function()
      local ctx = vim_findfile_init('test', 'file_search_spec.lua', 0, false)
      neq(NULL, ctx)

      neq(NULL, ctx["ffsc_stack_ptr"])
      neq(NULL, ctx["ffsc_visited_list"])
      neq(NULL, ctx["ffsc_dir_visited_list"])
      neq(NULL, ctx["ffsc_visited_lists_list"])
      neq(NULL, ctx["ffsc_dir_visited_lists_list"])
      string_eq("file_search_spec.lua", ctx["ffsc_file_to_search"])
      string_eq(lfs.currentdir(), ctx["ffsc_start_dir"])
      string_eq('test', ctx["ffsc_fix_path"])
      eq(NULL, ctx["ffsc_wc_path"])
      eq(100, ctx["ffsc_level"])
      eq(NULL, ctx["ffsc_stopdirs_v"])
      eq(0, ctx["ffsc_find_what"]) -- FINDFILE_FILE
      eq(0, ctx["ffsc_tagfile"])
    end)

    it('handles wildcard in path names', function()
      local ctx = vim_findfile_init('test**65', 'file_search_spec.lua', 0, false)
      neq(NULL, ctx)

      string_eq("file_search_spec.lua", ctx["ffsc_file_to_search"])
      string_eq(lfs.currentdir(), ctx["ffsc_start_dir"])
      string_eq('test', ctx["ffsc_fix_path"])
      string_eq('**A', ctx["ffsc_wc_path"])
    end)
  end)

  describe('init: ffsc_stopdirs_v', function()
    local create_stopdirs = function(path)
      local ctx = vim_findfile_init(path, 'file_search_spec.lua', 0, false)
      if (ctx == NULL) then
        return "null context"
      end
      return ctx["ffsc_stopdirs_v"]
    end

    it('returns NULL if there is no comma', function()
      res = create_stopdirs("asdfh32#$%#&*")
      eq(NULL, res)
    end)

    it("returns a NULL ctx when the first character isn't a comma", function()
      res = create_stopdirs("hello;world")
      eq("null context", res)
    end)

    it('strips leading comma', function()
      res = create_stopdirs(";dir1")
      string_eq("dir1", res[0])
      eq(NULL, res[1])
    end)

    it('splits the remaining part', function()
      res = create_stopdirs(";dir1;dir2;dir3")
      string_eq("dir1", res[0])
      string_eq("dir2", res[1])
      string_eq("dir3", res[2])
      eq(NULL, res[3])
    end)

    it('ignores escaped commas', function()
      res = create_stopdirs(";file path with a comma\\;in it;dir1")
      string_eq("file path with a comma\\", res[0])
      string_eq("in it", res[1])
      string_eq("dir1", res[2])
      eq(NULL, res[3])
    end)
  end)

  describe('vim_findfile', function()
    local vim_findfile = function(search_ctx)
      helpers.vim_init()
      event.event_init()
      res = file_search.vim_findfile(search_ctx)
      event.event_teardown()
      return res
    end

    it('returns found files until NULL', function()
      local file = 'file_search_spec.lua'
      local ctx = vim_findfile_init(lfs.currentdir() .. "**2", file, 0, false)
      local res1 = vim_findfile(ctx)
      local res2 = vim_findfile(ctx)

      string_eq('test/unit/file_search_spec.lua', res1)
      eq(NULL, res2)
    end)
  end)

  describe('find_file_in_path', function()
    local findfile = function(filename)
      helpers.vim_init()
      event.event_init()
      local len = string.len(filename)
      res = file_search.find_file_in_path(to_cstr(filename), len, 0,
        true, to_cstr(lfs.currentdir()))
      event.event_teardown()
      return res
    end

    it('finds a file', function()
      local file = findfile("neovim/test/unit/file_search_spec.lua")
      string_eq("test/unit/file_search_spec.lua", file)
    end)

    it('returns NULL when there is no file', function()
      local file = findfile("hergblergh")
      eq(NULL, file)
    end)

    it('finds a file in the relative path', function()
      local file = findfile("./test/unit/file_search_spec.lua")
      string_eq("./test/unit/file_search_spec.lua", file)
    end)

    it('returns NULL when there is no file in the relative path', function()
      local file = findfile("./hergblergh")
      eq(NULL, file)
    end)
  end)
end)
