local ffi = require('ffi')
local formatc = require('test.unit.formatc')
local Set = require('test.unit.set')
local Preprocess = require('test.unit.preprocess')
local Paths = require('test.config.paths')

-- add some standard header locations
for _, p in ipairs(Paths.include_paths) do
  Preprocess.add_to_include_path(p)
end

-- load neovim shared library
local libnvim = ffi.load(Paths.test_libnvim_path)

local function trim(s)
  return s:match('^%s*(.*%S)') or ''
end

-- a Set that keeps around the lines we've already seen
if cdefs == nil then
  cdefs = Set:new()
end

if imported == nil then
  imported = Set:new()
end

-- some things are just too complex for the LuaJIT C parser to digest. We
-- usually don't need them anyway.
local function filter_complex_blocks(body)
  local result = {}

  for line in body:gmatch("[^\r\n]+") do
    if not (string.find(line, "(^)", 1, true) ~= nil or
      string.find(line, "_ISwupper", 1, true)) then
      result[#result + 1] = line
    end
  end

  return table.concat(result, "\n")
end

-- use this helper to import C files, you can pass multiple paths at once,
-- this helper will return the C namespace of the nvim library.
local function cimport(...)
  local paths = {}
  local args = {...}

  -- filter out paths we've already imported
  for _,path in pairs(args) do
    if path ~= nil and not imported:contains(path) then
      paths[#paths + 1] = path
    end
  end

  for _,path in pairs(paths) do
    imported:add(path)
  end

  if #paths == 0 then
    return libnvim
  end

  local body = nil
  for i=1, 3 do
    local stream = Preprocess.preprocess_stream(unpack(paths))
    body = stream:read("*a")
    stream:close()
    if body ~= nil then break end
  end

  if body == nil then
    print("ERROR: helpers.lua: Preprocess.preprocess_stream():read() returned empty")
  end

  -- format it (so that the lines are "unique" statements), also filter out
  -- Objective-C blocks
  body = formatc(body)
  body = filter_complex_blocks(body)

  -- add the formatted lines to a set
  local new_cdefs = Set:new()
  for line in body:gmatch("[^\r\n]+") do
    new_cdefs:add(trim(line))
  end

  -- subtract the lines we've already imported from the new lines, then add
  -- the new unique lines to the old lines (so they won't be imported again)
  new_cdefs:diff(cdefs)
  cdefs:union(new_cdefs)

  if new_cdefs:size() == 0 then
    -- if there's no new lines, just return
    return libnvim
  end

  -- request a sorted version of the new lines (same relative order as the
  -- original preprocessed file) and feed that to the LuaJIT ffi
  local new_lines = new_cdefs:to_table()
  ffi.cdef(table.concat(new_lines, "\n"))

  return libnvim
end

local function cppimport(path)
  return cimport(Paths.test_include_path .. '/' .. path)
end

cimport('./src/nvim/types.h')

-- take a pointer to a C-allocated string and return an interned
-- version while also freeing the memory
local function internalize(cdata, len)
  ffi.gc(cdata, ffi.C.free)
  return ffi.string(cdata, len)
end

local cstr = ffi.typeof('char[?]')
local function to_cstr(string)
  return cstr((string.len(string)) + 1, string)
end

-- initialize some global variables, this is still necessary to unit test
-- functions that rely on global state.
local function vim_init()
  if vim_init_called ~= nil then
    return 
  end
  -- import os_unix.h for mch_early_init(), which initializes some globals
  local all = cimport('./src/nvim/os_unix.h',
                      './src/nvim/misc1.h',
                      './src/nvim/eval.h',
                      './src/nvim/os_unix.h',
                      './src/nvim/option.h',
                      './src/nvim/ex_cmds2.h',
                      './src/nvim/window.h',
                      './src/nvim/ops.h',
                      './src/nvim/normal.h',
                      './src/nvim/mbyte.h')
  all.mch_early_init()
  all.mb_init()
  all.eval_init()
  all.init_normal_cmds()
  all.win_alloc_first()
  all.init_yank()
  all.init_homedir()
  all.set_init_1()
  all.set_lang_var()
  vim_init_called = true
end

-- C constants.
local NULL = ffi.cast('void*', 0)

local OK = 1
local FAIL = 0

return {
  cimport = cimport,
  cppimport = cppimport,
  internalize = internalize,
  eq = function(expected, actual)
    return assert.are.same(expected, actual)
  end,
  neq = function(expected, actual)
    return assert.are_not.same(expected, actual)
  end,
  ffi = ffi,
  lib = libnvim,
  cstr = cstr,
  to_cstr = to_cstr,
  vim_init = vim_init,
  NULL = NULL,
  OK = OK,
  FAIL = FAIL
}
