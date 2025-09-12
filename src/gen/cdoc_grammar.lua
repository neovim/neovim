--[[!
LPEG grammar for C doc comments
]]

--- @class nvim.cdoc.Param
--- @field kind 'param'
--- @field name string
--- @field desc? string

--- @class nvim.cdoc.Return
--- @field kind 'return'
--- @field desc string

--- @class nvim.cdoc.Note
--- @field desc? string

--- @alias nvim.cdoc.grammar.result
--- | nvim.cdoc.Param
--- | nvim.cdoc.Return
--- | nvim.cdoc.Note

--- @class nvim.cdoc.grammar
--- @field match fun(self, input: string): nvim.cdoc.grammar.result?

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

local any = P(1) -- (consume one character)
local letter = R('az', 'AZ') + S('_$')
local ident = letter * rep(letter + R('09'))

local io = P('[') * (P('in') + P('out') + P('inout')) * P(']')

--- @param x string
local function Pf(x)
  return opt(ws) * P(x) * opt(ws)
end

--- @type table<string,vim.lpeg.Pattern>
local v = setmetatable({}, {
  __index = function(_, k)
    return lpeg.V(k)
  end,
})

local grammar = P {
  rep1(P('@') * v.ats),

  ats = v.at_param + v.at_return + v.at_deprecated + v.at_see + v.at_brief + v.at_note + v.at_nodoc,

  at_param = Ct(
    Cg(P('param'), 'kind') * opt(io) * ws * Cg(ident, 'name') * opt(ws * Cg(rep(any), 'desc'))
  ),

  at_return = Ct(Cg(P('return'), 'kind') * opt(S('s')) * opt(ws * Cg(rep(any), 'desc'))),

  at_deprecated = Ct(Cg(P('deprecated'), 'kind')),

  at_see = Ct(Cg(P('see'), 'kind') * ws * opt(Pf('#')) * Cg(rep(any), 'desc')),

  at_brief = Ct(Cg(P('brief'), 'kind') * ws * Cg(rep(any), 'desc')),

  at_note = Ct(Cg(P('note'), 'kind') * ws * Cg(rep(any), 'desc')),

  at_nodoc = Ct(Cg(P('nodoc'), 'kind')),
}

return grammar --[[@as nvim.cdoc.grammar]]
