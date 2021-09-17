-- Tests for misc Vimscript |functions|.
--
-- If a function is non-trivial, consider moving its spec to:
--    test/functional/vimscript/<funcname>_spec.lua
--
-- Core "eval" tests live in eval_spec.lua.

local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eval = helpers.eval
local iswin = helpers.iswin
local matches = helpers.matches

before_each(clear)

it('windowsversion()', function()
  clear()
  matches(iswin() and '^%d+%.%d+$' or '^$', eval('windowsversion()'))
end)
