--- @meta

-- luacheck: no unused args

--- @brief Vim regexes can be used directly from Lua. Currently they only allow
--- matching within a single line.

--- Parses the Vim regex `re` and returns a regex object. Regexes are "magic" and case-sensitive by
--- default, regardless of 'magic' and 'ignorecase'. They can be controlled with flags, see |/magic|
--- and |/ignorecase|.
--- @param re string
--- @return vim.regex
function vim.regex(re) end

--- @nodoc
--- @class vim.regex
local regex = {} -- luacheck: no unused

--- Matches string `str` against this regex. To match the string precisely, surround the regex with
--- "^" and "$". Returns the byte indices for the start and end of the match, or `nil` if there is
--- no match. Because any integer is "truthy", `regex:match_str()` can be directly used as
--- a condition in an if-statement.
--- @param str string
--- @return integer? # match start (byte index), or `nil` if no match
--- @return integer? # match end (byte index), or `nil` if no match
function regex:match_str(str) end

--- Matches line at `line_idx` (zero-based) in buffer `bufnr`. Match is restricted to byte index
--- range `start` and `end_` if given, otherwise see |regex:match_str()|. Returned byte indices are
--- relative to `start` if given.
--- @param bufnr integer
--- @param line_idx integer
--- @param start? integer
--- @param end_? integer
--- @return integer? # match start (byte index) relative to `start`, or `nil` if no match
--- @return integer? # match end (byte index) relative to `start`, or `nil` if no match
function regex:match_line(bufnr, line_idx, start, end_) end
