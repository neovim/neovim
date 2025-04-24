local m = vim.lpeg
local mt = getmetatable(m.P(0))
local re = vim.re

local M = {}

local letter = m.P(1) - m.S(',*?[]{}/\\')
local slash = m.P'/' * m.Cc(m.P'/')
local notslash = m.P(1) - m.P'/'
local notcomma = m.P(1) - m.S(',\\')
-- local star = m.P'*'
local eof = -1 * m.Cb('inseg') / function(flag)
                                   if flag then return #m.P'/'
                                   else return m.P(-1) end
                                 end

local function start_seg(p)
  return { s = p[2], e = true, n = 0 }
end

local function lookfor(t, p)
  t.n = t.n + 1
  t[t.n] = p
  return t
end

local function to_seg_end(t)
  t.e = notslash^0
  return t
end

local function end_seg(t)
  -- print(inspect(t))
  local seg_grammar = { 's' }
  if t.n > 0 then
    seg_grammar.s = t.s
    for i = 1, t.n do
      local rname = t[i][1]
      if not seg_grammar[rname] then
        if t[i].F then
          seg_grammar[rname] = t[i][2] + notslash * (notslash - m.P(t[i].F))^0 * m.V(rname)
        else
          seg_grammar[rname] = t[i][2] + notslash * m.V(rname)
        end
      end
      seg_grammar.s = seg_grammar.s * m.V(rname)
    end
    if t.e then
      seg_grammar.s = seg_grammar.s * t.e
    end
    return m.P(seg_grammar)
  else
    seg_grammar.s = t.s
    if t.e then
      seg_grammar.s = seg_grammar.s * t.e
    end
    return seg_grammar.s
  end
end

local function dseg(p)
  return m.P{ p + notslash^0 * m.P'/' * m.V(1) }
end

---@type Pattern
local g = nil -- for expand to use

local function mul_cond(a, b)
  -- print('mul_cond: ', inspect(a), inspect(b))
  if type(a) == 'string' then
    if type(b) == 'string' then
      return a .. b
    elseif type(b) == 'table' then
      for i = 1, #b do
        b[i] = a .. b[i]
      end
      return b
    else
      return a
    end
  elseif type(a) == 'table' then
    if type(b) == 'string' then
      for i = 1, #a do
        a[i] = a[i] .. b
      end
      return a
    elseif type(b) == 'table' then
      local res = {}
      local idx = 0
      for i = 1, #a do
        for j = 1, #b do
          idx = idx + 1
          res[idx] = a[i] .. b[j]
        end
      end
      return res
    else
      return a
    end
  else
    return b
  end
end

local function add_cond(a, b)
  -- print('add_cond: ', inspect(a), inspect(b))
  if type(a) == 'string' then
    if type(b) == 'string' then
      return { a, b }
    elseif type(b) == 'table' then
      table.insert(b, 1, a)
      return b
    end
  elseif type(a) == 'table' then
    if type(b) == 'string' then
      table.insert(a, b)
      return a
    elseif type(b) == 'table' then
      for i = 1, #b do
        table.insert(a, b[i])
        return a
      end
    end
  end
end

local function expand(a, b, inseg)
  -- print('expand: ', inspect(a), inspect(b))
  for i = 1, #a do
    if inseg then a[i] = '#' .. a[i] end
    a[i] = g:match(a[i] .. b)
  end
  local res = a[1]
  for i = 2, #a do
    res = res + a[i]
  end
  return res
end

local function codepoint(utf8_str)
  local codepoint = 0
  local byte_count = 0

  for i = 1, #utf8_str do
    local byte = utf8_str:byte(i)

    if byte_count ~= 0 then
      codepoint = bit.bor(bit.lshift(codepoint, 6), bit.band(byte, 0x3F))
      byte_count = byte_count - 1
    else
      if byte < 0x80 then
        codepoint = byte
      elseif byte < 0xE0 then
        byte_count = 1
        codepoint = bit.band(byte, 0x1F)
      elseif byte < 0xF0 then
        byte_count = 2
        codepoint = bit.band(byte, 0x0F)
      else
        byte_count = 3
        codepoint = bit.band(byte, 0x07)
      end
    end

    if byte_count == 0 then break end
  end

  return codepoint
end

local cont = m.R("\128\191")
local any_utf8 = m.R("\0\127")
               + m.R("\194\223") * cont
               + m.R("\224\239") * cont * cont
               + m.R("\240\244") * cont * cont * cont

local function class(inv, ranges)
  local patt = false
  if #ranges == 0 then
    if inv == '!' then return m.P'[!]'
    else return m.P'[]' end
  end
  for _, v in ipairs(ranges) do
    patt = patt + (type(v) == 'table' and m.utfR(codepoint(v[1]), codepoint(v[2])) or m.P(v))
  end
  if inv == '!' then
    patt = m.P(1) - patt
  end
  return patt - m.P'/'
end

local noopt_condlist = re.compile[[
  s <- '/' / '**' / . [^/*]* s
]]

local opt_tail = re.compile[[
  s <- (!'**' [^{/])* &'/'
]]

g = {
  'Glob',
  Glob     = (m.P'#' * m.Cg(m.Cc(true), 'inseg') + m.Cg(m.Cc(false), 'inseg')) *
             m.Cf(m.V'Element'^-1 * (slash * m.V'Element')^0 * (slash^-1 * eof), mt.__mul),
  Element  = m.V'DSeg' + m.V'DSEnd' + m.Cf(m.V'Segment' * (slash * m.V'Segment')^0 * (slash * eof + eof^-1), mt.__mul),
  DSeg     = m.P'**/' * ((m.V'Element' + eof) / dseg),
  DSEnd    = m.P'**' * -1 * m.Cc(m.P(1)^0),
  Segment  = (m.V'Word' / start_seg + m.Cc({ '', true }) / start_seg * (m.V'Star' * m.V'Word' % lookfor)) *
              (m.V'Star' * m.V'Word' % lookfor)^0 * (m.V'Star' * m.V'CheckBnd' % to_seg_end)^-1 / end_seg
             + m.V'Star' * m.V'CheckBnd' * m.Cc(notslash^0),
  CheckBnd = #m.P'/' + -1,

  Word     = -m.P'*' * m.Ct( m.V('FIRST')^-1 * m.C(m.V'WordAux') ),
  WordAux  = m.V'Branch' + m.Cf(m.V'Simple'^1 * m.V'Branch'^-1, mt.__mul),
  Simple   = m.Cg( m.V'Token' * (m.V'Token' % mt.__mul)^0 * (m.V'Boundary' % mt.__mul)^-1),
  Boundary = #m.P'/' * m.Cc(#m.P'/') + eof,
  Token    = m.V'Ques' + m.V'Class' + m.V'Escape' + m.V'Literal',
  Star     = m.P'*',
  Ques     = m.P'?' * m.Cc(notslash),
  Escape   = m.P'\\' * m.C(1) / m.P,
  Literal  = m.C(letter^1) / m.P,

  Branch   = m.Cmt(m.C(m.V'CondList'), function(s, i, p1, p2)
                                         -- p1 gets the CondList in string format, p2 is the transformed lua table by add_cond and mul_cond below
                                         -- this checks whether group condition p1 cannot be optimized
                                         -- noopt_condlist is the simple check that p1 doesn't include `/` or `**`
                                         if noopt_condlist:match(p1) then
                                           -- cannot optimize, we'll match till the end, return p2 and the string after group condtion `s:sub(i)`
                                           return #s + 1, p2, s:sub(i)
                                         end
                                         -- try to find the point to cut, i.e. the early position that we could stop
                                         -- opt_tail looks for the first `/` if between ending of our current group condition and the `/` there's no other group conditions or globstars
                                         local cut = opt_tail:match(s, i)
                                         if cut then
                                           -- we can optimize!
                                           -- we'll match till the cut point instead of end of s, so the first return is `cut`
                                           -- p2 and s:sub(i, cut - 1) is what to expand into lpeg object
                                           -- the last return value `true` is as a flag to tell expand function that we need to 
                                           -- transform EOF matches into &'/' lookahead predicates
                                           return cut, p2, s:sub(i, cut - 1), true
                                         else
                                           -- otherwise cannot optimize, and same as before
                                           return #s + 1, p2, s:sub(i)
                                         end
                                       end) / expand,
  -- add_cond is a fold capture to combine conditions separated with comma into a lua table
  CondList = m.Cf(m.P'{' * m.V'Cond' * (m.P',' * m.V'Cond')^1 * m.P'}', add_cond),
  -- mul_cond is a fold capture to multiply (Cartesian product) previous and current pattern
  Cond     = m.Cf((m.C((notcomma + m.P'\\' * 1 - m.S'{}')^1) + m.V'CondList')^1, mul_cond) + m.C(true),

  Class    = m.P'[' * m.C(m.P'!'^-1) * m.Ct(
              (m.Ct(m.C(any_utf8) * m.P'-' * m.C(any_utf8 - m.P']')) + m.C(any_utf8 - m.P']'))^0
            ) * m.P']' / class,

  FIRST    = m.Cg(m.P(function(s, i)
                        if letter:match(s, i) then return true, s:sub(i, i)
                        else return false end
                      end), 'F')
}

g = m.P(g)

function M.to_lpeg(pattern)
  local lpeg_pattern = g:match(pattern) --[[@as vim.lpeg.Pattern?]]
  assert(lpeg_pattern, 'Invalid glob')
  return lpeg_pattern
end

return M