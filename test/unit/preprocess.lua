-- helps managing loading different headers into the LuaJIT ffi. Untested on
-- windows, will probably need quite a bit of adjustment to run there.

local ffi = require('ffi')
local global_t = require('test.testutil')

local argss_to_cmd = global_t.argss_to_cmd
local repeated_read_cmd = global_t.repeated_read_cmd

--- @alias Compiler {path: string[], type: string}

--- @type Compiler[]
local ccs = {}

local env_cc = os.getenv('CC')
if env_cc then
  table.insert(ccs, { path = { '/usr/bin/env', env_cc }, type = 'gcc' })
end

if ffi.os == 'Windows' then
  table.insert(ccs, { path = { 'cl' }, type = 'msvc' })
end

table.insert(ccs, { path = { '/usr/bin/env', 'cc' }, type = 'gcc' })
table.insert(ccs, { path = { '/usr/bin/env', 'gcc' }, type = 'gcc' })
table.insert(ccs, { path = { '/usr/bin/env', 'gcc-4.9' }, type = 'gcc' })
table.insert(ccs, { path = { '/usr/bin/env', 'gcc-4.8' }, type = 'gcc' })
table.insert(ccs, { path = { '/usr/bin/env', 'gcc-4.7' }, type = 'gcc' })
table.insert(ccs, { path = { '/usr/bin/env', 'clang' }, type = 'clang' })
table.insert(ccs, { path = { '/usr/bin/env', 'icc' }, type = 'gcc' })

-- parse Makefile format dependencies into a Lua table
--- @param deps string
--- @return string[]
local function parse_make_deps(deps)
  -- remove line breaks and line concatenators
  deps = deps:gsub('\n', ''):gsub('\\', '')
  -- remove the Makefile "target:" element
  deps = deps:gsub('.+:', '')
  -- remove redundant spaces
  deps = deps:gsub('  +', ' ')

  -- split according to token (space in this case)
  local headers = {} --- @type string[]
  for token in deps:gmatch('[^%s]+') do
    -- headers[token] = true
    headers[#headers + 1] = token
  end

  -- resolve path redirections (..) to normalize all paths
  for i, v in ipairs(headers) do
    -- double dots (..)
    headers[i] = v:gsub('/[^/%s]+/%.%.', '')
    -- single dot (.)
    headers[i] = v:gsub('%./', '')
  end

  return headers
end

--- will produce a string that represents a meta C header file that includes
--- all the passed in headers. I.e.:
---
--- headerize({"stdio.h", "math.h"}, true)
--- produces:
--- #include <stdio.h>
--- #include <math.h>
---
--- headerize({"vim_defs.h", "memory.h"}, false)
--- produces:
--- #include "vim_defs.h"
--- #include "memory.h"
--- @param headers string[]
--- @param global? boolean
--- @return string
local function headerize(headers, global)
  local fmt = global and '#include <%s>' or '#include "%s"'
  local formatted = {} --- @type string[]
  for _, hdr in ipairs(headers) do
    formatted[#formatted + 1] = string.format(fmt, hdr)
  end

  return table.concat(formatted, '\n')
end

--- @class Gcc
--- @field path string
--- @field preprocessor_extra_flags string[]
--- @field get_defines_extra_flags string[]
--- @field get_declarations_extra_flags string[]
local Gcc = {
  preprocessor_extra_flags = {},
  get_defines_extra_flags = { '-std=c99', '-dM', '-E' },
  get_declarations_extra_flags = { '-std=c99', '-P', '-E' },
}

--- @param name string
--- @param args string[]?
--- @param val string?
function Gcc:define(name, args, val)
  local define = string.format('-D%s', name)
  if args then
    define = string.format('%s(%s)', define, table.concat(args, ','))
  end
  if val then
    define = string.format('%s=%s', define, val)
  end
  self.preprocessor_extra_flags[#self.preprocessor_extra_flags + 1] = define
end

function Gcc:undefine(name)
  self.preprocessor_extra_flags[#self.preprocessor_extra_flags + 1] = '-U' .. name
end

function Gcc:init_defines()
  -- preprocessor flags that will hopefully make the compiler produce C
  -- declarations that the LuaJIT ffi understands.
  self:define('aligned', { 'ARGS' }, '')
  self:define('__attribute__', { 'ARGS' }, '')
  self:define('__asm', { 'ARGS' }, '')
  self:define('__asm__', { 'ARGS' }, '')
  self:define('__inline__', nil, '')
  self:define('EXTERN', nil, 'extern')
  self:define('INIT', { '...' }, '')
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

--- @param obj? Compiler
--- @return Gcc
function Gcc:new(obj)
  obj = obj or {}
  setmetatable(obj, self)
  self.__index = self
  self:init_defines()
  return obj
end

--- @param ... string
function Gcc:add_to_include_path(...)
  local ef = self.preprocessor_extra_flags
  for i = 1, select('#', ...) do
    local path = select(i, ...)
    ef[#ef + 1] = '-I' .. path
  end
end

function Gcc:add_apple_sysroot(sysroot)
  local ef = self.preprocessor_extra_flags

  table.insert(ef, '-isysroot')
  table.insert(ef, sysroot)
end

-- returns a list of the headers files upon which this file relies
--- @param hdr string
--- @return string[]?
function Gcc:dependencies(hdr)
  --- @type string
  local cmd = argss_to_cmd(self.path, { '-M', hdr }) .. ' 2>&1'
  local out = assert(io.popen(cmd))
  local deps = out:read('*a')
  out:close()
  if deps then
    return parse_make_deps(deps)
  end
end

--- @param defines string
--- @return string
function Gcc:filter_standard_defines(defines)
  if not self.standard_defines then
    local pseudoheader_fname = 'tmp_empty_pseudoheader.h'
    local pseudoheader_file = assert(io.open(pseudoheader_fname, 'w'))
    pseudoheader_file:close()
    local standard_defines = assert(
      repeated_read_cmd(
        self.path,
        self.preprocessor_extra_flags,
        self.get_defines_extra_flags,
        { pseudoheader_fname }
      )
    )
    os.remove(pseudoheader_fname)
    self.standard_defines = {} --- @type table<string,true>
    for line in standard_defines:gmatch('[^\n]+') do
      self.standard_defines[line] = true
    end
  end

  local ret = {} --- @type string[]
  for line in defines:gmatch('[^\n]+') do
    if not self.standard_defines[line] then
      ret[#ret + 1] = line
    end
  end

  return table.concat(ret, '\n')
end

--- returns a stream representing a preprocessed form of the passed-in headers.
--- Don't forget to close the stream by calling the close() method on it.
--- @param previous_defines string
--- @param ... string
--- @return string, string
function Gcc:preprocess(previous_defines, ...)
  -- create pseudo-header
  local pseudoheader = headerize({ ... }, false)
  local pseudoheader_fname = 'tmp_pseudoheader.h'
  local pseudoheader_file = assert(io.open(pseudoheader_fname, 'w'))
  pseudoheader_file:write(previous_defines)
  pseudoheader_file:write('\n')
  pseudoheader_file:write(pseudoheader)
  pseudoheader_file:flush()
  pseudoheader_file:close()

  local defines = assert(
    repeated_read_cmd(
      self.path,
      self.preprocessor_extra_flags,
      self.get_defines_extra_flags,
      { pseudoheader_fname }
    )
  )
  defines = self:filter_standard_defines(defines)

  local declarations = assert(
    repeated_read_cmd(
      self.path,
      self.preprocessor_extra_flags,
      self.get_declarations_extra_flags,
      { pseudoheader_fname }
    )
  )

  os.remove(pseudoheader_fname)

  return declarations, defines
end

-- find the best cc. If os.exec causes problems on windows (like popping up
-- a console window) we might consider using something like this:
-- http://scite-ru.googlecode.com/svn/trunk/pack/tools/LuaLib/shell.html#exec
--- @param compilers Compiler[]
--- @return Gcc?
local function find_best_cc(compilers)
  for _, meta in pairs(compilers) do
    local version = assert(io.popen(tostring(meta.path) .. ' -v 2>&1'))
    version:close()
    if version then
      return Gcc:new({ path = meta.path })
    end
  end
end

-- find the best cc. If os.exec causes problems on windows (like popping up
-- a console window) we might consider using something like this:
-- http://scite-ru.googlecode.com/svn/trunk/pack/tools/LuaLib/shell.html#exec
local cc = assert(find_best_cc(ccs))

local M = {}

--- @param hdr string
--- @return string[]?
function M.includes(hdr)
  return cc:dependencies(hdr)
end

--- @param ... string
--- @return string, string
function M.preprocess(...)
  return cc:preprocess(...)
end

--- @param ... string
function M.add_to_include_path(...)
  return cc:add_to_include_path(...)
end

--- @param ... string
function M.add_apple_sysroot(...)
  return cc:add_apple_sysroot(...)
end

return M
