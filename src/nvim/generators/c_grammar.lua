local lpeg = vim.lpeg

-- lpeg grammar for building api metadata from a set of header files. It
-- ignores comments and preprocessor commands and parses a very small subset
-- of C prototypes with a limited set of types
local P, R, S = lpeg.P, lpeg.R, lpeg.S
local C, Ct, Cc, Cg = lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.Cg

--- @param pat vim.lpeg.Pattern
local function rep(pat)
  return pat ^ 0
end

--- @param pat vim.lpeg.Pattern
local function rep1(pat)
  return pat ^ 1
end

--- @param pat vim.lpeg.Pattern
local function opt(pat)
  return pat ^ -1
end

local any = P(1) -- (consume one character)
local letter = R('az', 'AZ') + S('_$')
local num = R('09')
local alpha = letter + num
local nl = P('\r\n') + P('\n')
local not_nl = any - nl
local space = S(' \t')
local ws = space + nl
local fill = rep(ws)
local c_comment = P('//') * rep(not_nl)
local cdoc_comment = P('///') * opt(Ct(Cg(rep(space) * rep(not_nl), 'comment')))
local c_preproc = P('#') * rep(not_nl)
local dllexport = P('DLLEXPORT') * rep1(ws)

local typed_container = ((P('ArrayOf(') + P('DictOf(') + P('Dict(')) * rep1(any - P(')')) * P(')'))

local c_id = (typed_container + (letter * rep(alpha)))
local c_void = P('void')

local c_param_type = (
  ((P('Error') * fill * P('*') * fill) * Cc('error'))
  + ((P('Arena') * fill * P('*') * fill) * Cc('arena'))
  + ((P('lua_State') * fill * P('*') * fill) * Cc('lstate'))
  + C(opt(P('const ')) * c_id * rep1(ws) * rep1(P('*')))
  + (C(c_id) * rep1(ws))
)

local c_type = (C(c_void) * (ws ^ 1)) + c_param_type
local c_param = Ct(c_param_type * C(c_id))
local c_param_list = c_param * (fill * (P(',') * fill * c_param) ^ 0)
local c_params = Ct(c_void + c_param_list)

local impl_line = (any - P('}')) * opt(rep(not_nl)) * nl

local ignore_line = rep1(not_nl) * nl

local empty_line = Ct(Cc('empty') * nl * nl)

local c_proto = Ct(
  Cc('proto')
    * opt(dllexport)
    * opt(Cg(P('static') * fill * Cc(true), 'static'))
    * Cg(c_type, 'return_type')
    * Cg(c_id, 'name')
    * fill
    * (P('(') * fill * Cg(c_params, 'parameters') * fill * P(')'))
    * Cg(Cc(false), 'fast')
    * (fill * Cg((P('FUNC_API_SINCE(') * C(rep1(num))) * P(')'), 'since') ^ -1)
    * (fill * Cg((P('FUNC_API_DEPRECATED_SINCE(') * C(rep1(num))) * P(')'), 'deprecated_since') ^ -1)
    * (fill * Cg((P('FUNC_API_FAST') * Cc(true)), 'fast') ^ -1)
    * (fill * Cg((P('FUNC_API_RET_ALLOC') * Cc(true)), 'ret_alloc') ^ -1)
    * (fill * Cg((P('FUNC_API_NOEXPORT') * Cc(true)), 'noexport') ^ -1)
    * (fill * Cg((P('FUNC_API_REMOTE_ONLY') * Cc(true)), 'remote_only') ^ -1)
    * (fill * Cg((P('FUNC_API_LUA_ONLY') * Cc(true)), 'lua_only') ^ -1)
    * (fill * (Cg(P('FUNC_API_TEXTLOCK_ALLOW_CMDWIN') * Cc(true), 'textlock_allow_cmdwin') + Cg(
      P('FUNC_API_TEXTLOCK') * Cc(true),
      'textlock'
    )) ^ -1)
    * (fill * Cg((P('FUNC_API_REMOTE_IMPL') * Cc(true)), 'remote_impl') ^ -1)
    * (fill * Cg((P('FUNC_API_COMPOSITOR_IMPL') * Cc(true)), 'compositor_impl') ^ -1)
    * (fill * Cg((P('FUNC_API_CLIENT_IMPL') * Cc(true)), 'client_impl') ^ -1)
    * (fill * Cg((P('FUNC_API_CLIENT_IGNORE') * Cc(true)), 'client_ignore') ^ -1)
    * fill
    * (P(';') + (P('{') * nl + (impl_line ^ 0) * P('}')))
)

local dict_key = P('DictKey(') * Cg(rep1(any - P(')')), 'dict_key') * P(')')
local keyset_field =
  Ct(Cg(c_id, 'type') * ws * Cg(c_id, 'name') * fill * (dict_key ^ -1) * fill * P(';') * fill)
local c_keyset = Ct(
  P('typedef')
    * ws
    * P('struct')
    * fill
    * P('{')
    * fill
    * Cg(Ct(keyset_field ^ 1), 'fields')
    * P('}')
    * fill
    * P('Dict')
    * fill
    * P('(')
    * Cg(c_id, 'keyset_name')
    * fill
    * P(')')
    * P(';')
)

local grammar = Ct(
  rep1(empty_line + c_proto + cdoc_comment + c_comment + c_preproc + ws + c_keyset + ignore_line)
)
return { grammar = grammar, typed_container = typed_container }
