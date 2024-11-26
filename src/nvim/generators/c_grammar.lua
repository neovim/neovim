-- lpeg grammar for building api metadata from a set of header files. It
-- ignores comments and preprocessor commands and parses a very small subset
-- of C prototypes with a limited set of types

--- @class nvim.c_grammar.Proto
--- @field [1] 'proto'
--- @field pos integer
--- @field endpos integer
--- @field fast boolean
--- @field name string
--- @field return_type string
--- @field parameters [string, string][]
--- @field static true?
--- @field inline true?

--- @class nvim.c_grammar.Preproc
--- @field [1] 'preproc'
--- @field content string

--- @class nvim.c_grammar.Empty
--- @field [1] 'empty'

--- @alias nvim.c_grammar.result
--- | nvim.c_grammar.Proto
--- | nvim.c_grammar.Preproc
--- | nvim.c_grammar.Empty

--- @class nvim.c_grammar
--- @field match fun(self, input: string): nvim.c_grammar.result[]

local lpeg = vim.lpeg

local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local C, Ct, Cc, Cg, Cp = lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cp

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

local any = P(1)
local letter = R('az', 'AZ') + S('_$')
local num = R('09')
local alpha = letter + num
local nl = P('\r\n') + P('\n')
local space = S(' \t')
local str = P('"') * rep((P('\\') * any) + (1 - P('"'))) * P('"')
local char = P("'") * (any - P("'")) * P("'")
local ws = space + nl
local wb = #-alpha -- word boundary
local id = letter * rep(alpha)

local comment_inline = P('/*') * rep(1 - P('*/')) * P('*/')
local comment = P('//') * rep(1 - nl) * nl
local preproc = Ct(Cc('preproc') * P('#') * Cg(rep(1 - nl) * nl, 'content'))

local fill = rep(ws + comment_inline + comment + preproc)

--- @param s string
--- @return vim.lpeg.Pattern
local function word(s)
  return fill * P(s) * wb * fill
end

--- @param x vim.lpeg.Pattern
local function comma1(x)
  return x * rep(fill * P(',') * fill * x)
end

--- @param v string
local function Pf(v)
  return fill * P(v) * fill
end

--- @param x vim.lpeg.Pattern
local function paren(x)
  return P('(') * fill * x * fill * P(')')
end

local cdoc_comment = P('///') * opt(Ct(Cg(rep(space) * rep(1 - nl), 'comment')))

local braces = P({
  'S',
  A = comment_inline + comment + preproc + str + char + (any - S('{}')),
  S = P('{') * rep(V('A')) * rep(V('S') + V('A')) * P('}'),
})

-- stylua: ignore start
local typed_container = P({
  'S',
  S = (
    (P('Union') * paren(comma1(V('ID'))))
    + (P('ArrayOf') * paren(id * opt(P(',') * fill * rep1(num))))
    + (P('DictOf') * paren(id))
    + (P('LuaRefOf') * paren(
      paren(comma1((V('ID') + str) * rep1(ws) * opt(P('*')) * id))
      * opt(P(',') * fill * opt(P('*')) * V('ID'))
    ))
    + (P('Dict') * paren(id))),
  ID = V('S') + id,
})
-- stylua: ignore end

local ptr_mod = word('restrict') + word('__restrict') + word('const')
local opt_ptr = rep(Pf('*') * opt(ptr_mod))

--- @param name string
--- @param var string
--- @return vim.lpeg.Pattern
local function attr(name, var)
  return Cg((P(name) * Cc(true)), var)
end

--- @param name string
--- @param var string
--- @return vim.lpeg.Pattern
local function attr_num(name, var)
  return Cg((P(name) * paren(C(rep1(num)))), var)
end

local fattr = (
  attr_num('FUNC_API_SINCE', 'since')
  + attr_num('FUNC_API_DEPRECATED_SINCE', 'deprecated_since')
  + attr('FUNC_API_FAST', 'fast')
  + attr('FUNC_API_RET_ALLOC', 'ret_alloc')
  + attr('FUNC_API_NOEXPORT', 'noexport')
  + attr('FUNC_API_REMOTE_ONLY', 'remote_only')
  + attr('FUNC_API_LUA_ONLY', 'lua_only')
  + attr('FUNC_API_TEXTLOCK_ALLOW_CMDWIN', 'textlock_allow_cmdwin')
  + attr('FUNC_API_TEXTLOCK', 'textlock')
  + attr('FUNC_API_REMOTE_IMPL', 'remote_impl')
  + attr('FUNC_API_COMPOSITOR_IMPL', 'compositor_impl')
  + attr('FUNC_API_CLIENT_IMPL', 'client_impl')
  + attr('FUNC_API_CLIENT_IGNORE', 'client_ignore')
  + (P('FUNC_') * rep(alpha) * opt(fill * paren(rep(1 - P(')') * any))))
)

local void = P('void') * wb

local api_param_type = (
  (word('Error') * opt_ptr * Cc('error'))
  + (word('Arena') * opt_ptr * Cc('arena'))
  + (word('lua_State') * opt_ptr * Cc('lstate'))
)

local ctype = C(
  opt(word('const'))
    * (
      typed_container
      -- 'unsigned' is a type modifier, and a type itself
      + (word('unsigned char') + word('unsigned'))
      + (word('struct') * fill * id)
      + id
    )
    * opt(word('const'))
    * opt_ptr
)

local return_type = (C(void) * fill) + ctype

-- stylua: ignore start
local params = Ct(
  (void * #P(')'))
  + comma1(Ct(
      (api_param_type + ctype)
      * fill
      * C(id)
      * rep(Pf('[') * rep(alpha) * Pf(']'))
      * rep(fill * fattr)
    ))
    * opt(Pf(',') * P('...'))
)
-- stylua: ignore end

local ignore_line = rep1(1 - nl) * nl
local empty_line = Ct(Cc('empty') * nl * nl)

local proto_name = opt_ptr * fill * id

-- __inline is used in MSVC
local decl_mod = (
  Cg(word('static') * Cc(true), 'static')
  + Cg((word('inline') + word('__inline')) * Cc(true), 'inline')
)

local proto = Ct(
  Cg(Cp(), 'pos')
    * Cc('proto')
    * -#P('typedef')
    * #alpha
    * opt(P('DLLEXPORT') * rep1(ws))
    * rep(decl_mod)
    * Cg(return_type, 'return_type')
    * fill
    * Cg(proto_name, 'name')
    * fill
    * paren(Cg(params, 'parameters'))
    * Cg(Cc(false), 'fast')
    * rep(fill * fattr)
    * Cg(Cp(), 'endpos')
    * (fill * (S(';') + braces))
)

local keyset_field = Ct(
  Cg(ctype, 'type')
    * fill
    * Cg(id, 'name')
    * fill
    * opt(P('DictKey') * paren(Cg(rep1(1 - P(')')), 'dict_key')))
    * Pf(';')
)

local keyset = Ct(
  P('typedef')
    * word('struct')
    * Pf('{')
    * Cg(Ct(rep1(keyset_field)), 'fields')
    * Pf('}')
    * P('Dict')
    * paren(Cg(id, 'keyset_name'))
    * Pf(';')
)

local grammar =
  Ct(rep1(empty_line + proto + cdoc_comment + comment + preproc + ws + keyset + ignore_line))

if arg[1] == '--test' then
  for i, t in ipairs({
    'void multiqueue_put_event(MultiQueue *self, Event event) {} ',
    'void *xmalloc(size_t size) {} ',
    {
      'struct tm *os_localtime_r(const time_t *restrict clock,',
      '                          struct tm *restrict result) FUNC_ATTR_NONNULL_ALL {}',
    },
    {
      '_Bool',
      '# 163 "src/nvim/event/multiqueue.c"',
      '    multiqueue_empty(MultiQueue *self)',
      '{}',
    },
    'const char *find_option_end(const char *arg, OptIndex *opt_idxp) {}',
    'bool semsg(const char *const fmt, ...) {}',
    'int32_t utf_ptr2CharInfo_impl(uint8_t const *p, uintptr_t const len) {}',
    'void ex_argdedupe(exarg_T *eap FUNC_ATTR_UNUSED) {}',
    'static TermKeySym register_c0(TermKey *tk, TermKeySym sym, unsigned char ctrl, const char *name) {}',
    'unsigned get_bkc_flags(buf_T *buf) {}',
    'char *xstpcpy(char *restrict dst, const char *restrict src) {}',
    'bool try_leave(const TryState *const tstate, Error *const err) {}',
    'void api_set_error(ErrorType errType) {}',

    -- Do not consume leading preproc statements
    {
      '#line 1 "D:/a/neovim/neovim/src\\nvim/mark.h"',
      'static __inline int mark_global_index(const char name)',
      '  FUNC_ATTR_CONST',
      '{}',
    },
    {
      '',
      '#line 1 "D:/a/neovim/neovim/src\\nvim/mark.h"',
      'static __inline int mark_global_index(const char name)',
      '{}',
    },
    {
      'size_t xstrlcpy(char *__restrict dst, const char *__restrict src, size_t dsize)',
      ' FUNC_ATTR_NONNULL_ALL',
      ' {}',
    },
  }) do
    if type(t) == 'table' then
      t = table.concat(t, '\n') .. '\n'
    end
    t = t:gsub(' +', ' ')
    local r = grammar:match(t)
    if not r then
      print('Test ' .. i .. ' failed')
      print('    |' .. table.concat(vim.split(t, '\n'), '\n    |'))
    end
  end
end

return {
  grammar = grammar --[[@as nvim.c_grammar]],
  typed_container = typed_container,
}
