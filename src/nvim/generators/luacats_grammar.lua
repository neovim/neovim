--[[!
LPEG grammar for LuaCATS

Currently only partially supports:
- @param
- @return
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
  return (Pf('(') * x ^ -1 * fill * P(')')) + x ^ -1
end

--- @type table<string,vim.lpeg.Pattern>
local v = setmetatable({}, {
  __index = function(_, k)
    return lpeg.V(k)
  end,
})

local desc_delim = Sf '#:' + ws

--- @class luacats.Param
--- @field kind 'param'
--- @field name string
--- @field type string
--- @field desc? string

--- @class luacats.Return
--- @field kind 'return'
--- @field [integer] { type: string, name?: string}
--- @field desc? string

--- @class luacats.Generic
--- @field kind 'generic'
--- @field name string
--- @field type? string

--- @alias luacats.grammar.result
--- | luacats.Param
--- | luacats.Return
--- | luacats.Generic

--- @class luacats.grammar
--- @field match fun(self, input: string): luacats.grammar.result?

local grammar = P {
  rep1(P('@') * v.ats),

  ats = (v.at_param + v.at_return + v.at_generic),

  at_param = Ct(
    Cg(P('param'), 'kind')
      * ws
      * Cg(lname, 'name')
      * ws
      * Cg(v.ltype, 'type')
      * opt(desc_delim * Cg(rep(any), 'desc'))
  ),

  at_return = Ct(
    Cg(P('return'), 'kind')
      * ws
      * parenOpt(comma(Ct(Cg(v.ltype, 'type') * opt(ws * Cg(ident, 'name')))))
      * opt(desc_delim * Cg(rep(any), 'desc'))
  ),

  at_generic = Ct(
    Cg(P('generic'), 'kind') * ws * Cg(ident, 'name') * opt(Pf ':' * Cg(v.ltype, 'type'))
  ),

  ltype = v.ty_union + Pf '(' * v.ty_union * fill * P ')',

  ty_union = v.ty_opt * rep(Pf '|' * v.ty_opt),
  ty = v.ty_fun + ident + v.ty_table + literal,
  ty_param = Pf '<' * comma(v.ltype) * fill * P '>',
  ty_opt = v.ty * opt(v.ty_param) * opt(P '[]') * opt(P '?'),

  table_key = (Pf '[' * literal * Pf ']') + lname,
  table_elem = v.table_key * Pf ':' * v.ltype,
  ty_table = Pf '{' * comma(v.table_elem) * Pf '}',

  fun_param = lname * opt(Pf ':' * v.ltype),
  ty_fun = Pf 'fun(' * rep(comma(v.fun_param)) * fill * P ')' * opt(Pf ':' * v.ltype),
}

return grammar --[[@as luacats.grammar]]
