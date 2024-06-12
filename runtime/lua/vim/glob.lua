local lpeg = vim.lpeg
local P, S, V, R, B = lpeg.P, lpeg.S, lpeg.V, lpeg.R, lpeg.B
local C, Cc, Ct, Cf = lpeg.C, lpeg.Cc, lpeg.Ct, lpeg.Cf

local M = {}

local pathsep = P '/'

---@param ... vim.lpeg.Pattern|string
---@return vim.lpeg.Pattern|string
local function fold_cond(...)
  local captures = { ... }

  if #captures == 1 and type(captures[1]) == 'string' then
    return captures[1]
  end

  local pat
  local strings_acumulator = {} ---@type string[]
  for i, capture in ipairs(captures) do
    if type(capture) == 'string' and i < #captures then
      table.insert(strings_acumulator, capture)
    elseif type(capture) == 'string' and i == #captures then
      local string_pat = P(capture)
      pat = pat and pat * string_pat or string_pat
    elseif type(capture) == 'userdata' then
      ---@cast capture vim.lpeg.Pattern
      if not vim.tbl_isempty(strings_acumulator) then
        local string_pat = P(table.concat(strings_acumulator))
        strings_acumulator = {}
        pat = path and pat * string_pat or string_pat
      end
      pat = pat and pat * capture or capture
    end
  end

  return pat
end

local function accumulate_fold_list(acc, a)
  if type(a) == 'string' then
    acc.ids = acc.ids or {}
    table.insert(acc.ids, a)
    return acc
  elseif type(a) == 'userdata' then
    acc.pattern = acc.pattern and acc.pattern + a or a
    return acc
  end
end

---@param ... vim.lpeg.Pattern|string
---@return vim.lpeg.Pattern
local function fold_cond_list(...)
  local captures = { ... }

  local acc = vim.iter(captures):fold({}, accumulate_fold_list)

  if acc.ids and not vim.tbl_isempty(acc.ids) then
    table.sort(acc.ids, function(a, b)
      return #a > #b
    end)
    local id_pattern = vim.iter(acc.ids):fold(P(false), function(a, b)
      return a + b
    end)
    return acc.pattern and acc.pattern + id_pattern or id_pattern
  end
  return acc.pattern
end

---@param acc vim.lpeg.Pattern
---@param m vim.lpeg.Pattern
---@return vim.lpeg.Pattern
local function mul(acc, m)
  return acc * m
end

---@param stars '*'
---@param after vim.lpeg.Pattern
---@return vim.lpeg.Pattern
local function star(stars, after)
  return (-after * (P(1) - pathsep)) ^ #stars * after
end

---@param after vim.lpeg.Pattern
---@return vim.lpeg.Pattern
local function dstar(after)
  return (-after * P(1)) ^ 0 * after
end

--- Parses a raw glob into an |lua-lpeg| pattern.
---
--- This uses glob semantics from LSP 3.17.0: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#pattern
---
--- Glob patterns can have the following syntax:
--- - `*` to match one or more characters in a path segment
--- - `?` to match on one character in a path segment
--- - `**` to match any number of path segments, including none
--- - `{}` to group conditions (e.g. `*.{ts,js}` matches TypeScript and JavaScript files)
--- - `[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
--- - `[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)
---
---@param pattern string The raw glob pattern
---@return vim.lpeg.Pattern pattern An |lua-lpeg| representation of the pattern
function M.to_lpeg(pattern)
  local function class(inv, ranges)
    local patt = R(unpack(vim.tbl_map(table.concat, ranges)))
    if inv == '!' then
      patt = P(1) - patt
    end
    return patt
  end

  local p = P {
    'Pattern',
    Pattern = V 'Elem' ^ -1 * V 'End',
    Elem = Cf(
      (V 'DStar' + V 'Star' + V 'Ques' + V 'Class' + V 'CondList' + V 'Literal')
        * (V 'Elem' + V 'End'),
      mul
    ),
    DStar = (B(pathsep) + -B(P(1))) * P '**' * (pathsep * (V 'Elem' + V 'End') + V 'End') / dstar,
    Star = C(P '*' ^ 1) * (V 'Elem' + V 'End') / star,
    Ques = P '?' * Cc(P(1) - pathsep),
    Class = P '[' * C(P '!' ^ -1) * Ct(Ct(C(P(1)) * P '-' * C(P(1) - P ']')) ^ 1 * P ']') / class,
    CondList = P '{' * (V 'Cond' * (P ',' * V 'Cond') ^ 0) / fold_cond_list * P '}',
    -- TODO: '*' inside a {} condition is interpreted literally but should probably have the same
    -- wildcard semantics it usually has.
    -- Fixing this is non-trivial because '*' should match non-greedily up to "the rest of the
    -- pattern" which in all other cases is the entire succeeding part of the pattern, but at the end of a {}
    -- condition means "everything after the {}" where several other options separated by ',' may
    -- exist in between that should not be matched by '*'.
    Cond = ((V 'Ques' + V 'Class' + V 'CondList' + (V 'Identifier')) ^ 1) / fold_cond + Cc(P(0)),
    Identifier = (P(1) - S '?,}') ^ 1 / tostring,
    Literal = P(1) / P,
    End = P(-1) * Cc(P(-1)),
  }

  local lpeg_pattern = p:match(pattern) --[[@as vim.lpeg.Pattern?]]
  assert(lpeg_pattern, 'Invalid glob')
  return lpeg_pattern
end

return M
