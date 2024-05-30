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

local ws = rep1(S(' \t'))
local fill = opt(ws)

local any = P(1) -- (consume one character)
local letter = R('az', 'AZ') + S('_$')
local num = R('09')
local ident = letter * rep(letter + num + S '-.')
local string_single = P "'" * rep(any - P "'") * P "'"
local string_double = P('"') * rep(any - P('"')) * P('"')

local literal = (string_single + string_double + (opt(P('-')) * num) + P('false') + P('true'))

local lname = (ident + P('...')) * opt(P('?'))

--- @param x string
local function Pf(x)
  return fill * P(x) * fill
end

--- @param x string
local function Sf(x)
  return fill * S(x) * fill
end

--- @param x vim.lpeg.Pattern
local function paren(x)
  return Pf('(') * x * fill * P(')')
end

--- @param x vim.lpeg.Pattern
local function parenOpt(x)
  return paren(x) + x
end

--- @param x vim.lpeg.Pattern
local function comma1(x)
  return parenOpt(x * rep(Pf(',') * x))
end

--- @param x vim.lpeg.Pattern
local function comma(x)
  return opt(comma1(x))
end

--- @type table<string,vim.lpeg.Pattern>
local v = setmetatable({}, {
  __index = function(_, k)
    return lpeg.V(k)
  end,
})

local colon = Pf(':')
local opt_exact = opt(Cg(Pf('(exact)'), 'access'))
local access = P('private') + P('protected') + P('package')
local caccess = Cg(access, 'access')
local desc_delim = Sf '#:' + ws
local desc = Cg(rep(any), 'desc')
local opt_desc = opt(desc_delim * desc)
local cname = Cg(ident, 'name')
local opt_parent = opt(colon * Cg(ident, 'parent'))

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
--- @field access? 'private'|'protected'|'package'

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

local function annot(nm, pat)
  if type(nm) == 'string' then
    nm = P(nm)
  end
  if pat then
    return Ct(Cg(P(nm), 'kind') * fill * pat)
  end
  return Ct(Cg(P(nm), 'kind'))
end

local grammar = P {
  rep1(P('@') * (v.ats + v.ext_ats)),

  ats = annot('param', Cg(lname, 'name') * ws * v.ctype * opt_desc)
    + annot('return', comma1(Ct(v.ctype * opt(ws * cname))) * opt_desc)
    + annot('type', comma1(Ct(v.ctype)) * opt_desc)
    + annot('cast', cname * ws * opt(Sf('+-')) * v.ctype)
    + annot('generic', cname * opt(colon * v.ctype))
    + annot('class', opt_exact * opt(paren(caccess)) * fill * cname * opt_parent)
    + annot('field', opt(caccess * ws) * v.field_name * ws * v.ctype * opt_desc)
    + annot('operator', cname * opt(paren(Cg(v.ltype, 'argtype'))) * colon * v.ctype)
    + annot(access)
    + annot('deprecated')
    + annot('alias', cname * opt(ws * v.ctype))
    + annot('enum', cname)
    + annot('overload', v.ctype)
    + annot('see', opt(desc_delim) * desc)
    + annot('diagnostic', opt(desc_delim) * desc)
    + annot('meta'),

  --- Custom extensions
  ext_ats = (
    annot('note', desc)
    + annot('since', desc)
    + annot('nodoc')
    + annot('inlinedoc')
    + annot('brief', desc)
  ),

  field_name = Cg(lname + (v.ty_index * opt(P('?'))), 'name'),

  ctype = parenOpt(Cg(v.ltype, 'type')),
  ltype = parenOpt(v.ty_union),

  ty_union = v.ty_opt * rep(Pf('|') * v.ty_opt),
  ty = v.ty_fun + ident + v.ty_table + literal + paren(v.ty) + v.ty_generic + v.ty_tuple,
  ty_param = Pf('<') * comma1(v.ltype) * fill * P('>'),
  ty_opt = v.ty * opt(v.ty_param) * opt(P('[]')) * opt(P('?')),
  ty_index = (Pf('[') * (v.ltype + ident + rep1(num)) * fill * P(']')),
  table_key = v.ty_index + lname,
  table_elem = v.table_key * colon * v.ltype,
  ty_table = Pf('{') * comma1(v.table_elem) * fill * P('}'),
  fun_param = lname * opt(colon * v.ltype),
  ty_fun = Pf('fun') * paren(comma(lname * opt(colon * v.ltype))) * opt(colon * comma1(v.ltype)),
  ty_generic = P('`') * letter * P('`'),
  ty_tuple = Pf('[') * comma(v.ty_opt) * fill * P(']'),
}

return grammar --[[@as nvim.luacats.grammar]]
