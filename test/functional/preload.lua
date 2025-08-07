-- Modules loaded here will NOT be cleared and reloaded by Busted.
-- Busted started doing this to help provide more isolation.  See issue #62
-- for more information about this.
local t = require('test.testutil')
require('test.functional.ui.screen')

local has_ffi, ffi = pcall(require, 'ffi')
if t.is_os('win') and has_ffi then
  ffi.cdef [[
  typedef int errno_t;
  errno_t _set_fmode(int mode);
  ]]
  ffi.C._set_fmode(0x8000)
end
