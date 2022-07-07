local P = {}

---Take characters until the target characters (The escape sequence is '\' + char)
---@param targets string[] The character list for stop consuming text.
---@param specials string[] If the character isn't contained in targets/specials, '\' will be left.
P.take_until = function(targets, specials)
  targets = targets or {}
  specials = specials or {}

  return function(input, pos)
    local new_pos = pos
    local raw = {}
    local esc = {}
    while new_pos <= #input do
      local c = string.sub(input, new_pos, new_pos)
      if c == '\\' then
        table.insert(raw, '\\')
        new_pos = new_pos + 1
        c = string.sub(input, new_pos, new_pos)
        if not vim.tbl_contains(targets, c) and not vim.tbl_contains(specials, c) then
          table.insert(esc, '\\')
        end
        table.insert(raw, c)
        table.insert(esc, c)
        new_pos = new_pos + 1
      else
        if vim.tbl_contains(targets, c) then
          break
        end
        table.insert(raw, c)
        table.insert(esc, c)
        new_pos = new_pos + 1
      end
    end

    if new_pos == pos then
      return P.unmatch(pos)
    end

    return {
      parsed = true,
      value = {
        raw = table.concat(raw, ''),
        esc = table.concat(esc, ''),
      },
      pos = new_pos,
    }
  end
end

P.unmatch = function(pos)
  return {
    parsed = false,
    value = nil,
    pos = pos,
  }
end

P.map = function(parser, map)
  return function(input, pos)
    local result = parser(input, pos)
    if result.parsed then
      return {
        parsed = true,
        value = map(result.value),
        pos = result.pos,
      }
    end
    return P.unmatch(pos)
  end
end

P.lazy = function(factory)
  return function(input, pos)
    return factory()(input, pos)
  end
end

P.token = function(token)
  return function(input, pos)
    local maybe_token = string.sub(input, pos, pos + #token - 1)
    if token == maybe_token then
      return {
        parsed = true,
        value = maybe_token,
        pos = pos + #token,
      }
    end
    return P.unmatch(pos)
  end
end

P.pattern = function(p)
  return function(input, pos)
    local maybe_match = string.match(string.sub(input, pos), '^' .. p)
    if maybe_match then
      return {
        parsed = true,
        value = maybe_match,
        pos = pos + #maybe_match,
      }
    end
    return P.unmatch(pos)
  end
end

P.many = function(parser)
  return function(input, pos)
    local values = {}
    local new_pos = pos
    while new_pos <= #input do
      local result = parser(input, new_pos)
      if not result.parsed then
        break
      end
      table.insert(values, result.value)
      new_pos = result.pos
    end
    if #values > 0 then
      return {
        parsed = true,
        value = values,
        pos = new_pos,
      }
    end
    return P.unmatch(pos)
  end
end

P.any = function(...)
  local parsers = { ... }
  return function(input, pos)
    for _, parser in ipairs(parsers) do
      local result = parser(input, pos)
      if result.parsed then
        return result
      end
    end
    return P.unmatch(pos)
  end
end

P.opt = function(parser)
  return function(input, pos)
    local result = parser(input, pos)
    return {
      parsed = true,
      value = result.value,
      pos = result.pos,
    }
  end
end

P.seq = function(...)
  local parsers = { ... }
  return function(input, pos)
    local values = {}
    local new_pos = pos
    for i, parser in ipairs(parsers) do
      local result = parser(input, new_pos)
      if result.parsed then
        values[i] = result.value
        new_pos = result.pos
      else
        return P.unmatch(pos)
      end
    end
    return {
      parsed = true,
      value = values,
      pos = new_pos,
    }
  end
end

local Node = {}

Node.Type = {
  SNIPPET = 0,
  TABSTOP = 1,
  PLACEHOLDER = 2,
  VARIABLE = 3,
  CHOICE = 4,
  TRANSFORM = 5,
  FORMAT = 6,
  TEXT = 7,
}

function Node:__tostring()
  local insert_text = {}
  if self.type == Node.Type.SNIPPET then
    for _, c in ipairs(self.children) do
      table.insert(insert_text, tostring(c))
    end
  elseif self.type == Node.Type.CHOICE then
    table.insert(insert_text, self.items[1])
  elseif self.type == Node.Type.PLACEHOLDER then
    for _, c in ipairs(self.children or {}) do
      table.insert(insert_text, tostring(c))
    end
  elseif self.type == Node.Type.TEXT then
    table.insert(insert_text, self.esc)
  end
  return table.concat(insert_text, '')
end

--@see https://code.visualstudio.com/docs/editor/userdefinedsnippets#_grammar

local S = {}
S.dollar = P.token('$')
S.open = P.token('{')
S.close = P.token('}')
S.colon = P.token(':')
S.slash = P.token('/')
S.comma = P.token(',')
S.pipe = P.token('|')
S.plus = P.token('+')
S.minus = P.token('-')
S.question = P.token('?')
S.int = P.map(P.pattern('[0-9]+'), function(value)
  return tonumber(value, 10)
end)
S.var = P.pattern('[%a_][%w_]+')
S.text = function(targets, specials)
  return P.map(P.take_until(targets, specials), function(value)
    return setmetatable({
      type = Node.Type.TEXT,
      raw = value.raw,
      esc = value.esc,
    }, Node)
  end)
end

S.toplevel = P.lazy(function()
  return P.any(S.placeholder, S.tabstop, S.variable, S.choice)
end)

S.format = P.any(
  P.map(P.seq(S.dollar, S.int), function(values)
    return setmetatable({
      type = Node.Type.FORMAT,
      capture_index = values[2],
    }, Node)
  end),
  P.map(P.seq(S.dollar, S.open, S.int, S.close), function(values)
    return setmetatable({
      type = Node.Type.FORMAT,
      capture_index = values[3],
    }, Node)
  end),
  P.map(
    P.seq(
      S.dollar,
      S.open,
      S.int,
      S.colon,
      S.slash,
      P.any(
        P.token('upcase'),
        P.token('downcase'),
        P.token('capitalize'),
        P.token('camelcase'),
        P.token('pascalcase')
      ),
      S.close
    ),
    function(values)
      return setmetatable({
        type = Node.Type.FORMAT,
        capture_index = values[3],
        modifier = values[6],
      }, Node)
    end
  ),
  P.map(
    P.seq(
      S.dollar,
      S.open,
      S.int,
      S.colon,
      P.seq(
        S.question,
        P.opt(P.take_until({ ':' }, { '\\' })),
        S.colon,
        P.opt(P.take_until({ '}' }, { '\\' }))
      ),
      S.close
    ),
    function(values)
      return setmetatable({
        type = Node.Type.FORMAT,
        capture_index = values[3],
        if_text = values[5][2] and values[5][2].esc or '',
        else_text = values[5][4] and values[5][4].esc or '',
      }, Node)
    end
  ),
  P.map(
    P.seq(
      S.dollar,
      S.open,
      S.int,
      S.colon,
      P.seq(S.plus, P.opt(P.take_until({ '}' }, { '\\' }))),
      S.close
    ),
    function(values)
      return setmetatable({
        type = Node.Type.FORMAT,
        capture_index = values[3],
        if_text = values[5][2] and values[5][2].esc or '',
        else_text = '',
      }, Node)
    end
  ),
  P.map(
    P.seq(
      S.dollar,
      S.open,
      S.int,
      S.colon,
      S.minus,
      P.opt(P.take_until({ '}' }, { '\\' })),
      S.close
    ),
    function(values)
      return setmetatable({
        type = Node.Type.FORMAT,
        capture_index = values[3],
        if_text = '',
        else_text = values[6] and values[6].esc or '',
      }, Node)
    end
  ),
  P.map(
    P.seq(S.dollar, S.open, S.int, S.colon, P.opt(P.take_until({ '}' }, { '\\' })), S.close),
    function(values)
      return setmetatable({
        type = Node.Type.FORMAT,
        capture_index = values[3],
        if_text = '',
        else_text = values[5] and values[5].esc or '',
      }, Node)
    end
  )
)

S.transform = P.map(
  P.seq(
    S.slash,
    P.take_until({ '/' }, { '\\' }),
    S.slash,
    P.many(P.any(S.format, S.text({ '$', '/' }, { '\\' }))),
    S.slash,
    P.opt(P.pattern('[ig]+'))
  ),
  function(values)
    return setmetatable({
      type = Node.Type.TRANSFORM,
      pattern = values[2].raw,
      format = values[4],
      option = values[6],
    }, Node)
  end
)

S.tabstop = P.any(
  P.map(P.seq(S.dollar, S.int), function(values)
    return setmetatable({
      type = Node.Type.TABSTOP,
      tabstop = values[2],
    }, Node)
  end),
  P.map(P.seq(S.dollar, S.open, S.int, S.close), function(values)
    return setmetatable({
      type = Node.Type.TABSTOP,
      tabstop = values[3],
    }, Node)
  end),
  P.map(P.seq(S.dollar, S.open, S.int, S.transform, S.close), function(values)
    return setmetatable({
      type = Node.Type.TABSTOP,
      tabstop = values[3],
      transform = values[4],
    }, Node)
  end)
)

S.placeholder = P.any(
  P.map(
    P.seq(
      S.dollar,
      S.open,
      S.int,
      S.colon,
      P.opt(P.many(P.any(S.toplevel, S.text({ '$', '}' }, { '\\' })))),
      S.close
    ),
    function(values)
      return setmetatable({
        type = Node.Type.PLACEHOLDER,
        tabstop = values[3],
        -- insert empty text if opt did not match.
        children = values[5] or {
          setmetatable({
            type = Node.Type.TEXT,
            raw = '',
            esc = '',
          }, Node),
        },
      }, Node)
    end
  )
)

S.choice = P.map(
  P.seq(
    S.dollar,
    S.open,
    S.int,
    S.pipe,
    P.many(P.map(P.seq(S.text({ ',', '|' }), P.opt(S.comma)), function(values)
      return values[1].esc
    end)),
    S.pipe,
    S.close
  ),
  function(values)
    return setmetatable({
      type = Node.Type.CHOICE,
      tabstop = values[3],
      items = values[5],
    }, Node)
  end
)

S.variable = P.any(
  P.map(P.seq(S.dollar, S.var), function(values)
    return setmetatable({
      type = Node.Type.VARIABLE,
      name = values[2],
    }, Node)
  end),
  P.map(P.seq(S.dollar, S.open, S.var, S.close), function(values)
    return setmetatable({
      type = Node.Type.VARIABLE,
      name = values[3],
    }, Node)
  end),
  P.map(P.seq(S.dollar, S.open, S.var, S.transform, S.close), function(values)
    return setmetatable({
      type = Node.Type.VARIABLE,
      name = values[3],
      transform = values[4],
    }, Node)
  end),
  P.map(
    P.seq(
      S.dollar,
      S.open,
      S.var,
      S.colon,
      P.many(P.any(S.toplevel, S.text({ '$', '}' }, { '\\' }))),
      S.close
    ),
    function(values)
      return setmetatable({
        type = Node.Type.VARIABLE,
        name = values[3],
        children = values[5],
      }, Node)
    end
  )
)

S.snippet = P.map(P.many(P.any(S.toplevel, S.text({ '$' }, { '}', '\\' }))), function(values)
  return setmetatable({
    type = Node.Type.SNIPPET,
    children = values,
  }, Node)
end)

local M = {}

---The snippet node type enum
---@types table<string, number>
M.NodeType = Node.Type

---Parse snippet string and returns the AST
---@param input string
---@return table
function M.parse(input)
  local result = S.snippet(input, 1)
  if not result.parsed then
    error('snippet parsing failed.')
  end
  return result.value
end

return M
