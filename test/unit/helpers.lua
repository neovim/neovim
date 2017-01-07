local ffi = require('ffi')
local formatc = require('test.unit.formatc')
local Set = require('test.unit.set')
local Preprocess = require('test.unit.preprocess')
local Paths = require('test.config.paths')
local global_helpers = require('test.helpers')

local neq = global_helpers.neq
local eq = global_helpers.eq
local ok = global_helpers.ok

-- C constants.
local NULL = ffi.cast('void*', 0)

local OK = 1
local FAIL = 0

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
local cdefs = Set:new()
local imported = Set:new()
local pragma_pack_id = 1

-- some things are just too complex for the LuaJIT C parser to digest. We
-- usually don't need them anyway.
local function filter_complex_blocks(body)
  local result = {}

  for line in body:gmatch("[^\r\n]+") do
    if not (string.find(line, "(^)", 1, true) ~= nil
            or string.find(line, "_ISwupper", 1, true)
            or string.find(line, "msgpack_zone_push_finalizer")
            or string.find(line, "msgpack_unpacker_reserve_buffer")
            or string.find(line, "UUID_NULL")  -- static const uuid_t UUID_NULL = {...}
            or string.find(line, "inline _Bool")) then
      result[#result + 1] = line
    end
  end

  return table.concat(result, "\n")
end

local previous_defines = ''

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

  local body
  body, previous_defines = Preprocess.preprocess(previous_defines, unpack(paths))

  -- format it (so that the lines are "unique" statements), also filter out
  -- Objective-C blocks
  body = formatc(body)
  body = filter_complex_blocks(body)

  -- add the formatted lines to a set
  local new_cdefs = Set:new()
  for line in body:gmatch("[^\r\n]+") do
    line = trim(line)
    -- give each #pragma pack an unique id, so that they don't get removed
    -- if they are inserted into the set
    -- (they are needed in the right order with the struct definitions,
    -- otherwise luajit has wrong memory layouts for the sturcts)
    if line:match("#pragma%s+pack") then
      line = line .. " // " .. pragma_pack_id
      pragma_pack_id = pragma_pack_id + 1
    end
    new_cdefs:add(line)
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
  if os.getenv('NVIM_TEST_PRINT_CDEF') == '1' then
    for lnum, line in ipairs(new_lines) do
      print(lnum, line)
    end
  end
  ffi.cdef(table.concat(new_lines, "\n"))

  return libnvim
end

local function cppimport(path)
  return cimport(Paths.test_include_path .. '/' .. path)
end

local function alloc_log_new()
  local log = {
    log={},
    lib=cimport('./src/nvim/memory.h'),
    original_functions={},
    null={['\0:is_null']=true},
  }
  local allocator_functions = {'malloc', 'free', 'calloc', 'realloc'}
  function log:save_original_functions()
    for _, funcname in ipairs(allocator_functions) do
      self.original_functions[funcname] = self.lib['mem_' .. funcname]
    end
  end
  function log:set_mocks()
    for _, k in ipairs(allocator_functions) do
      do
        local kk = k
        self.lib['mem_' .. k] = function(...)
          local log_entry = {func=kk, args={...}}
          self.log[#self.log + 1] = log_entry
          if kk == 'free' then
            self.original_functions[kk](...)
          else
            log_entry.ret = self.original_functions[kk](...)
          end
          for i, v in ipairs(log_entry.args) do
            if v == nil then
              -- XXX This thing thinks that {NULL} ~= {NULL}.
              log_entry.args[i] = self.null
            end
          end
          if self.hook then self:hook(log_entry) end
          if log_entry.ret then
            return log_entry.ret
          end
        end
      end
    end
  end
  function log:clear()
    self.log = {}
  end
  function log:check(exp)
    eq(exp, self.log)
    self:clear()
  end
  function log:restore_original_functions()
    for k, v in pairs(self.original_functions) do
      self.lib['mem_' .. k] = v
    end
  end
  function log:before_each()
    log:save_original_functions()
    log:set_mocks()
  end
  function log:after_each()
    log:restore_original_functions()
  end
  return log
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
  return cstr(#string + 1, string)
end

-- initialize some global variables, this is still necessary to unit test
-- functions that rely on global state.
do
  local main = cimport('./src/nvim/main.h')
  local time = cimport('./src/nvim/os/time.h')
  time.time_init()
  main.early_init()
  main.event_init()
end

return {
  cimport = cimport,
  cppimport = cppimport,
  internalize = internalize,
  ok = ok,
  eq = eq,
  neq = neq,
  ffi = ffi,
  lib = libnvim,
  cstr = cstr,
  to_cstr = to_cstr,
  NULL = NULL,
  OK = OK,
  FAIL = FAIL,
  alloc_log_new = alloc_log_new,
}
