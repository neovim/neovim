-- Modules loaded here will not be cleared and reloaded by the local harness.
-- Keeping these preloaded preserves cross-file setup while still resetting
-- non-helper modules between files.
local t = require('test.testutil')
require('test.functional.testnvim')()
require('test.functional.ui.screen')

local has_ffi, ffi = pcall(require, 'ffi')
if t.is_os('win') and has_ffi then
  ffi.cdef [[
  typedef int errno_t;
  errno_t _set_fmode(int mode);
  ]]
  ffi.C._set_fmode(0x8000)
end
