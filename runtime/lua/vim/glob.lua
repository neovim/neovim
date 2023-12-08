local lpeg = vim.lpeg

local M = {}

--- Parses a raw glob into an |lpeg| pattern.
---
--- This uses glob semantics from LSP 3.17.0: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#pattern
--- Glob patterns can have the following syntax:
--- `*` to match one or more characters in a path segment
--- `?` to match on one character in a path segment
--- `**` to match any number of path segments, including none
--- `{}` to group conditions (e.g. `**​/*.{ts,js}` matches all TypeScript and JavaScript files)
--- `[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
--- `[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)
---@param pattern string The raw glob pattern
---@return vim.lpeg.Pattern pattern An |lpeg| representation of the pattern
function M.to_lpeg(pattern)
  local l = lpeg

  local P, S, V = lpeg.P, lpeg.S, lpeg.V
  local C, Cc, Ct, Cf = lpeg.C, lpeg.Cc, lpeg.Ct, lpeg.Cf

  local pathsep = '/'

  local function class(inv, ranges)
    for i, r in ipairs(ranges) do
      ranges[i] = r[1] .. r[2]
    end
    local patt = l.R(unpack(ranges))
    if inv == '!' then
      patt = P(1) - patt
    end
    return patt
  end

  local function add(acc, a)
    return acc + a
  end

  local function mul(acc, m)
    return acc * m
  end

  local function star(stars, after)
    return (-after * (l.P(1) - pathsep)) ^ #stars * after
  end

  local function dstar(after)
    return (-after * l.P(1)) ^ 0 * after
  end

  local p = P({
    'Pattern',
    Pattern = V('Elem') ^ -1 * V('End'),
    Elem = Cf(
      (V('DStar') + V('Star') + V('Ques') + V('Class') + V('CondList') + V('Literal'))
        * (V('Elem') + V('End')),
      mul
    ),
    DStar = P('**') * (P(pathsep) * (V('Elem') + V('End')) + V('End')) / dstar,
    Star = C(P('*') ^ 1) * (V('Elem') + V('End')) / star,
    Ques = P('?') * Cc(l.P(1) - pathsep),
    Class = P('[') * C(P('!') ^ -1) * Ct(Ct(C(1) * '-' * C(P(1) - ']')) ^ 1 * ']') / class,
    CondList = P('{') * Cf(V('Cond') * (P(',') * V('Cond')) ^ 0, add) * '}',
    -- TODO: '*' inside a {} condition is interpreted literally but should probably have the same
    -- wildcard semantics it usually has.
    -- Fixing this is non-trivial because '*' should match non-greedily up to "the rest of the
    -- pattern" which in all other cases is the entire succeeding part of the pattern, but at the end of a {}
    -- condition means "everything after the {}" where several other options separated by ',' may
    -- exist in between that should not be matched by '*'.
    Cond = Cf((V('Ques') + V('Class') + V('CondList') + (V('Literal') - S(',}'))) ^ 1, mul)
      + Cc(l.P(0)),
    Literal = P(1) / l.P,
    End = P(-1) * Cc(l.P(-1)),
  })

  local lpeg_pattern = p:match(pattern) --[[@as vim.lpeg.Pattern?]]
  return assert(lpeg_pattern, 'Invalid glob')
end

return M
