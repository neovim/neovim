--[[!
LPEG grammar for LuaCATS
]]

local lpeg = vim.lpeg
local P, R, S = lpeg.P, lpeg.R, lpeg.S
local Ct, Cg = lpeg.Ct, lpeg.Cg

--- @param x vim.lpeg.Pattern
local function rep(x)
  return x ^ 0
end

--- @param x vim.lpeg.Pattern
local function rep1(x)
  return x ^ 1
end

--- @param x vim.lpeg.Pattern
local function opt(x)
  return x ^ -1
end

local nl = P('\r\n') + P('\n')
local ws = rep1(S(' \t') + nl)
local fill = opt(ws)

local any = P(1) -- (consume one character)
local letter = R('az', 'AZ') + S('_$')
local num = R('09')
local ident = letter * rep(letter + num + S '-.')
local string_single = P "'" * rep(any - P "'") * P "'"
local string_double = P '"' * rep(any - P '"') * P '"'

local literal = (string_single + string_double + (opt(P '-') * num) + P 'false' + P 'true')

local lname = (ident + P '...') * opt(P '?')

--- @param x string
local function Pf(x)
  return fill * P(x) * fill
end

--- @param x string
local function Sf(x)
  return fill * S(x) * fill
end

--- @param x vim.lpeg.Pattern
local function comma(x)
  return x * rep(Pf ',' * x)
end

--- @param x vim.lpeg.Pattern
local function parenOpt(x)
  return (Pf('(') * x * fill * P(')')) + x
end

--- @type table<string,vim.lpeg.Pattern>
local v = setmetatable({}, {
  __index = function(_, k)
    return lpeg.V(k)
  end,
})

local desc_delim = Sf '#:' + ws

--- @class nvim.luacats.Param
--- @field kind 'param'
--- @field name string
--- @field type string
--- @field desc? string

--- @class nvim.luacats.Return
--- @field kind 'return'
--- @field [integer] { type: string, name?: string}
--- @field desc? string

--- @class nvim.luacats.Generic
--- @field kind 'generic'
--- @field name string
--- @field type? string

--- @class nvim.luacats.Class
--- @field kind 'class'
--- @field name string
--- @field parent? string

--- @class nvim.luacats.Field
--- @field kind 'field'
--- @field name string
--- @field type string
--- @field desc? string
--- @field access? 'private'|'protected'|'package'

--- @class nvim.luacats.Note
--- @field desc? string

--- @alias nvim.luacats.grammar.result
--- | nvim.luacats.Param
--- | nvim.luacats.Return
--- | nvim.luacats.Generic
--- | nvim.luacats.Class
--- | nvim.luacats.Field
--- | nvim.luacats.Note

--- @class nvim.luacats.grammar
--- @field match fun(self, input: string): nvim.luacats.grammar.result?

local grammar = P {
  rep1(P('@') * (v.ats + v.ext_ats)),

  ats = v.at_param
    + v.at_return
    + v.at_type
    + v.at_cast
    + v.at_generic
    + v.at_class
    + v.at_field
    + v.at_access
    + v.at_deprecated
    + v.at_alias
    + v.at_enum
    + v.at_see
    + v.at_diagnostic
    + v.at_overload
    + v.at_meta,

  ext_ats = v.ext_at_note + v.ext_at_since + v.ext_at_nodoc + v.ext_at_brief,

  at_param = Ct(
    Cg(P('param'), 'kind')
      * ws
      * Cg(lname, 'name')
      * ws
      * parenOpt(Cg(v.ltype, 'type'))
      * opt(desc_delim * Cg(rep(any), 'desc'))
  ),

  at_return = Ct(
    Cg(P('return'), 'kind')
      * ws
      * parenOpt(comma(Ct(Cg(v.ltype, 'type') * opt(ws * Cg(ident, 'name')))))
      * opt(desc_delim * Cg(rep(any), 'desc'))
  ),

  at_type = Ct(
    Cg(P('type'), 'kind')
      * ws
      * parenOpt(comma(Ct(Cg(v.ltype, 'type'))))
      * opt(desc_delim * Cg(rep(any), 'desc'))
  ),

  at_cast = Ct(
    Cg(P('cast'), 'kind') * ws * Cg(lname, 'name') * ws * opt(Sf('+-')) * Cg(v.ltype, 'type')
  ),

  at_generic = Ct(
    Cg(P('generic'), 'kind') * ws * Cg(ident, 'name') * opt(Pf ':' * Cg(v.ltype, 'type'))
  ),

  at_class = Ct(
    Cg(P('class'), 'kind')
      * ws
      * opt(P('(exact)') * ws)
      * Cg(lname, 'name')
      * opt(Pf(':') * Cg(lname, 'parent'))
  ),

  at_field = Ct(
    Cg(P('field'), 'kind')
      * ws
      * opt(Cg(Pf('private') + Pf('package') + Pf('protected'), 'access'))
      * Cg(lname, 'name')
      * ws
      * Cg(v.ltype, 'type')
      * opt(desc_delim * Cg(rep(any), 'desc'))
  ),

  at_access = Ct(Cg(P('private') + P('protected') + P('package'), 'kind')),

  at_deprecated = Ct(Cg(P('deprecated'), 'kind')),

  -- Types may be provided on subsequent lines
  at_alias = Ct(Cg(P('alias'), 'kind') * ws * Cg(lname, 'name') * opt(ws * Cg(v.ltype, 'type'))),

  at_enum = Ct(Cg(P('enum'), 'kind') * ws * Cg(lname, 'name')),

  at_see = Ct(Cg(P('see'), 'kind') * ws * opt(Pf('#')) * Cg(rep(any), 'desc')),
  at_diagnostic = Ct(Cg(P('diagnostic'), 'kind') * ws * opt(Pf('#')) * Cg(rep(any), 'desc')),
  at_overload = Ct(Cg(P('overload'), 'kind') * ws * Cg(v.ltype, 'type')),
  at_meta = Ct(Cg(P('meta'), 'kind')),

  --- Custom extensions
  ext_at_note = Ct(Cg(P('note'), 'kind') * ws * Cg(rep(any), 'desc')),

  -- TODO only consume 1 line
  ext_at_since = Ct(Cg(P('since'), 'kind') * ws * Cg(rep(any), 'desc')),

  ext_at_nodoc = Ct(Cg(P('nodoc'), 'kind')),
  ext_at_brief = Ct(Cg(P('brief'), 'kind') * opt(ws * Cg(rep(any), 'desc'))),

  ltype = v.ty_union + Pf '(' * v.ty_union * fill * P ')',

  ty_union = v.ty_opt * rep(Pf '|' * v.ty_opt),
  ty = v.ty_fun + ident + v.ty_table + literal,
  ty_param = Pf '<' * comma(v.ltype) * fill * P '>',
  ty_opt = v.ty * opt(v.ty_param) * opt(P '[]') * opt(P '?'),

  table_key = (Pf '[' * literal * Pf ']') + lname,
  table_elem = v.table_key * Pf ':' * v.ltype,
  ty_table = Pf '{' * comma(v.table_elem) * Pf '}',

  fun_param = lname * opt(Pf ':' * v.ltype),
  ty_fun = Pf 'fun(' * rep(comma(v.fun_param)) * fill * P ')' * opt(Pf ':' * comma(v.ltype)),
}

return grammar --[[@as nvim.luacats.grammar]]
