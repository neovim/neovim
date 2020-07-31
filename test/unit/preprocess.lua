-- helps managing loading different headers into the LuaJIT ffi. Untested on
-- windows, will probably need quite a bit of adjustment to run there.

local ffi = require("ffi")
local global_helpers = require('test.helpers')

local argss_to_cmd = global_helpers.argss_to_cmd
local repeated_read_cmd = global_helpers.repeated_read_cmd

local ccs = {}

local env_cc = os.getenv("CC")
if env_cc then
  table.insert(ccs, {path = {"/usr/bin/env", env_cc}, type = "gcc"})
end

if ffi.os == "Windows" then
  table.insert(ccs, {path = {"cl"}, type = "msvc"})
end

table.insert(ccs, {path = {"/usr/bin/env", "cc"}, type = "gcc"})
table.insert(ccs, {path = {"/usr/bin/env", "gcc"}, type = "gcc"})
table.insert(ccs, {path = {"/usr/bin/env", "gcc-4.9"}, type = "gcc"})
table.insert(ccs, {path = {"/usr/bin/env", "gcc-4.8"}, type = "gcc"})
table.insert(ccs, {path = {"/usr/bin/env", "gcc-4.7"}, type = "gcc"})
table.insert(ccs, {path = {"/usr/bin/env", "clang"}, type = "clang"})
table.insert(ccs, {path = {"/usr/bin/env", "icc"}, type = "gcc"})

-- parse Makefile format dependencies into a Lua table
local function parse_make_deps(deps)
  -- remove line breaks and line concatenators
  deps = deps:gsub("\n", ""):gsub("\\", "")
  -- remove the Makefile "target:" element
  deps = deps:gsub(".+:", "")
  -- remove redundant spaces
  deps = deps:gsub("  +", " ")

  -- split according to token (space in this case)
  local headers = {}
  for token in deps:gmatch("[^%s]+") do
    -- headers[token] = true
    headers[#headers + 1] = token
  end

  -- resolve path redirections (..) to normalize all paths
  for i, v in ipairs(headers) do
    -- double dots (..)
    headers[i] = v:gsub("/[^/%s]+/%.%.", "")
    -- single dot (.)
    headers[i] = v:gsub("%./", "")
  end

  return headers
end

-- will produce a string that represents a meta C header file that includes
-- all the passed in headers. I.e.:
--
-- headerize({"stdio.h", "math.h"}, true)
-- produces:
-- #include <stdio.h>
-- #include <math.h>
--
-- headerize({"vim.h", "memory.h"}, false)
-- produces:
-- #include "vim.h"
-- #include "memory.h"
local function headerize(headers, global)
  local pre = '"'
  local post = pre
  if global then
    pre = "<"
    post = ">"
  end

  local formatted = {}
  for _, hdr in ipairs(headers) do
    formatted[#formatted + 1] = "#include " ..
                                tostring(pre) ..
                                tostring(hdr) ..
                                tostring(post)
  end

  return table.concat(formatted, "\n")
end

local Gcc = {
  preprocessor_extra_flags = {},
  get_defines_extra_flags = {'-std=c99', '-dM', '-E'},
  get_declarations_extra_flags = {'-std=c99', '-P', '-E'},
}
if ffi.abi("32bit") then
  table.insert(Gcc.get_defines_extra_flags, '-m32')
  table.insert(Gcc.get_declarations_extra_flags, '-m32')
end

function Gcc:define(name, args, val)
  local define = '-D' .. name
  if args ~= nil then
    define = define .. '(' .. table.concat(args, ',') .. ')'
  end
  if val ~= nil then
    define = define .. '=' .. val
  end
  self.preprocessor_extra_flags[#self.preprocessor_extra_flags + 1] = define
end

function Gcc:undefine(name)
  self.preprocessor_extra_flags[#self.preprocessor_extra_flags + 1] = (
      '-U' .. name)
end

function Gcc:init_defines()
  -- preprocessor flags that will hopefully make the compiler produce C
  -- declarations that the LuaJIT ffi understands.
  self:define('aligned', {'ARGS'}, '')
  self:define('__attribute__', {'ARGS'}, '')
  self:define('__asm', {'ARGS'}, '')
  self:define('__asm__', {'ARGS'}, '')
  self:define('__inline__', nil, '')
  self:define('EXTERN', nil, 'extern')
  self:define('INIT', {'...'}, '')
  self:define('_GNU_SOURCE')
  self:define('INCLUDE_GENERATED_DECLARATIONS')
  self:define('UNIT_TESTING')
  self:define('UNIT_TESTING_LUA_PREPROCESSING')
  -- Needed for FreeBSD
  self:define('_Thread_local', nil, '')
  -- Needed for macOS Sierra
  self:define('_Nullable', nil, '')
  self:define('_Nonnull', nil, '')
  self:undefine('__BLOCKS__')
end

function Gcc:new(obj)
  obj = obj or {}
  setmetatable(obj, self)
  self.__index = self
  self:init_defines()
  return obj
end

function Gcc:add_to_include_path(...)
  for i = 1, select('#', ...) do
    local path = select(i, ...)
    local ef = self.preprocessor_extra_flags
    ef[#ef + 1] = '-I' .. path
  end
end

-- returns a list of the headers files upon which this file relies
function Gcc:dependencies(hdr)
  local cmd = argss_to_cmd(self.path, {'-M', hdr}) .. ' 2>&1'
  local out = io.popen(cmd)
  local deps = out:read("*a")
  out:close()
  if deps then
    return parse_make_deps(deps)
  else
    return nil
  end
end

function Gcc:filter_standard_defines(defines)
  if not self.standard_defines then
    local pseudoheader_fname = 'tmp_empty_pseudoheader.h'
    local pseudoheader_file = io.open(pseudoheader_fname, 'w')
    pseudoheader_file:close()
    local standard_defines = repeated_read_cmd(self.path,
                                               self.preprocessor_extra_flags,
                                               self.get_defines_extra_flags,
                                               {pseudoheader_fname})
    os.remove(pseudoheader_fname)
    self.standard_defines = {}
    for line in standard_defines:gmatch('[^\n]+') do
      self.standard_defines[line] = true
    end
  end
  local ret = {}
  for line in defines:gmatch('[^\n]+') do
    if not self.standard_defines[line] then
      ret[#ret + 1] = line
    end
  end
  return table.concat(ret, "\n")
end

-- returns a stream representing a preprocessed form of the passed-in headers.
-- Don't forget to close the stream by calling the close() method on it.
function Gcc:preprocess(previous_defines, ...)
  -- create pseudo-header
  local pseudoheader = headerize({...}, false)
  local pseudoheader_fname = 'tmp_pseudoheader.h'
  local pseudoheader_file = io.open(pseudoheader_fname, 'w')
  pseudoheader_file:write(previous_defines)
  pseudoheader_file:write("\n")
  pseudoheader_file:write(pseudoheader)
  pseudoheader_file:flush()
  pseudoheader_file:close()

  local defines = repeated_read_cmd(self.path, self.preprocessor_extra_flags,
                                    self.get_defines_extra_flags,
                                    {pseudoheader_fname})
  defines = self:filter_standard_defines(defines)

  -- lfs = require("lfs")
  -- print("CWD: #{lfs.currentdir!}")
  -- print("CMD: #{cmd}")
  -- io.stderr\write("CWD: #{lfs.currentdir!}\n")
  -- io.stderr\write("CMD: #{cmd}\n")

  local declarations = repeated_read_cmd(self.path,
                                         self.preprocessor_extra_flags,
                                         self.get_declarations_extra_flags,
                                         {pseudoheader_fname})

  os.remove(pseudoheader_fname)

  assert(declarations and defines)
  return declarations, defines
end

local Clang = Gcc:new()
local Msvc = Gcc:new()

local type_to_class = {
  ["gcc"] = Gcc,
  ["clang"] = Clang,
  ["msvc"] = Msvc
}

-- find the best cc. If os.exec causes problems on windows (like popping up
-- a console window) we might consider using something like this:
-- http://scite-ru.googlecode.com/svn/trunk/pack/tools/LuaLib/shell.html#exec
local function find_best_cc(compilers)
  for _, meta in pairs(compilers) do
    local version = io.popen(tostring(meta.path) .. " -v 2>&1")
    version:close()
    if version then
      return type_to_class[meta.type]:new({path = meta.path})
    end
  end
  return nil
end

-- find the best cc. If os.exec causes problems on windows (like popping up
-- a console window) we might consider using something like this:
-- http://scite-ru.googlecode.com/svn/trunk/pack/tools/LuaLib/shell.html#exec
local cc = nil
if cc == nil then
  cc = find_best_cc(ccs)
end

return {
  includes = function(hdr)
    return cc:dependencies(hdr)
  end,
  preprocess = function(...)
    return cc:preprocess(...)
  end,
  add_to_include_path = function(...)
    return cc:add_to_include_path(...)
  end
}
