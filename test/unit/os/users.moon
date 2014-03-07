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
int mch_get_user_name(char *s, size_t len);
int mch_get_uname(int uid, char *s, size_t len);
char *mch_get_user_directory(const char *name);
int getuid(void);
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

  -- will probably not work on windows
  current_username = os.getenv 'USER'

  describe 'mch_get_usernames', ->

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

  describe 'mch_get_user_name', ->

    it 'should write the username into the buffer and return OK', ->
      name_out = ffi.new 'char[100]'
      eq OK, users.mch_get_user_name(name_out, 100)
      eq current_username, ffi.string name_out

  describe 'mch_get_uname', ->

    it 'should write the username into the buffer and return OK', ->
      name_out = ffi.new 'char[100]'
      user_id = lib.getuid!
      eq OK, users.mch_get_uname(user_id, name_out, 100)
      eq current_username, ffi.string name_out

    it 'should FAIL if the userid is not found', ->
      name_out = ffi.new 'char[100]'
      -- hoping nobody has this uid
      user_id = 2342
      eq FAIL, users.mch_get_uname(user_id, name_out, 100)
      eq '2342', ffi.string name_out

  describe 'mch_get_user_directory', ->

    it 'should return NULL if called with NULL', ->
      eq NULL, users.mch_get_user_directory NULL

    it 'should return $HOME for the current user', ->
      home = os.getenv('HOME')
      eq home, ffi.string (users.mch_get_user_directory current_username)

    it 'should return NULL if the user is not found', ->
      eq NULL, users.mch_get_user_directory 'neovim_user_not_found_test'

