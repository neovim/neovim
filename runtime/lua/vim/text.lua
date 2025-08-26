-- Text processing functions.

local M = {}

--- Optional parameters:
--- @class vim.text.diff.Opts
--- @inlinedoc
---
--- Invoked for each hunk in the diff. Return a negative number
--- to cancel the callback for any remaining hunks.
--- Arguments:
---   - `start_a` (`integer`): Start line of hunk in {a}.
---   - `count_a` (`integer`): Hunk size in {a}.
---   - `start_b` (`integer`): Start line of hunk in {b}.
---   - `count_b` (`integer`): Hunk size in {b}.
--- @field on_hunk? fun(start_a: integer, count_a: integer, start_b: integer, count_b: integer): integer?
---
--- Form of the returned diff:
---   - `unified`: String in unified format.
---   - `indices`: Array of hunk locations.
--- Note: This option is ignored if `on_hunk` is used.
--- (default: `'unified'`)
--- @field result_type? 'unified'|'indices'
---
--- Run linematch on the resulting hunks from xdiff. When integer, only hunks
--- upto this size in lines are run through linematch.
--- Requires `result_type = indices`, ignored otherwise.
--- @field linematch? boolean|integer
---
--- Diff algorithm to use. Values:
---   - `myers`: the default algorithm
---   - `minimal`: spend extra time to generate the smallest possible diff
---   - `patience`: patience diff algorithm
---   - `histogram`: histogram diff algorithm
--- (default: `'myers'`)
--- @field algorithm? 'myers'|'minimal'|'patience'|'histogram'
--- @field ctxlen? integer Context length
--- @field interhunkctxlen? integer Inter hunk context length
--- @field ignore_whitespace? boolean Ignore whitespace
--- @field ignore_whitespace_change? boolean Ignore whitespace change
--- @field ignore_whitespace_change_at_eol? boolean Ignore whitespace change at end-of-line.
--- @field ignore_cr_at_eol? boolean Ignore carriage return at end-of-line
--- @field ignore_blank_lines? boolean Ignore blank lines
--- @field indent_heuristic? boolean Use the indent heuristic for the internal diff library.

-- luacheck: no unused args

--- Run diff on strings {a} and {b}. Any indices returned by this function,
--- either directly or via callback arguments, are 1-based.
---
--- Examples:
---
--- ```lua
--- vim.text.diff('a\n', 'b\nc\n')
--- -- =>
--- -- @@ -1 +1,2 @@
--- -- -a
--- -- +b
--- -- +c
---
--- vim.text.diff('a\n', 'b\nc\n', {result_type = 'indices'})
--- -- =>
--- -- {
--- --   {1, 1, 1, 2}
--- -- }
--- ```
---
---@diagnostic disable-next-line: undefined-doc-param
---@param a string First string to compare
---@diagnostic disable-next-line: undefined-doc-param
---@param b string Second string to compare
---@diagnostic disable-next-line: undefined-doc-param
---@param opts? vim.text.diff.Opts
---@return string|integer[][]? # See {opts.result_type}. `nil` if {opts.on_hunk} is given.
function M.diff(...)
  ---@diagnostic disable-next-line: deprecated
  return vim.diff(...)
end

local alphabet = '0123456789ABCDEF'
local atoi = {} ---@type table<string, integer>
local itoa = {} ---@type table<integer, string>
do
  for i = 1, #alphabet do
    local char = alphabet:sub(i, i)
    itoa[i - 1] = char
    atoi[char] = i - 1
    atoi[char:lower()] = i - 1
  end
end

--- Hex encode a string.
---
--- @param str string String to encode
--- @return string : Hex encoded string
function M.hexencode(str)
  local enc = {} ---@type string[]
  for i = 1, #str do
    local byte = str:byte(i)
    enc[2 * i - 1] = itoa[math.floor(byte / 16)]
    enc[2 * i] = itoa[byte % 16]
  end
  return table.concat(enc)
end

--- Hex decode a string.
---
--- @param enc string String to decode
--- @return string? : Decoded string
--- @return string? : Error message, if any
function M.hexdecode(enc)
  if #enc % 2 ~= 0 then
    return nil, 'string must have an even number of hex characters'
  end

  local str = {} ---@type string[]
  for i = 1, #enc, 2 do
    local u = atoi[enc:sub(i, i)]
    local l = atoi[enc:sub(i + 1, i + 1)]
    if not u or not l then
      return nil, 'string must contain only hex characters'
    end
    str[(i + 1) / 2] = string.char(u * 16 + l)
  end
  return table.concat(str), nil
end

--- Sets the indent (i.e. the common leading whitespace) of non-empty lines in `text` to `size`
--- spaces/tabs.
---
--- Indent is calculated by number of consecutive indent chars.
--- - The first indented, non-empty line decides the indent char (space/tab):
---   - `SPC SPC TAB …` = two-space indent.
---   - `TAB SPC …` = one-tab indent.
--- - Set `opts.expandtab` to treat tabs as spaces.
---
--- To "dedent" (remove the common indent), pass `size=0`:
--- ```lua
--- vim.print(vim.text.indent(0, ' a\n  b\n'))
--- ```
---
--- To adjust relative-to an existing indent, call indent() twice:
--- ```lua
--- local indented, old_indent = vim.text.indent(0, ' a\n b\n')
--- indented = vim.text.indent(old_indent + 2, indented)
--- vim.print(indented)
--- ```
---
--- To ignore the final, blank line when calculating the indent, use gsub() before calling indent():
--- ```lua
--- local text = '  a\n  b\n '
--- vim.print(vim.text.indent(0, (text:gsub('\n[\t ]+\n?$', '\n'))))
--- ```
---
--- @param size integer Number of spaces.
--- @param text string Text to indent.
--- @param opts? { expandtab?: integer }
--- @return string # Indented text.
--- @return integer # Indent size _before_ modification.
function M.indent(size, text, opts)
  vim.validate('size', size, 'number')
  vim.validate('text', text, 'string')
  vim.validate('opts', opts, 'table', true)
  -- TODO(justinmk): `opts.prefix`, `predicate` like python https://docs.python.org/3/library/textwrap.html
  opts = opts or {}
  local tabspaces = opts.expandtab and (' '):rep(opts.expandtab) or nil

  --- Minimum common indent shared by all lines.
  local old_indent --- @type integer?
  local prefix = tabspaces and ' ' or nil -- Indent char (space or tab).
  --- Check all non-empty lines, capturing leading whitespace (if any).
  --- @diagnostic disable-next-line: no-unknown
  for line_ws, extra in text:gmatch('([\t ]*)([^\n]+)') do
    line_ws = tabspaces and line_ws:gsub('[\t]', tabspaces) or line_ws
    -- XXX: blank line will miss the last whitespace char in `line_ws`, so we need to check `extra`.
    line_ws = line_ws .. (extra:match('^%s+$') or '')
    if 0 == #line_ws then
      -- Optimization: If any non-empty line has indent=0, there is no common indent.
      old_indent = 0
      break
    end
    prefix = prefix and prefix or line_ws:sub(1, 1)
    local _, end_ = line_ws:find('^[' .. prefix .. ']+')
    old_indent = math.min(old_indent or math.huge, end_ or 0) --[[@as integer?]]
  end
  -- Default to 0 if all lines are empty.
  old_indent = old_indent or 0
  prefix = prefix and prefix or ' '

  if old_indent == size then
    -- Optimization: if the indent is the same, return the text unchanged.
    return text, old_indent
  end

  local new_indent = prefix:rep(size)

  --- Replaces indentation of a line.
  --- @param line string
  local function replace_line(line)
    -- Match the existing indent exactly; avoid over-matching any following whitespace.
    local pat = prefix:rep(old_indent)
    -- Expand tabs before replacing indentation.
    line = not tabspaces and line
      or line:gsub('^[\t ]+', function(s)
        return s:gsub('\t', tabspaces)
      end)
    -- Text following the indent.
    local line_text = line:match('^' .. pat .. '(.*)') or line
    return new_indent .. line_text
  end

  return (text:gsub('[^\n]+', replace_line)), old_indent
end

return M
