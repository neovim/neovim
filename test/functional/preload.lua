-- Modules loaded here will NOT be cleared and reloaded by Busted.
-- Busted started doing this to help provide more isolation.  See issue #62
-- for more information about this.
local t = require('test.functional.testutil')(nil)
require('test.functional.ui.screen')
local busted = require('busted')
local is_os = t.is_os

if is_os('win') then
  local ffi = require('ffi')
  ffi.cdef [[
  typedef int errno_t;
  errno_t _set_fmode(int mode);
  ]]
  ffi.C._set_fmode(0x8000)
end

local testid = (function()
  local id = 0
  return function()
    id = id + 1
    return id
  end
end)()

-- Global before_each. https://github.com/Olivine-Labs/busted/issues/613
local function before_each(_element, _parent)
  local id = ('T%d'):format(testid())
  _G._nvim_test_id = id
  return nil, true
end
busted.subscribe({ 'test', 'start' }, before_each, {
  -- Ensure our --helper is handled before --output (see busted/runner.lua).
  priority = 1,
  -- Don't generate a test-id for skipped tests. /shrug
  predicate = function(element, _, status)
    return not (element.descriptor == 'pending' or status == 'pending')
  end,
})
