{:cimport, :internalize, :eq, :neq, :ffi, :lib, :cstr, :to_cstr, :NULL} = require 'test.unit.helpers'

garray = cimport './src/nvim/garray.h'

-- define a basic interface to garray. We could make it a lot nicer by
-- constructing a moonscript class wrapper around garray. It could for
-- example associate ga_clear_strings to the underlying garray cdata if the
-- garray is a string array. But for now I estimate that that kind of magic
-- might make testing less "transparant" (i.e.: the interface would become
-- quite different as to how one would use it from C.

-- accessors
ga_len = (garr) ->
  garr[0].ga_len
ga_maxlen = (garr) ->
  garr[0].ga_maxlen
ga_itemsize = (garr) ->
  garr[0].ga_itemsize
ga_growsize = (garr) ->
  garr[0].ga_growsize
ga_data = (garr) ->
  garr[0].ga_data

-- derived accessors
ga_size = (garr) ->
  ga_len(garr) * ga_itemsize(garr)
ga_maxsize = (garr) ->
  ga_maxlen(garr) * ga_itemsize(garr)
ga_data_as_bytes = (garr) ->
  ffi.cast('uint8_t *', ga_data(garr))
ga_data_as_strings = (garr) ->
  ffi.cast('char **', ga_data(garr))
ga_data_as_ints = (garr) ->
  ffi.cast('int *', ga_data(garr))

-- garray manipulation
ga_init = (garr, itemsize, growsize) ->
  garray.ga_init(garr, itemsize, growsize)
ga_clear = (garr) ->
  garray.ga_clear(garr)
ga_clear_strings = (garr) ->
  assert.is_true(ga_itemsize(garr) == ffi.sizeof('char *'))
  garray.ga_clear_strings(garr)
ga_grow = (garr, n) ->
  garray.ga_grow(garr, n)
ga_concat = (garr, str) ->
  garray.ga_concat(garr, to_cstr(str))
ga_append = (garr, b) ->
  if type(b) == 'string'
    garray.ga_append(garr, string.byte(b))
  else
    garray.ga_append(garr, b)
ga_concat_strings = (garr) ->
  internalize(garray.ga_concat_strings(garr))
ga_concat_strings_sep = (garr, sep) ->
  internalize(garray.ga_concat_strings_sep(garr, to_cstr(sep)))
ga_remove_duplicate_strings = (garr) ->
  garray.ga_remove_duplicate_strings(garr)

-- derived manipulators
ga_set_len = (garr, len) ->
  assert.is_true(len <= ga_maxlen(garr))
  garr[0].ga_len = len
ga_inc_len = (garr, by) ->
  ga_set_len(garr, ga_len(garr) + 1)

-- custom append functions
-- not the C ga_append, which only works for bytes
ga_append_int = (garr, it) ->
  assert.is_true(ga_itemsize(garr) == ffi.sizeof('int'))

  ga_grow(garr, 1)
  data = ga_data_as_ints(garr)
  data[ga_len(garr)] = it
  ga_inc_len(garr, 1)
ga_append_string = (garr, it) ->
  assert.is_true(ga_itemsize(garr) == ffi.sizeof('char *'))

  -- make a non-garbage collected string and copy the lua string into it,
  -- TODO(aktau): we should probably call xmalloc here, though as long as
  -- xmalloc is based on malloc it should work.
  mem = ffi.C.malloc(string.len(it) + 1)
  ffi.copy(mem, it)

  ga_grow(garr, 1)
  data = ga_data_as_strings(garr)
  data[ga_len(garr)] = mem
  ga_inc_len(garr, 1)
ga_append_strings = (garr, ...) ->
  prevlen = ga_len(garr)
  len = select('#', ...)
  for i = 1, len
    ga_append_string(garr, select(i, ...))
  eq prevlen + len, ga_len(garr)
ga_append_ints = (garr, ...) ->
  prevlen = ga_len(garr)
  len = select('#', ...)
  for i = 1, len
    ga_append_int(garr, select(i, ...))
  eq prevlen + len, ga_len(garr)

-- enhanced constructors
garray_ctype = ffi.typeof('garray_T[1]')
new_garray = ->
  garr = garray_ctype()
  ffi.gc(garr, ga_clear)
new_string_garray = ->
  garr = garray_ctype()
  ga_init(garr, ffi.sizeof("char_u *"), 1)
  ffi.gc(garr, ga_clear_strings)

randomByte = ->
  ffi.cast('uint8_t', math.random(0, 255))

-- scramble the data in a garray
ga_scramble = (garr) ->
  size, bytes = ga_size(garr), ga_data_as_bytes(garr)

  for i = 0, size - 1
    bytes[i] = randomByte()

describe 'garray', ->
  itemsize = 14
  growsize = 95

  describe 'ga_init', ->
    it 'initializes the values of the garray', ->
      garr = new_garray()
      ga_init(garr, itemsize, growsize)
      eq 0, ga_len(garr)
      eq 0, ga_maxlen(garr)
      eq growsize, ga_growsize(garr)
      eq itemsize, ga_itemsize(garr)
      eq NULL, ga_data(garr)

  describe 'ga_grow', ->
    new_and_grow = (itemsize, growsize, req) ->
      garr = new_garray()
      ga_init(garr, itemsize, growsize)

      eq 0, ga_size(garr)       -- should be 0 at first
      eq NULL, ga_data(garr)    -- should be NULL
      ga_grow(garr, req)        -- add space for `req` items

      garr

    it 'grows by growsize items if num < growsize', ->
      itemsize = 16
      growsize = 4
      grow_by = growsize - 1
      garr = new_and_grow(itemsize, growsize, grow_by)
      neq NULL, ga_data(garr)      -- data should be a ptr to memory
      eq growsize, ga_maxlen(garr) -- we requested LESS than growsize, so...

    it 'grows by num items if num > growsize', ->
      itemsize = 16
      growsize = 4
      grow_by = growsize + 1
      garr = new_and_grow(itemsize, growsize, grow_by)
      neq NULL, ga_data(garr)      -- data should be a ptr to memory
      eq grow_by, ga_maxlen(garr)  -- we requested MORE than growsize, so...

    it 'does not grow when nothing is requested', ->
      garr = new_and_grow(16, 4, 0)
      eq NULL, ga_data(garr)
      eq 0, ga_maxlen(garr)

  describe 'ga_clear', ->
    it 'clears an already allocated array', ->
      -- allocate and scramble an array
      garr = garray_ctype()
      ga_init(garr, itemsize, growsize)
      ga_grow(garr, 4)
      ga_set_len(garr, 4)
      ga_scramble(garr)

      -- clear it and check
      ga_clear(garr)
      eq NULL, ga_data(garr)
      eq 0, ga_maxlen(garr)
      eq 0, ga_len(garr)

  describe 'ga_append', ->
    it 'can append bytes', ->
      -- this is the actual ga_append, the others are just emulated lua
      -- versions
      garr = new_garray()
      ga_init(garr, ffi.sizeof("uint8_t"), 1)
      ga_append(garr, 'h')
      ga_append(garr, 'e')
      ga_append(garr, 'l')
      ga_append(garr, 'l')
      ga_append(garr, 'o')
      ga_append(garr, 0)
      bytes = ga_data_as_bytes(garr)
      eq 'hello', ffi.string(bytes)

    it 'can append integers', ->
      garr = new_garray()
      ga_init(garr, ffi.sizeof("int"), 1)
      input = {-20, 94, 867615, 90927, 86}
      ga_append_ints(garr, unpack(input))

      ints = ga_data_as_ints(garr)
      for i = 0, #input - 1
        eq input[i+1], ints[i]

    it 'can append strings to a growing array of strings', ->
      garr = new_string_garray()
      input = {"some", "str", "\r\n\r●●●●●●,,,", "hmm", "got it"}
      ga_append_strings(garr, unpack(input))

      -- check that we can get the same strings out of the array
      strings = ga_data_as_strings(garr)
      for i = 0, #input - 1
        eq input[i+1], ffi.string(strings[i])

  describe 'ga_concat', ->
    it 'concatenates the parameter to the growing byte array', ->
      garr = new_garray()
      ga_init(garr, ffi.sizeof("char"), 1)

      str = "ohwell●●"
      loop = 5
      for i = 1, loop
        ga_concat(garr, str)

      -- ga_concat does NOT append the NUL in the src string to the
      -- destination, you have to do that manually by calling something like
      -- ga_append(gar, '\0'). I'ts always used like that in the vim
      -- codebase. I feel that this is a bit of an unnecesesary
      -- micro-optimization.
      ga_append(garr, 0)

      result = ffi.string(ga_data_as_bytes(garr))
      eq string.rep(str, loop), result

  test_concat_fn = (input, fn, sep) ->
    garr = new_string_garray()
    ga_append_strings(garr, unpack(input))
    if sep == nil
      eq table.concat(input, ','), fn(garr)
    else
      eq table.concat(input, sep), fn(garr, sep)

  describe 'ga_concat_strings', ->
    it 'returns an empty string when concatenating an empty array', ->
      test_concat_fn({}, ga_concat_strings)
    it 'can concatenate a non-empty array', ->
      test_concat_fn({'oh', 'my', 'neovim'}, ga_concat_strings)

  describe 'ga_concat_strings_sep', ->
    it 'returns an empty string when concatenating an empty array', ->
      test_concat_fn({}, ga_concat_strings_sep, '---')
    it 'can concatenate a non-empty array', ->
      sep = '-●●-'
      test_concat_fn({'oh', 'my', 'neovim'}, ga_concat_strings_sep, sep)

  describe 'ga_remove_duplicate_strings', ->
    it 'sorts and removes duplicate strings', ->
      garr = new_string_garray()
      input = {'ccc', 'aaa', 'bbb', 'ddd●●', 'aaa', 'bbb', 'ccc', 'ccc', 'ddd●●'}
      sorted_dedup_input = {'aaa', 'bbb', 'ccc', 'ddd●●'}

      ga_append_strings(garr, unpack(input))
      ga_remove_duplicate_strings(garr)
      eq #sorted_dedup_input, ga_len(garr)

      strings = ga_data_as_strings(garr)
      for i = 0, #sorted_dedup_input - 1
        eq sorted_dedup_input[i+1], ffi.string(strings[i])
