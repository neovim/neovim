local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local cimport = t.cimport
local internalize = t.internalize
local eq = t.eq
local neq = t.neq
local ffi = t.ffi
local to_cstr = t.to_cstr
local NULL = t.NULL

local garray = cimport('./src/nvim/garray.h')

local itemsize = 14
local growsize = 95

-- define a basic interface to garray. We could make it a lot nicer by
-- constructing a class wrapper around garray. It could for example associate
-- ga_clear_strings to the underlying garray cdata if the garray is a string
-- array. But for now I estimate that that kind of magic might make testing
-- less "transparent" (i.e.: the interface would become quite different as to
-- how one would use it from C.

-- accessors
local ga_len = function(garr)
  return garr[0].ga_len
end

local ga_maxlen = function(garr)
  return garr[0].ga_maxlen
end

local ga_itemsize = function(garr)
  return garr[0].ga_itemsize
end

local ga_growsize = function(garr)
  return garr[0].ga_growsize
end

local ga_data = function(garr)
  return garr[0].ga_data
end

-- derived accessors
local ga_size = function(garr)
  return ga_len(garr) * ga_itemsize(garr)
end

local ga_maxsize = function(garr) -- luacheck: ignore
  return ga_maxlen(garr) * ga_itemsize(garr)
end

local ga_data_as_bytes = function(garr)
  return ffi.cast('uint8_t *', ga_data(garr))
end

local ga_data_as_strings = function(garr)
  return ffi.cast('char **', ga_data(garr))
end

local ga_data_as_ints = function(garr)
  return ffi.cast('int *', ga_data(garr))
end

-- garray manipulation
local ga_init = function(garr, itemsize_, growsize_)
  return garray.ga_init(garr, itemsize_, growsize_)
end

local ga_clear = function(garr)
  return garray.ga_clear(garr)
end

local ga_clear_strings = function(garr)
  assert.is_true(ga_itemsize(garr) == ffi.sizeof('char *'))
  return garray.ga_clear_strings(garr)
end

local ga_grow = function(garr, n)
  return garray.ga_grow(garr, n)
end

local ga_concat = function(garr, str)
  return garray.ga_concat(garr, to_cstr(str))
end

local ga_append = function(garr, b)
  if type(b) == 'string' then
    return garray.ga_append(garr, string.byte(b))
  else
    return garray.ga_append(garr, b)
  end
end

local ga_concat_strings = function(garr)
  return internalize(garray.ga_concat_strings(garr))
end

local ga_concat_strings_sep = function(garr, sep)
  return internalize(garray.ga_concat_strings_sep(garr, to_cstr(sep)))
end

local ga_remove_duplicate_strings = function(garr)
  return garray.ga_remove_duplicate_strings(garr)
end

-- derived manipulators
local ga_set_len = function(garr, len)
  assert.is_true(len <= ga_maxlen(garr))
  garr[0].ga_len = len
end

local ga_inc_len = function(garr, by)
  return ga_set_len(garr, ga_len(garr) + by)
end

-- custom append functions
-- not the C ga_append, which only works for bytes
local ga_append_int = function(garr, it)
  assert.is_true(ga_itemsize(garr) == ffi.sizeof('int'))
  ga_grow(garr, 1)
  local data = ga_data_as_ints(garr)
  data[ga_len(garr)] = it
  return ga_inc_len(garr, 1)
end

local ga_append_string = function(garr, it)
  assert.is_true(ga_itemsize(garr) == ffi.sizeof('char *'))
  -- make a non-garbage collected string and copy the lua string into it,
  -- TODO(aktau): we should probably call xmalloc here, though as long as
  -- xmalloc is based on malloc it should work.
  local mem = ffi.C.malloc(string.len(it) + 1)
  ffi.copy(mem, it)
  ga_grow(garr, 1)
  local data = ga_data_as_strings(garr)
  data[ga_len(garr)] = mem
  return ga_inc_len(garr, 1)
end

local ga_append_strings = function(garr, ...)
  local prevlen = ga_len(garr)
  local len = select('#', ...)
  for i = 1, len do
    ga_append_string(garr, select(i, ...))
  end
  return eq(prevlen + len, ga_len(garr))
end

local ga_append_ints = function(garr, ...)
  local prevlen = ga_len(garr)
  local len = select('#', ...)
  for i = 1, len do
    ga_append_int(garr, select(i, ...))
  end
  return eq(prevlen + len, ga_len(garr))
end

-- enhanced constructors
local garray_ctype = function(...)
  return ffi.typeof('garray_T[1]')(...)
end
local new_garray = function()
  local garr = garray_ctype()
  return ffi.gc(garr, ga_clear)
end

local new_string_garray = function()
  local garr = garray_ctype()
  ga_init(garr, ffi.sizeof('unsigned char *'), 1)
  return ffi.gc(garr, ga_clear_strings)
end

local randomByte = function()
  return ffi.cast('uint8_t', math.random(0, 255))
end

-- scramble the data in a garray
local ga_scramble = function(garr)
  local size, bytes = ga_size(garr), ga_data_as_bytes(garr)
  for i = 0, size - 1 do
    bytes[i] = randomByte()
  end
end

describe('garray', function()
  describe('ga_init', function()
    itp('initializes the values of the garray', function()
      local garr = new_garray()
      ga_init(garr, itemsize, growsize)
      eq(0, ga_len(garr))
      eq(0, ga_maxlen(garr))
      eq(growsize, ga_growsize(garr))
      eq(itemsize, ga_itemsize(garr))
      eq(NULL, ga_data(garr))
    end)
  end)

  describe('ga_grow', function()
    local function new_and_grow(itemsize_, growsize_, req)
      local garr = new_garray()
      ga_init(garr, itemsize_, growsize_)
      eq(0, ga_size(garr)) -- should be 0 at first
      eq(NULL, ga_data(garr)) -- should be NULL
      ga_grow(garr, req) -- add space for `req` items
      return garr
    end

    itp('grows by growsize items if num < growsize', function()
      itemsize = 16
      growsize = 4
      local grow_by = growsize - 1
      local garr = new_and_grow(itemsize, growsize, grow_by)
      neq(NULL, ga_data(garr)) -- data should be a ptr to memory
      eq(growsize, ga_maxlen(garr)) -- we requested LESS than growsize, so...
    end)

    itp('grows by num items if num > growsize', function()
      itemsize = 16
      growsize = 4
      local grow_by = growsize + 1
      local garr = new_and_grow(itemsize, growsize, grow_by)
      neq(NULL, ga_data(garr)) -- data should be a ptr to memory
      eq(grow_by, ga_maxlen(garr)) -- we requested MORE than growsize, so...
    end)

    itp('does not grow when nothing is requested', function()
      local garr = new_and_grow(16, 4, 0)
      eq(NULL, ga_data(garr))
      eq(0, ga_maxlen(garr))
    end)
  end)

  describe('ga_clear', function()
    itp('clears an already allocated array', function()
      -- allocate and scramble an array
      local garr = garray_ctype()
      ga_init(garr, itemsize, growsize)
      ga_grow(garr, 4)
      ga_set_len(garr, 4)
      ga_scramble(garr)

      -- clear it and check
      ga_clear(garr)
      eq(NULL, ga_data(garr))
      eq(0, ga_maxlen(garr))
      eq(0, ga_len(garr))
    end)
  end)

  describe('ga_append', function()
    itp('can append bytes', function()
      -- this is the actual ga_append, the others are just emulated lua
      -- versions
      local garr = new_garray()
      ga_init(garr, ffi.sizeof('uint8_t'), 1)
      ga_append(garr, 'h')
      ga_append(garr, 'e')
      ga_append(garr, 'l')
      ga_append(garr, 'l')
      ga_append(garr, 'o')
      ga_append(garr, 0)
      local bytes = ga_data_as_bytes(garr)
      eq('hello', ffi.string(bytes))
    end)

    itp('can append integers', function()
      local garr = new_garray()
      ga_init(garr, ffi.sizeof('int'), 1)
      local input = {
        -20,
        94,
        867615,
        90927,
        86,
      }
      ga_append_ints(garr, unpack(input))
      local ints = ga_data_as_ints(garr)
      for i = 0, #input - 1 do
        eq(input[i + 1], ints[i])
      end
    end)

    itp('can append strings to a growing array of strings', function()
      local garr = new_string_garray()
      local input = {
        'some',
        'str',
        '\r\n\r●●●●●●,,,',
        'hmm',
        'got it',
      }
      ga_append_strings(garr, unpack(input))
      -- check that we can get the same strings out of the array
      local strings = ga_data_as_strings(garr)
      for i = 0, #input - 1 do
        eq(input[i + 1], ffi.string(strings[i]))
      end
    end)
  end)

  describe('ga_concat', function()
    itp('concatenates the parameter to the growing byte array', function()
      local garr = new_garray()
      ga_init(garr, ffi.sizeof('char'), 1)
      local str = 'ohwell●●'
      local loop = 5
      for _ = 1, loop do
        ga_concat(garr, str)
      end

      -- ga_concat does NOT append the NUL in the src string to the
      -- destination, you have to do that manually by calling something like
      -- ga_append(gar, '\0'). I'ts always used like that in the vim
      -- codebase. I feel that this is a bit of an unnecesesary
      -- micro-optimization.
      ga_append(garr, 0)
      local result = ffi.string(ga_data_as_bytes(garr))
      eq(string.rep(str, loop), result)
    end)
  end)

  local function test_concat_fn(input, fn, sep)
    local garr = new_string_garray()
    ga_append_strings(garr, unpack(input))
    if sep == nil then
      eq(table.concat(input, ','), fn(garr))
    else
      eq(table.concat(input, sep), fn(garr, sep))
    end
  end

  describe('ga_concat_strings', function()
    itp('returns an empty string when concatenating an empty array', function()
      test_concat_fn({}, ga_concat_strings)
    end)

    itp('can concatenate a non-empty array', function()
      test_concat_fn({
        'oh',
        'my',
        'neovim',
      }, ga_concat_strings)
    end)
  end)

  describe('ga_concat_strings_sep', function()
    itp('returns an empty string when concatenating an empty array', function()
      test_concat_fn({}, ga_concat_strings_sep, '---')
    end)

    itp('can concatenate a non-empty array', function()
      local sep = '-●●-'
      test_concat_fn({
        'oh',
        'my',
        'neovim',
      }, ga_concat_strings_sep, sep)
    end)
  end)

  describe('ga_remove_duplicate_strings', function()
    itp('sorts and removes duplicate strings', function()
      local garr = new_string_garray()
      local input = {
        'ccc',
        'aaa',
        'bbb',
        'ddd●●',
        'aaa',
        'bbb',
        'ccc',
        'ccc',
        'ddd●●',
      }
      local sorted_dedup_input = {
        'aaa',
        'bbb',
        'ccc',
        'ddd●●',
      }
      ga_append_strings(garr, unpack(input))
      ga_remove_duplicate_strings(garr)
      eq(#sorted_dedup_input, ga_len(garr))
      local strings = ga_data_as_strings(garr)
      for i = 0, #sorted_dedup_input - 1 do
        eq(sorted_dedup_input[i + 1], ffi.string(strings[i]))
      end
    end)
  end)
end)
