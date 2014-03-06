{:cimport, :internalize, :eq, :ffi, :lib, :cstr} = require 'test.unit.helpers'

-- fs = cimport './src/os/os.h'
-- remove these statements once 'cimport' is working properly for misc1.h
users = lib
ffi.cdef [[
typedef struct growarray {
  int ga_len;
  int ga_maxlen;
  int ga_itemsize;
  int ga_growsize;
  void    *ga_data;
} garray_T;
int mch_get_usernames(garray_T *usernames);
]]

NULL = ffi.cast 'void*', 0
OK = 1
FAIL = 0

garray_new = () ->
  ffi.new 'garray_T[1]'

garray_get_len = (array) ->
  array[0].ga_len

garray_get_item = (array, index) ->
  (ffi.cast 'void **', array[0].ga_data)[index]


describe 'users function', ->

  describe 'mch_get_usernames', ->

    -- will probably not work on windows
    current_username = os.getenv 'USER'

    it 'returns FAIL if called with NULL', ->
      eq FAIL, users.mch_get_usernames NULL

    it 'fills the names garray with os usernames and returns OK', ->
      ga_users = garray_new!
      eq OK, users.mch_get_usernames ga_users
      user_count = garray_get_len ga_users
      assert.is_true user_count > 0
      current_username_found = false
      for i = 0, user_count - 1
        name = ffi.string (garray_get_item ga_users, i)
        if name == current_username
          current_username_found = true
      assert.is_true current_username_found

