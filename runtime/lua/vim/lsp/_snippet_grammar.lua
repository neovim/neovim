--- Grammar for LSP snippets, based on https://microsoft.github.io/language-server-protocol/specification/#snippet_syntax

local lpeg = vim.lpeg
local P, S, R, V = lpeg.P, lpeg.S, lpeg.R, lpeg.V
local C, Cg, Ct = lpeg.C, lpeg.Cg, lpeg.Ct

local M = {}

local alpha = R('az', 'AZ')
local backslash = P('\\')
local colon = P(':')
local dollar = P('$')
local int = R('09') ^ 1
local l_brace, r_brace = P('{'), P('}')
local pipe = P('|')
local slash = P('/')
local underscore = P('_')
local var = Cg((underscore + alpha) * ((underscore + alpha + int) ^ 0), 'name')
local format_capture = Cg(int / tonumber, 'capture')
local format_modifier = Cg(P('upcase') + P('downcase') + P('capitalize'), 'modifier')
local tabstop = Cg(int / tonumber, 'tabstop')

-- These characters are always escapable in text nodes no matter the context.
local escapable = '$}\\'

--- Returns a function that unescapes occurrences of "special" characters.
---
--- @param special? string
--- @return fun(match: string): string
local function escape_text(special)
  special = special or escapable
  return function(match)
    local escaped = match:gsub('\\(.)', function(c)
      return special:find(c) and c or '\\' .. c
    end)
    return escaped
  end
end

--- Returns a pattern for text nodes. Will match characters in `escape` when preceded by a backslash,
--- and will stop with characters in `stop_with`.
---
--- @param escape string
--- @param stop_with? string
--- @return vim.lpeg.Pattern
local function text(escape, stop_with)
  stop_with = stop_with or escape
  return (backslash * S(escape)) + (P(1) - S(stop_with))
end

-- For text nodes inside curly braces. It stops parsing when reaching an escapable character.
local braced_text = (text(escapable) ^ 0) / escape_text()

-- Within choice nodes, \ also escapes comma and pipe characters.
local choice_text = C(text(escapable .. ',|') ^ 1) / escape_text(escapable .. ',|')

-- Within format nodes, make sure we stop at /
local format_text = C(text(escapable, escapable .. '/') ^ 1) / escape_text()

local if_text, else_text = Cg(braced_text, 'if_text'), Cg(braced_text, 'else_text')

-- Within ternary condition format nodes, make sure we stop at :
local if_till_colon_text = Cg(C(text(escapable, escapable .. ':') ^ 1) / escape_text(), 'if_text')

-- Matches the string inside //, allowing escaping of the closing slash.
local regex = Cg(text('/') ^ 1, 'regex')

-- Regex constructor flags (see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp/RegExp#parameters).
local options = Cg(S('dgimsuvy') ^ 0, 'options')

--- @enum vim.snippet.Type
local Type = {
  Tabstop = 1,
  Placeholder = 2,
  Choice = 3,
  Variable = 4,
  Format = 5,
  Text = 6,
  Snippet = 7,
}
M.NodeType = Type

--- @class vim.snippet.Node<T>: { type: vim.snippet.Type, data: T }
--- @class vim.snippet.TabstopData: { tabstop: integer }
--- @class vim.snippet.TextData: { text: string }
--- @class vim.snippet.PlaceholderData: { tabstop: integer, value: vim.snippet.Node<any> }
--- @class vim.snippet.ChoiceData: { tabstop: integer, values: string[] }
--- @class vim.snippet.VariableData: { name: string, default?: vim.snippet.Node<any>, regex?: string, format?: vim.snippet.Node<vim.snippet.FormatData|vim.snippet.TextData>[], options?: string }
--- @class vim.snippet.FormatData: { capture: number, modifier?: string, if_text?: string, else_text?: string }
--- @class vim.snippet.SnippetData: { children: vim.snippet.Node<any>[] }

--- @type vim.snippet.Node<any>
local Node = {}

--- @return string
--- @diagnostic disable-next-line: inject-field
function Node:__tostring()
  local node_text = {}
  local type, data = self.type, self.data
  if type == Type.Snippet then
    --- @cast data vim.snippet.SnippetData
    for _, child in ipairs(data.children) do
      table.insert(node_text, tostring(child))
    end
  elseif type == Type.Choice then
    --- @cast data vim.snippet.ChoiceData
    table.insert(node_text, data.values[1])
  elseif type == Type.Placeholder then
    --- @cast data vim.snippet.PlaceholderData
    table.insert(node_text, tostring(data.value))
  elseif type == Type.Text then
    --- @cast data vim.snippet.TextData
    table.insert(node_text, data.text)
  end
  return table.concat(node_text)
end

--- Returns a function that constructs a snippet node of the given type.
---
--- @generic T
--- @param type vim.snippet.Type
--- @return fun(data: T): vim.snippet.Node<T>
local function node(type)
  return function(data)
    return setmetatable({ type = type, data = data }, Node)
  end
end

-- stylua: ignore
local G = P({
  'snippet';
  snippet = Ct(Cg(
    Ct((
      V('any') +
      (Ct(Cg((text(escapable, '$') ^ 1) / escape_text(), 'text')) / node(Type.Text))
    ) ^ 1), 'children'
  ) * -P(1)) / node(Type.Snippet),
  any = V('placeholder') + V('tabstop') + V('choice') + V('variable'),
  any_or_text = V('any') + (Ct(Cg(braced_text, 'text')) / node(Type.Text)),
  tabstop = Ct(dollar * (tabstop + (l_brace * tabstop * r_brace))) / node(Type.Tabstop),
  placeholder = Ct(dollar * l_brace * tabstop * colon * Cg(V('any_or_text'), 'value') * r_brace) / node(Type.Placeholder),
  choice = Ct(dollar *
    l_brace *
    tabstop *
    pipe *
    Cg(Ct(choice_text * (P(',') * choice_text) ^ 0), 'values') *
    pipe *
    r_brace) / node(Type.Choice),
  variable = Ct(dollar * (
    var + (
    l_brace * var * (
      r_brace +
      (colon * Cg(V('any_or_text'), 'default') * r_brace) +
      (slash * regex * slash * Cg(Ct((V('format') + (C(format_text) / node(Type.Text))) ^ 1), 'format') * slash * options * r_brace)
    ))
  )) / node(Type.Variable),
  format = Ct(dollar * (
    format_capture + (
    l_brace * format_capture * (
      r_brace +
      (colon * (
        (slash * format_modifier * r_brace) +
        (P('+') * if_text * r_brace) +
        (P('?') * if_till_colon_text * colon * else_text * r_brace) +
        (P('-') * else_text * r_brace) +
        (else_text * r_brace)
      ))
    ))
  )) / node(Type.Format),
})

--- Parses the given input into a snippet tree.
--- @param input string
--- @return vim.snippet.Node<vim.snippet.SnippetData>
function M.parse(input)
  local snippet = G:match(input)
  assert(snippet, 'snippet parsing failed')
  return snippet --- @type vim.snippet.Node<vim.snippet.SnippetData>
end

return M
