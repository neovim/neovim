local lpeg = require('lpeg')

-- lpeg grammar for building api metadata from a set of header files. It
-- ignores comments and preprocessor commands and parses a very small subset
-- of C prototypes with a limited set of types
local P, R, S = lpeg.P, lpeg.R, lpeg.S
local C, Ct, Cc, Cg = lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.Cg

local any = P(1) -- (consume one character)
local letter = R('az', 'AZ') + S('_$')
local num = R('09')
local alpha = letter + num
local nl = P('\r\n') + P('\n')
local not_nl = any - nl
local ws = S(' \t') + nl
local fill = ws ^ 0
local c_comment = P('//') * (not_nl ^ 0)
local c_preproc = P('#') * (not_nl ^ 0)
local typed_container =
  (P('ArrayOf(') + P('DictionaryOf(')) * ((any - P(')')) ^ 1) * P(')')
local c_id = (
  typed_container +
  (letter * (alpha ^ 0))
)
local c_void = P('void')
local c_param_type = (
  ((P('Error') * fill * P('*') * fill) * Cc('error')) +
  C((P('const ') ^ -1) * (c_id) * (ws ^ 1) * P('*')) +
  (C(c_id) * (ws ^ 1))
  )
local c_type = (C(c_void) * (ws ^ 1)) + c_param_type
local c_param = Ct(c_param_type * C(c_id))
local c_param_list = c_param * (fill * (P(',') * fill * c_param) ^ 0)
local c_params = Ct(c_void + c_param_list)
local c_proto = Ct(
  Cg(c_type, 'return_type') * Cg(c_id, 'name') *
  fill * P('(') * fill * Cg(c_params, 'parameters') * fill * P(')') *
  Cg(Cc(false), 'fast') *
  (fill * Cg((P('FUNC_API_SINCE(') * C(num ^ 1)) * P(')'), 'since') ^ -1) *
  (fill * Cg((P('FUNC_API_DEPRECATED_SINCE(') * C(num ^ 1)) * P(')'),
              'deprecated_since') ^ -1) *
  (fill * Cg((P('FUNC_API_FAST') * Cc(true)), 'fast') ^ -1) *
  (fill * Cg((P('FUNC_API_NOEXPORT') * Cc(true)), 'noexport') ^ -1) *
  (fill * Cg((P('FUNC_API_REMOTE_ONLY') * Cc(true)), 'remote_only') ^ -1) *
  (fill * Cg((P('FUNC_API_REMOTE_IMPL') * Cc(true)), 'remote_impl') ^ -1) *
  (fill * Cg((P('FUNC_API_BRIDGE_IMPL') * Cc(true)), 'bridge_impl') ^ -1) *
  (fill * Cg((P('FUNC_API_COMPOSITOR_IMPL') * Cc(true)), 'compositor_impl') ^ -1) *
  fill * P(';')
  )

local grammar = Ct((c_proto + c_comment + c_preproc + ws) ^ 1)
return {grammar=grammar, typed_container=typed_container}
