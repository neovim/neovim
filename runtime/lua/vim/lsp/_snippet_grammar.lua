--- Grammar for LSP snippets, based on https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#snippet_syntax

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

--- Returns a function that unescapes occurrences of "special" characters.
---
--- @param special string
--- @return fun(match: string): string
local function escape_text(special)
  return function(match)
    local escaped = match:gsub('\\(.)', function(c)
      return special:find(c) and c or '\\' .. c
    end)
    return escaped
  end
end

-- Text nodes match "any character", but $, \, and } must be escaped.
local escapable = '$}\\'
local text = (backslash * S(escapable)) + (P(1) - S(escapable))
local text_0, text_1 = (text ^ 0) / escape_text(escapable), text ^ 1
-- Within choice nodes, \ also escapes comma and pipe characters.
local choice_text = C(((backslash * S(escapable .. ',|')) + (P(1) - S(escapable .. ',|'))) ^ 1)
  / escape_text(escapable .. ',|')
local if_text, else_text = Cg(text_0, 'if_text'), Cg(text_0, 'else_text')
-- Within format nodes, make sure we stop at /
local format_text = C(((backslash * S(escapable)) + (P(1) - S(escapable .. '/'))) ^ 1)
  / escape_text(escapable)
-- Within ternary condition format nodes, make sure we stop at :
local if_till_colon_text = Cg(
  C(((backslash * S(escapable)) + (P(1) - S(escapable .. ':'))) ^ 1) / escape_text(escapable),
  'if_text'
)

-- Matches the string inside //, allowing escaping of the closing slash.
local regex = Cg(((backslash * slash) + (P(1) - slash)) ^ 1, 'regex')

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
--- @class vim.snippet.TabstopData: { tabstop: number }
--- @class vim.snippet.TextData: { text: string }
--- @class vim.snippet.PlaceholderData: { tabstop: vim.snippet.TabstopData, value: vim.snippet.Node<any> }
--- @class vim.snippet.ChoiceData: { tabstop: vim.snippet.TabstopData, values: string[] }
--- @class vim.snippet.VariableData: { name: string, default?: vim.snippet.Node<any>, regex?: string, format?: vim.snippet.Node<vim.snippet.FormatData|vim.snippet.TextData>[], options?: string }
--- @class vim.snippet.FormatData: { capture: number, modifier?: string, if_text?: string, else_text?: string }
--- @class vim.snippet.SnippetData: { children: vim.snippet.Node<any>[] }

--- Returns a function that constructs a snippet node of the given type.
---
--- @generic T
--- @param type vim.snippet.Type
--- @return fun(data: T): vim.snippet.Node<T>
local function node(type)
  return function(data)
    return { type = type, data = data }
  end
end

-- stylua: ignore
local G = P({
  'snippet';
  snippet = Ct(Cg(
    Ct((
      V('any') +
      (Ct(Cg(text_1 / escape_text(escapable), 'text')) / node(Type.Text))
    ) ^ 1), 'children'
  )) / node(Type.Snippet),
  any_or_text = V('any') + (Ct(Cg(text_0 / escape_text(escapable), 'text')) / node(Type.Text)),
  any = V('placeholder') + V('tabstop') + V('choice') + V('variable'),
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
