local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local cimport = t.cimport
local eq = t.eq
local ffi = t.ffi
local lib = t.lib
local NULL = t.NULL
local OK = t.OK
local FAIL = t.FAIL

local users = cimport('./src/nvim/os/os.h', 'unistd.h')

local function garray_new()
  return ffi.new('garray_T[1]')
end

local function garray_get_len(array)
  return array[0].ga_len
end

local function garray_get_item(array, index)
  return (ffi.cast('void **', array[0].ga_data))[index]
end

describe('users function', function()
  -- will probably not work on windows
  local current_username = os.getenv('USER')

  describe('os_get_usernames', function()
    itp('returns FAIL if called with NULL', function()
      eq(FAIL, users.os_get_usernames(NULL))
    end)

    itp('fills the names garray with os usernames and returns OK', function()
      local ga_users = garray_new()
      eq(OK, users.os_get_usernames(ga_users))
      local user_count = garray_get_len(ga_users)
      assert.is_true(user_count > 0)
      local current_username_found = false
      for i = 0, user_count - 1 do
        local name = ffi.string((garray_get_item(ga_users, i)))
        if name == current_username then
          current_username_found = true
        end
      end
      assert.is_true(current_username_found)
    end)
  end)

  describe('os_get_username', function()
    itp('should write the username into the buffer and return OK', function()
      local name_out = ffi.new('char[100]')
      eq(OK, users.os_get_username(name_out, 100))
      eq(current_username, ffi.string(name_out))
    end)
  end)

  describe('os_get_uname', function()
    itp('should write the username into the buffer and return OK', function()
      local name_out = ffi.new('char[100]')
      local user_id = lib.getuid()
      eq(OK, users.os_get_uname(user_id, name_out, 100))
      eq(current_username, ffi.string(name_out))
    end)

    itp('should FAIL if the userid is not found', function()
      local name_out = ffi.new('char[100]')
      -- hoping nobody has this uid
      local user_id = 2342
      eq(FAIL, users.os_get_uname(user_id, name_out, 100))
      eq('2342', ffi.string(name_out))
    end)
  end)

  describe('os_get_userdir', function()
    itp('should return NULL if called with NULL', function()
      eq(NULL, users.os_get_userdir(NULL))
    end)

    itp('should return $HOME for the current user', function()
      local home = os.getenv('HOME')
      eq(home, ffi.string((users.os_get_userdir(current_username))))
    end)

    itp('should return NULL if the user is not found', function()
      eq(NULL, users.os_get_userdir('neovim_user_not_found_test'))
    end)
  end)
end)
