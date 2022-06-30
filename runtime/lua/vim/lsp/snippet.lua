local P = {}

local ast = require('vim.lsp.snippet.ast')

---Take characters until the target characters (The escape sequence is '\' + char)
---@param targets string[] The character list for stop consuming text.
---@param specials string[] If the character isn't contained in targets/specials, '\' will be left.
---@private
function P.take_until(targets, specials)
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

---@private
function P.unmatch(pos)
  return {
    parsed = false,
    value = nil,
    pos = pos,
  }
end

---@private
function P.map(parser, map)
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

---@private
function P.lazy(factory)
  return function(input, pos)
    return factory()(input, pos)
  end
end

---@private
function P.token(token)
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

---@private
function P.pattern(p)
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

---@private
function P.many(parser)
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

---@private
function P.any(...)
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

---@private
function P.opt(parser)
  return function(input, pos)
    local result = parser(input, pos)
    return {
      parsed = true,
      value = result.value,
      pos = result.pos,
    }
  end
end

---@private
function P.seq(...)
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

---see https://code.visualstudio.com/docs/editor/userdefinedsnippets#_grammar

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
    return ast.Text.new(value.esc, value.raw)
  end)
end

S.toplevel = P.lazy(function()
  return P.any(S.placeholder, S.tabstop, S.variable, S.choice)
end)

S.format = P.any(
  P.map(P.seq(S.dollar, S.int), function(values)
    return ast.Format.new(values[2])
  end),
  P.map(P.seq(S.dollar, S.open, S.int, S.close), function(values)
    return ast.Format.new(values[3])
  end),
  P.map(
    P.seq(
      S.dollar,
      S.open,
      S.int,
      S.colon,
      S.slash,
      P.any(P.token('upcase'), P.token('downcase'), P.token('capitalize'), P.token('camelcase'), P.token('pascalcase')),
      S.close
    ),
    function(values)
      return ast.Format.new(values[3], values[6])
    end
  ),
  P.map(
    P.seq(
      S.dollar,
      S.open,
      S.int,
      S.colon,
      P.seq(S.question, P.opt(P.take_until({ ':' }, { '\\' })), S.colon, P.opt(P.take_until({ '}' }, { '\\' }))),
      S.close
    ),
    function(values)
      return ast.Format.new(values[3], {
        if_text = values[5][2] and values[5][2].esc,
        else_text = values[5][4] and values[5][4].esc,
      })
    end
  ),
  P.map(
    P.seq(S.dollar, S.open, S.int, S.colon, P.seq(S.plus, P.opt(P.take_until({ '}' }, { '\\' }))), S.close),
    function(values)
      return ast.Format.new(values[3], {
        if_text = values[5][2] and values[5][2].esc,
      })
    end
  ),
  P.map(
    P.seq(S.dollar, S.open, S.int, S.colon, S.minus, P.opt(P.take_until({ '}' }, { '\\' })), S.close),
    function(values)
      return ast.Format.new(values[3], {
        else_text = values[6] and values[6].esc,
      })
    end
  ),
  P.map(P.seq(S.dollar, S.open, S.int, S.colon, P.opt(P.take_until({ '}' }, { '\\' })), S.close), function(values)
    return ast.Format.new(values[3], {
      else_text = values[5] and values[5].esc,
    })
  end)
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
    return ast.Transform.new(values[2].raw, values[4], values[6])
  end
)

S.tabstop = P.any(
  P.map(P.seq(S.dollar, S.int), function(values)
    return ast.Tabstop.new(values[2])
  end),
  P.map(P.seq(S.dollar, S.open, S.int, S.close), function(values)
    return ast.Tabstop.new(values[3])
  end),
  P.map(P.seq(S.dollar, S.open, S.int, S.transform, S.close), function(values)
    return ast.Tabstop.new(values[3], values[4])
  end)
)

S.placeholder = P.any(
  P.map(
    P.seq(S.dollar, S.open, S.int, S.colon, P.opt(P.many(P.any(S.toplevel, S.text({ '$', '}' }, { '\\' })))), S.close),
    function(values)
      -- no children -> manually create empty text.
      return ast.Placeholder.new(values[3], values[5] or { ast.Text.new('') })
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
    return ast.Choice.new(values[3], values[5])
  end
)

S.variable = P.any(
  P.map(P.seq(S.dollar, S.var), function(values)
    return ast.Variable.new(values[2])
  end),
  P.map(P.seq(S.dollar, S.open, S.var, S.close), function(values)
    return ast.Variable.new(values[3])
  end),
  P.map(P.seq(S.dollar, S.open, S.var, S.transform, S.close), function(values)
    return ast.Variable.new(values[3], values[4])
  end),
  P.map(
    P.seq(S.dollar, S.open, S.var, S.colon, P.many(P.any(S.toplevel, S.text({ '$', '}' }, { '\\' }))), S.close),
    function(values)
      return ast.Variable.new(values[3], values[5])
    end
  )
)

S.snippet = P.map(P.many(P.any(S.toplevel, S.text({ '$' }, { '}', '\\' }))), function(values)
  return ast.Snippet.new(values)
end)

local M = {}

---Build the AST for {input}.
---@param input string A snippet as defined in
---                    https://code.visualstudio.com/docs/editor/userdefinedsnippets#_grammar
---@return (Snippet)
function M.parse(input)
  local result = S.snippet(input, 1)
  if not result.parsed then
    error('snippet parsing failed.')
  end
  return result.value
end

M.ast = ast

return M
