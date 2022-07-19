-- Modules loaded here will NOT be cleared and reloaded by Busted.
-- Busted started doing this to help provide more isolation.  See issue #62
-- for more information about this.
local helpers = require('test.functional.helpers')(nil)
local iswin = helpers.iswin
local busted = require("busted")

if iswin() then
  local ffi = require('ffi')
  ffi.cdef[[
  typedef int errno_t;
  errno_t _set_fmode(int mode);
  ]]
  ffi.C._set_fmode(0x8000)
end
