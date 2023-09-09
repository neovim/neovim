-- Tests for misc Vimscript |builtin-functions|.
--
-- If a function is non-trivial, consider moving its spec to:
--    test/functional/vimscript/<funcname>_spec.lua
--
-- Core "eval" tests live in eval_spec.lua.

local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eval = helpers.eval
local matches = helpers.matches
local is_os = helpers.is_os

before_each(clear)

it('windowsversion()', function()
  clear()
  matches(is_os('win') and '^%d+%.%d+$' or '^$', eval('windowsversion()'))
end)
