--- @class nvim.c_grammar.Proto
--- @field [1] 'proto'
--- @field name string
--- @field return_type string
--- @field parameters string[][]
--- @field attrs table<string,any>
--- @field attrs1 table<string,any>
--- @field static? true
--- @field inline? true

--- @class nvim.c_grammar.Preproc
--- @field [1] 'preproc'
--- @field name string
--- @field body string

--- @class nvim.c_grammar.Keyset
--- @field [1] 'keyset'
--- @field name string
--- @field fields {name:string, type:string}[]

--- @class nvim.c_grammar.Empty
--- @field [1] 'empty'

--- @class nvim.c_grammar.Comment
--- @field [1] 'comment'
--- @field comment string

--- @alias nvim.c_grammar.Result
--- | nvim.c_grammar.Proto
--- | nvim.c_grammar.Keyset
--- | nvim.c_grammar.Preproc
--- | nvim.c_grammar.Empty
--- | nvim.c_grammar.Comment

--- @class nvim.c_grammar
--- @field match fun(self, input: string): nvim.c_grammar.Result[]

local lpeg = vim.lpeg

-- lpeg grammar for building api metadata and documentation
local P, R, S = lpeg.P, lpeg.R, lpeg.S
local C, Cmt, Ct, Cc, Cg = lpeg.C, lpeg.Cmt, lpeg.Ct, lpeg.Cc, lpeg.Cg

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
local id = letter * rep(letter + num)
local nl = P('\r\n') + P('\n')
local not_nl = (S('\\') * nl) + (any - nl)
local space = S(' \t')
local ws = space + nl
local fill1 = rep1(ws)
local preproc_fill1 = rep1(space)
local fill = rep(ws)

local c_comment = P('//') * rep(not_nl)
local cdoc_comment = P('///') * opt(Ct(Cc('comment') * Cg(rep(space) * rep(not_nl), 'comment')))

local dllexport = P('DLLEXPORT') * fill1

--- @param x string
local function Pf(x)
  return fill * P(x) * fill
end

local typed_container = (
  (P('ArrayOf') + P('DictionaryOf') + P('Dict'))
  * P('(')
  * rep1(any - P(')'))
  * P(')')
)

local c_id = typed_container + id
local c_void = P('void')

local c_param_type = (
  ((P('Error') * Pf('*')) * Cc('error'))
  + ((P('Arena') * Pf('*')) * Cc('arena'))
  + ((P('lua_State') * Pf('*')) * Cc('lstate'))
  + (
    C(opt(P('struct') * fill1) * opt(P('const ')) * c_id * rep(fill * (P('const') + P('*')))) * fill
  )
)

--- @param x vim.lpeg.Pattern
local function comma1(x)
  return x * rep(Pf(',') * x)
end

local array = P('[') * rep(any - P(']')) * P(']')

local c_return_type = c_param_type + (C(c_void) * fill1)
local c_param = Ct((c_param_type * C(c_id * rep(array)) * rep(fill * C(id))) + C(Pf('...')))
local c_params = Ct(comma1(c_param) + c_void)

local ignore_line = rep1(not_nl) * nl
local empty_line = Ct(Cc('empty') * nl * nl)

--- @param kind string
local function attrs(kind)
  local attr = P('FUNC_')
    * P(kind:upper())
    * S('_')
    * C(id)
    * opt(P('(') * Ct(comma1(C(rep1(num)))) * P(')'))

  return Cmt(rep(fill * Ct(attr)), function(_, pos, ...)
    local r = {} --- @type table<string,any>
    for i = 1, select('#', ...) do
      local arg = select(i, ...)
      if type(arg) == 'table' then
        --- @type string, any
        local name, a = unpack(arg)
        local v --- @type any
        if not a then
          v = true
        elseif #a == 1 then
          v = tonumber(a[1]) or a[1]
        else
          v = a
        end
        r[name:lower()] = v
      end
    end

    return pos, r
  end)
end

local c_preproc = Ct(
  Cc('preproc')
    * Pf('#')
    * Cg(id + rep1(num), 'name')
    * opt(preproc_fill1 * Cg(rep(not_nl), 'body'))
)

local c_proto = Ct(
  Cc('proto')
    * opt(dllexport)
    * opt(Cg(P('static') * fill * Cc(true), 'static'))
    * opt(Cg(P('inline') * fill * Cc(true), 'inline'))
    * Cg(c_return_type, 'return_type')
    * Cg(c_id, 'name')
    * (Pf('(') * Cg(c_params, 'parameters') * Pf(')'))
    * Cg(attrs('api'), 'attrs')
    * Cg(attrs('attr'), 'attrs1')
    * fill
    * (P(';') + P('{'))
)

local c_field = Ct(Cg(c_id, 'type') * fill1 * Cg(c_id, 'name') * Pf(';'))
local c_keyset = Ct(
  Cc('keyset')
    * (P('typedef') * Pf('struct') * (Pf('{')) * Cg(Ct(rep1(c_field)), 'fields') * Pf('}') * (Pf(
      'Dict'
    ) * Pf('(') * Cg(id, 'name') * Pf(')')))
    * P(';')
)

local grammar = Ct(
  rep1(empty_line + c_proto + cdoc_comment + c_comment + c_preproc + fill1 + c_keyset + ignore_line)
) --[[@as nvim.c_grammar]]

return { grammar = grammar, typed_container = typed_container }
