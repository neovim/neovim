local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local M = {}

---@type vim.elisp.F
local F = {}
local function make_lisp_time(seconds, nanoseconds)
  if lisp.nilp(vars.V.current_time_list) then
    error('TODO')
  else
    local hi_time = lisp.make_fixnum(bit.rshift(seconds, 16))
    local lo_time = lisp.make_fixnum(seconds % (bit.lshift(1, 16)))
    assert(nanoseconds == 0, 'TODO')
    return lisp.list(hi_time, lo_time, lisp.make_fixnum(0), lisp.make_fixnum(0))
  end
end
F.current_time = {
  'current-time',
  0,
  0,
  0,
  [[Return the current time, as the number of seconds since 1970-01-01 00:00:00.
If the variable `current-time-list' is nil, the time is returned as a
pair of integers (TICKS . HZ), where TICKS counts clock ticks and HZ
is the clock ticks per second.  Otherwise, the time is returned as a
list of integers (HIGH LOW USEC PSEC) where HIGH has the most
significant bits of the seconds, LOW has the least significant 16
bits, and USEC and PSEC are the microsecond and picosecond counts.

You can use `time-convert' to get a particular timestamp form
regardless of the value of `current-time-list'.]],
}
function F.current_time.f()
  return make_lisp_time(os.time(), 0)
end

function M.init_syms()
  vars.defsubr(F, 'current_time')

  vars.defvar_bool(
    'current_time_list',
    'current-time-list',
    [[Whether `current-time' should return list or (TICKS . HZ) form.

This boolean variable is a transition aid.  If t, `current-time' and
related functions return timestamps in list form, typically
\(HIGH LOW USEC PSEC); otherwise, they use (TICKS . HZ) form.
Currently this variable defaults to t, for behavior compatible with
previous Emacs versions.  Developers are encouraged to test
timestamp-related code with this variable set to nil, as it will
default to nil in a future Emacs version, and will be removed in some
version after that.]]
  )
  vars.V.current_time_list = vars.Qt
end
return M
