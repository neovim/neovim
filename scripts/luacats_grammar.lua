--[[!
LPEG grammar for LuaCATS
]]

local lpeg = vim.lpeg
local P, R, S = lpeg.P, lpeg.R, lpeg.S
local C, Ct, Cg = lpeg.C, lpeg.Ct, lpeg.Cg

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
local letter = R('az', 'AZ')
local num = R('09')

--- @param x string | vim.lpeg.Pattern
local function Pf(x)
  return fill * P(x) * fill
end

--- @param x string | vim.lpeg.Pattern
local function Plf(x)
  return fill * P(x)
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

local colon = Pf(':')
local ellipsis = P('...')
local ident_first = P('_') + letter
local ident = ident_first * rep(ident_first + num)
local opt_ident = ident * opt(P('?'))
local ty_ident_sep = S('-._')
local ty_ident = ident * rep(ty_ident_sep * ident)
local string_single = P "'" * rep(any - P "'") * P "'"
local string_double = P('"') * rep(any - P('"')) * P('"')
local generic = P('`') * ty_ident * P('`')
local literal = string_single + string_double + (opt(P('-')) * rep1(num)) + P('false') + P('true')
local ty_prims = ty_ident + literal + generic

local array_postfix = rep1(Plf('[]'))
local opt_postfix = rep1(Plf('?'))
local rep_array_opt_postfix = rep(array_postfix + opt_postfix)

local typedef = P({
  'typedef',
  typedef = C(v.type),

  type = v.ty * rep_array_opt_postfix * rep(Pf('|') * v.ty * rep_array_opt_postfix),
  ty = v.composite + paren(v.typedef),
  composite = (v.types * array_postfix) + (v.types * opt_postfix) + v.types,
  types = v.generics + v.kv_table + v.tuple + v.dict + v.table_literal + v.fun + ty_prims,

  tuple = Pf('[') * comma1(v.type) * Plf(']'),
  dict = Pf('{') * comma1(Pf('[') * v.type * Pf(']') * colon * v.type) * Plf('}'),
  kv_table = Pf('table') * Pf('<') * v.type * Pf(',') * v.type * Plf('>'),
  table_literal = Pf('{') * comma1(opt_ident * Pf(':') * v.type) * Plf('}'),
  fun_param = (opt_ident + ellipsis) * opt(colon * v.type),
  fun_ret = v.type + (ellipsis * opt(colon * v.type)),
  fun = Pf('fun') * paren(comma(v.fun_param)) * opt(Pf(':') * comma1(v.fun_ret)),
  generics = P(ty_ident) * Pf('<') * comma1(v.type) * Plf('>'),
}) / function(match)
  return vim.trim(match):gsub('^%((.*)%)$', '%1'):gsub('%?+', '?')
end

local opt_exact = opt(Cg(Pf('(exact)'), 'access'))
local access = P('private') + P('protected') + P('package')
local caccess = Cg(access, 'access')
local desc_delim = Sf '#:' + ws
local desc = Cg(rep(any), 'desc')
local opt_desc = opt(desc_delim * desc)
local ty_name = Cg(ty_ident, 'name')
local opt_parent = opt(colon * Cg(ty_ident, 'parent'))
local lname = (ident + ellipsis) * opt(P('?'))

local grammar = P {
  rep1(P('@') * (v.ats + v.ext_ats)),

  ats = annot('param', Cg(lname, 'name') * ws * v.ctype * opt_desc)
    + annot('return', comma1(Ct(v.ctype * opt(ws * (ty_name + Cg(ellipsis, 'name'))))) * opt_desc)
    + annot('type', comma1(Ct(v.ctype)) * opt_desc)
    + annot('cast', ty_name * ws * opt(Sf('+-')) * v.ctype)
    + annot('generic', ty_name * opt(colon * v.ctype))
    + annot('class', opt_exact * opt(paren(caccess)) * fill * ty_name * opt_parent)
    + annot('field', opt(caccess * ws) * v.field_name * ws * v.ctype * opt_desc)
    + annot('operator', ty_name * opt(paren(Cg(v.ctype, 'argtype'))) * colon * v.ctype)
    + annot(access)
    + annot('deprecated')
    + annot('alias', ty_name * opt(ws * v.ctype))
    + annot('enum', ty_name)
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
  ty_index = C(Pf('[') * typedef * fill * P(']')),
  ctype = Cg(typedef, 'type'),
}

return grammar --[[@as nvim.luacats.grammar]]
