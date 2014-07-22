{:cimport, :internalize, :eq, :ffi, :lib, :cstr, :NULL, :OK, :FAIL} = require 'test.unit.helpers'

users = cimport './src/nvim/os/os.h', 'unistd.h'

garray_new = () ->
  ffi.new 'garray_T[1]'

garray_get_len = (array) ->
  array[0].ga_len

garray_get_item = (array, index) ->
  (ffi.cast 'void **', array[0].ga_data)[index]


describe 'users function', ->

  -- will probably not work on windows
  current_username = os.getenv 'USER'

  describe 'os_get_usernames', ->

    it 'returns FAIL if called with NULL', ->
      eq FAIL, users.os_get_usernames NULL

    it 'fills the names garray with os usernames and returns OK', ->
      ga_users = garray_new!
      eq OK, users.os_get_usernames ga_users
      user_count = garray_get_len ga_users
      assert.is_true user_count > 0
      current_username_found = false
      for i = 0, user_count - 1
        name = ffi.string (garray_get_item ga_users, i)
        if name == current_username
          current_username_found = true
      assert.is_true current_username_found

  describe 'os_get_user_name', ->

    it 'should write the username into the buffer and return OK', ->
      name_out = ffi.new 'char[100]'
      eq OK, users.os_get_user_name(name_out, 100)
      eq current_username, ffi.string name_out

  describe 'os_get_uname', ->

    it 'should write the username into the buffer and return OK', ->
      name_out = ffi.new 'char[100]'
      user_id = lib.getuid!
      eq OK, users.os_get_uname(user_id, name_out, 100)
      eq current_username, ffi.string name_out

    it 'should FAIL if the userid is not found', ->
      name_out = ffi.new 'char[100]'
      -- hoping nobody has this uid
      user_id = 2342
      eq FAIL, users.os_get_uname(user_id, name_out, 100)
      eq '2342', ffi.string name_out

  describe 'os_get_user_directory', ->

    it 'should return NULL if called with NULL', ->
      eq NULL, users.os_get_user_directory NULL

    it 'should return $HOME for the current user', ->
      home = os.getenv('HOME')
      eq home, ffi.string (users.os_get_user_directory current_username)

    it 'should return NULL if the user is not found', ->
      eq NULL, users.os_get_user_directory 'neovim_user_not_found_test'

