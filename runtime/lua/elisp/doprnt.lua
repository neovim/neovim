local b = require 'elisp.bytes'
local alloc = require 'elisp.alloc'
local M = {}
---@param format string
---@param ap (string|number)[]
---@param format_end false|number
---@return string
function M.doprnt(format, ap, format_end)
  if format_end then
    error('TODO')
  end
  local ap_idx = 0
  local function ap_get(t)
    ap_idx = ap_idx + 1
    local a = ap[ap_idx]
    assert(type(a) == t)
    return a
  end
  local fmt = require 'elisp.lread'.make_readcharfun(alloc.make_unibyte_string(format), 0)
  local buf = require 'elisp.print'.make_printcharfun()
  local c = fmt.read()
  while c ~= -1 do
    if c == b '%' then
      c = fmt.read()
      local flags = {}
      while true do
        if c == b '-' then
          flags.minus = true
        elseif c == b '+' then
          flags.plus = true
        elseif c == b ' ' then
          flags.space = true
        elseif c == b '0' then
          flags.zero = true
        else
          break
        end
        c = fmt.read()
      end
      local wid = 0
      if b '1' <= c and c <= b '9' then
        error('TODO')
      end
      if c == b '.' then
        error('TODO')
      end
      local maxmlen = 1
      local length_modifier
      for mlen = 1, maxmlen do
        if mlen == 1 and c == b 'l' then
          length_modifier = 'long'
        end
        if mlen == 1 and c == b 't' then
          length_modifier = 'pD'
        end
        if mlen == 1 and c == b 'l' then
          length_modifier = 'pI'
        end
        if mlen == 1 and c == b 'l' then
          if fmt.read() == b 'd' then
            length_modifier = 'pM'
          else
            fmt.unread()
          end
        end
      end
      if length_modifier then
        c = fmt.read()
      end
      if c == b 's' or c == 'S' then
        local minlen = flags.minus and -wid or wid
        local s = ap_get('string')
        if minlen > 0 then
          error('TODO')
        end
        buf.write(s)
        if minlen < 0 then
          error('TODO')
        end
        goto continue
      else
        error('TODO')
      end
    elseif c == b '`' then
      error('TODO')
    elseif c == b '\\' then
      error('TODO')
    else
      buf.write(c)
    end
    ::continue::
    c = fmt.read()
  end
  return buf.out()
end
return M
