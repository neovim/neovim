--- @brief Glob-to-LPeg Converter (Peglob)
--- This module converts glob patterns to LPeg patterns according to the LSP 3.17 specification:
--- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#pattern
---
--- Glob grammar overview:
--- - `*` to match zero or more characters in a path segment
--- - `?` to match on one character in a path segment
--- - `**` to match any number of path segments, including none
--- - `{}` to group conditions (e.g. `*.{ts,js}` matches TypeScript and JavaScript files)
--- - `[]` to declare a range of characters to match in a path segment
---   (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
--- - `[!...]` to negate a range of characters to match in a path segment
---   (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)
---
--- Additional constraints:
--- - A Glob pattern must match an entire path, with partial matches
---   considered failures.
--- - The pattern only determines success or failure, without specifying
---   which parts correspond to which characters.
--- - A *path segment* is the portion of a path between two adjacent path
---   separators (`/`), or between the start/end of the path and the nearest
---   separator.
--- - The `**` (*globstar*) pattern matches zero or more path segments,
---   including intervening separators (`/`). Within pattern strings, `**`
---   must be delimited by path separators (`/`) or pattern boundaries and
---   cannot be adjacent to any characters other than `/`. If `**` is not
---   the final element, it must be followed by `/`.
--- - `{}` (*braced conditions*) contains valid Glob patterns as branches,
---   separated by commas. Commas are exclusively used for separating
---   branches and cannot appear within a branch for any other purpose.
---   Nested `{}` structures are allowed, but `{}` must contain at least two
---   branches—zero or one branch is not permitted.
--- - In `[]` or `[!...]`, a *character range* consists of character
---   intervals (e.g., `a-z`) or individual characters (e.g., `w`). A range
---   including `/` won’t match that character.

--- @diagnostic disable: missing-fields

local m = vim.lpeg
local mt = getmetatable(m.P(0))
local re = vim.re
local bit = require('bit')

local M = {}

-- Basic patterns for matching glob components
local letter = m.P(1) - m.S(',*?[]{}/\\') -- Any character except special glob characters
local slash = m.P '/' * m.Cc(m.P '/') -- Path separator with capture
local notslash = m.P(1) - m.P '/' -- Any character except path separator
local notcomma = m.P(1) - m.S(',\\') -- Any character except comma and backslash

--- Handle EOF, considering whether we're in a segment or not
--- @type vim.lpeg.Pattern
local eof = -1
  * m.Cb('inseg')
  / function(flag)
    if flag then
      return #m.P '/'
    else
      return m.P(-1)
    end
  end

---@alias pat_table { F: string?, [1]: string, [2]: vim.lpeg.Pattern }
---@alias seg_part { [string]: any, [integer]: pat_table }

--- @param p pat_table Initial segment pattern data
--- @return seg_part Segment structure with start pattern
local function start_seg(p)
  return { s = p[2], e = true, n = 0 }
end

--- @param t seg_part Segment structure
--- @param p pat_table Pattern to look for
--- @return table Updated segment structure
local function lookfor(t, p)
  t.n = t.n + 1
  t[t.n] = p
  return t
end

--- @param t seg_part Segment structure
--- @return table Segment structure with end pattern
local function to_seg_end(t)
  t.e = notslash ^ 0
  return t
end

--- Constructs a segment matching pattern from collected components
---
--- @param t seg_part Segment structure with patterns
--- @return vim.lpeg.Pattern Complete segment match pattern
local function end_seg(t)
  --- @type table<any,any>
  local seg_grammar = { 's' }
  if t.n > 0 then
    seg_grammar.s = t.s
    for i = 1, t.n do
      local rname = t[i][1]
      if not seg_grammar[rname] then
        -- Optimize search when deterministic first character is available
        if t[i].F then
          seg_grammar[rname] = t[i][2] + notslash * (notslash - m.P(t[i].F)) ^ 0 * m.V(rname)
        else
          seg_grammar[rname] = t[i][2] + notslash * m.V(rname)
        end
      end
      seg_grammar.s = seg_grammar.s * m.V(rname)
    end
    if t.e then
      seg_grammar.s = seg_grammar.s * t.e
    end
    return m.P(seg_grammar)
  else
    seg_grammar.s = t.s
    if t.e then
      seg_grammar.s = seg_grammar.s * t.e
    end
    return seg_grammar.s
  end
end

--- @param p vim.lpeg.Pattern Pattern directly after `**/`
--- @return vim.lpeg.Pattern LPeg pattern for `**/p`
local function dseg(p)
  return m.P { p + notslash ^ 0 * m.P '/' * m.V(1) }
end

--- @type (vim.lpeg.Pattern|table)
local g = nil

--- Multiplies conditions for braced expansion (Cartesian product)
---
--- @param a string|string[] First part
--- @param b string|string[] Second part
--- @return string|string[] Cartesian product of values
local function mul_cond(a, b)
  if type(a) == 'string' then
    if type(b) == 'string' then
      return a .. b
    elseif type(b) == 'table' then
      for i = 1, #b do
        b[i] = a .. b[i]
      end
      return b
    else
      return a
    end
  elseif type(a) == 'table' then
    if type(b) == 'string' then
      for i = 1, #a do
        a[i] = a[i] .. b
      end
      return a
    elseif type(b) == 'table' then
      --- @type string[]
      local res = {}
      local idx = 0
      for i = 1, #a do
        for j = 1, #b do
          idx = idx + 1
          res[idx] = a[i] .. b[j]
        end
      end
      return res
    else
      return a
    end
  else
    return b
  end
end

--- Combines alternatives in braced patterns
---
--- @param a string|table First part
--- @param b string|table Second part
--- @return table #Combined alternatives
local function add_cond(a, b)
  if type(a) == 'string' then
    if type(b) == 'string' then
      return { a, b }
    elseif type(b) == 'table' then
      table.insert(b, 1, a)
      return b
    end
  elseif type(a) == 'table' then
    if type(b) == 'string' then
      table.insert(a, b)
      return a
    elseif type(b) == 'table' then
      for i = 1, #b do
        table.insert(a, b[i])
      end
      return a
    end
    --- @diagnostic disable-next-line: missing-return
  end
end

--- Expands patterns handling segment boundaries
--- `#` prefix is added for sub-grammar to detect in-segment flag
---
---@param a (any[]|vim.lpeg.Pattern[]) Array of patterns
---@param b string Tail string
---@param inseg boolean Whether inside a path segment
---@return vim.lpeg.Pattern #Expanded pattern
local function expand(a, b, inseg)
  for i = 1, #a do
    if inseg then
      a[i] = '#' .. a[i]
    end
    a[i] = g:match(a[i] .. b)
  end
  local res = a[1]
  for i = 2, #a do
    res = res + a[i]
  end
  return res
end

--- Converts a UTF-8 character to its Unicode codepoint
---
--- @param utf8_str string UTF-8 character
--- @return number #Codepoint value
local function to_codepoint(utf8_str)
  local codepoint = 0
  local byte_count = 0

  for i = 1, #utf8_str do
    local byte = utf8_str:byte(i)

    if byte_count ~= 0 then
      codepoint = bit.bor(bit.lshift(codepoint, 6), bit.band(byte, 0x3F))
      byte_count = byte_count - 1
    else
      if byte < 0x80 then
        codepoint = byte
      elseif byte < 0xE0 then
        byte_count = 1
        codepoint = bit.band(byte, 0x1F)
      elseif byte < 0xF0 then
        byte_count = 2
        codepoint = bit.band(byte, 0x0F)
      else
        byte_count = 3
        codepoint = bit.band(byte, 0x07)
      end
    end

    if byte_count == 0 then
      break
    end
  end

  return codepoint
end

--- Pattern for matching UTF-8 characters
local cont = m.R('\128\191')
local any_utf8 = m.R('\0\127')
  + m.R('\194\223') * cont
  + m.R('\224\239') * cont * cont
  + m.R('\240\244') * cont * cont * cont

--- Creates a character class pattern for glob ranges
--- @param inv string Inversion flag ('!' or '')
--- @param ranges (string|string[])[] Character ranges
--- @return vim.lpeg.Pattern #Character class pattern
local function class(inv, ranges)
  local patt = m.P(false)
  if #ranges == 0 then
    if inv == '!' then
      return m.P '[!]'
    else
      return m.P '[]'
    end
  end
  for _, v in ipairs(ranges) do
    patt = patt + (type(v) == 'table' and m.utfR(to_codepoint(v[1]), to_codepoint(v[2])) or m.P(v))
  end
  if inv == '!' then
    patt = m.P(1) - patt --[[@as vim.lpeg.Pattern]]
  end
  return patt - m.P '/'
end

-- Parse constraints for optimizing braced conditions
local noopt_condlist = re.compile [[
  s <- '/' / '**' / . [^/*]* s
]]

local opt_tail = re.compile [[
  s <- (!'**' [^{/])* &'/'
]]

-- stylua: ignore start
--- @nodoc
--- @diagnostic disable
--- Main grammar for glob pattern matching
g = {
  'Glob',
  Glob     = (m.P'#' * m.Cg(m.Cc(true), 'inseg') + m.Cg(m.Cc(false), 'inseg')) *
             m.Cf(m.V'Element'^-1 * (slash * m.V'Element')^0 * (slash^-1 * eof), mt.__mul),
  -- Elements handle segments, globstar patterns
  Element  = m.V'DSeg' + m.V'DSEnd' + m.Cf(m.V'Segment' * (slash * m.V'Segment')^0 * (slash * eof + eof^-1), mt.__mul),
  -- Globstar patterns
  DSeg     = m.P'**/' * ((m.V'Element' + eof) / dseg),
  DSEnd    = m.P'**' * -1 * m.Cc(m.P(1)^0),
  -- Segment handling with word and star patterns
  Segment  = (m.V'Word' / start_seg + m.Cc({ '', true }) / start_seg * (m.V'Star' * m.V'Word' % lookfor)) *
              (m.V'Star' * m.V'Word' % lookfor)^0 * (m.V'Star' * m.V'CheckBnd' % to_seg_end)^-1 / end_seg
             + m.V'Star' * m.V'CheckBnd' * m.Cc(notslash^0),
  CheckBnd = #m.P'/' + -1,  -- Boundary constraint

  -- Word patterns for fixed-length matching
  Word     = -m.P'*' * m.Ct( m.V('FIRST')^-1 * m.C(m.V'WordAux') ),
  WordAux  = m.V'Branch' + m.Cf(m.V'Simple'^1 * m.V'Branch'^-1, mt.__mul),
  Simple   = m.Cg( m.V'Token' * (m.V'Token' % mt.__mul)^0 * (m.V'Boundary' % mt.__mul)^-1),
  Boundary = #m.P'/' * m.Cc(#m.P'/') + eof,
  Token    = m.V'Ques' + m.V'Class' + m.V'Escape' + m.V'Literal',
  Star     = m.P'*',
  Ques     = m.P'?' * m.Cc(notslash),
  Escape   = m.P'\\' * m.C(1) / m.P,
  Literal  = m.C(letter^1) / m.P,

  -- Branch handling for braced conditions
  Branch   = m.Cmt(m.C(m.V'CondList'), function(s, i, p1, p2)
                                         -- Optimize brace expansion when possible
                                         -- p1: string form of condition list, p2: transformed lua table
                                         if noopt_condlist:match(p1) then
                                           -- Cannot optimize, match till the end
                                           return #s + 1, p2, s:sub(i)
                                         end
                                         -- Find point to cut for optimization
                                         local cut = opt_tail:match(s, i)
                                         if cut then
                                           -- Can optimize: match till cut point
                                           -- true flag tells expand to transform EOF matches to &'/' predicates
                                           return cut, p2, s:sub(i, cut - 1), true
                                         else
                                           -- Cannot optimize
                                           return #s + 1, p2, s:sub(i)
                                         end
                                       end) / expand,
  -- Brace expansion handling
  CondList = m.Cf(m.P'{' * m.V'Cond' * (m.P',' * m.V'Cond')^1 * m.P'}', add_cond),
  Cond     = m.Cf((m.C((notcomma + m.P'\\' * 1 - m.S'{}')^1) + m.V'CondList')^1, mul_cond) + m.C(true),

  -- Character class handling
  Class    = m.P'[' * m.C(m.P'!'^-1) * m.Ct(
              (m.Ct(m.C(any_utf8) * m.P'-' * m.C(any_utf8 - m.P']')) + m.C(any_utf8 - m.P']'))^0
            ) * m.P']' / class,

  -- Deterministic first character extraction for optimization
  FIRST    = m.Cg(m.P(function(s, i)
                        if letter:match(s, i) then return true, s:sub(i, i)
                        else return false end
                      end), 'F')
}
-- stylua: ignore end
--- @diagnostic enable

--- @nodoc
g = m.P(g)

--- Parses a raw glob into an |lua-lpeg| pattern.
---
---@param pattern string The raw glob pattern
---@return vim.lpeg.Pattern #An |lua-lpeg| representation of the pattern
function M.to_lpeg(pattern)
  local lpeg_pattern = g:match(pattern) --[[@as vim.lpeg.Pattern?]]
  assert(lpeg_pattern, 'Invalid glob')
  return lpeg_pattern
end

return M
