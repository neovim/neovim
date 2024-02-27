--- @meta

-- luacheck: no unused args

--- @brief Vim regexes can be used directly from Lua. Currently they only allow
--- matching within a single line.

--- Parse the Vim regex {re} and return a regex object. Regexes are "magic"
--- and case-sensitive by default, regardless of 'magic' and 'ignorecase'.
--- They can be controlled with flags, see |/magic| and |/ignorecase|.
--- @param re string
--- @return vim.regex
function vim.regex(re) end

--- @nodoc
--- @class vim.regex
local regex = {} -- luacheck: no unused

--- Match the string against the regex. If the string should match the regex
--- precisely, surround the regex with `^` and `$`. If there was a match, the
--- byte indices for the beginning and end of the match are returned. When
--- there is no match, `nil` is returned. Because any integer is "truthy",
--- `regex:match_str()` can be directly used as a condition in an if-statement.
--- @param str string
function regex:match_str(str) end

--- Match line {line_idx} (zero-based) in buffer {bufnr}. If {start} and {end}
--- are supplied, match only this byte index range. Otherwise see
--- |regex:match_str()|. If {start} is used, then the returned byte indices
--- will be relative {start}.
--- @param bufnr integer
--- @param line_idx integer
--- @param start? integer
--- @param end_? integer
function regex:match_line(bufnr, line_idx, start, end_) end
