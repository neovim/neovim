-- Modules loaded here will NOT be cleared and reloaded by Busted.
-- Busted started doing this to help provide more isolation.  See issue #62
-- for more information about this.
local t = require('test.functional.testutil')()
require('test.functional.ui.screen')
local is_os = t.is_os

if is_os('win') then
  local ffi = require('ffi')
  ffi.cdef [[
  typedef int errno_t;
  errno_t _set_fmode(int mode);
  ]]
  ffi.C._set_fmode(0x8000)
end
