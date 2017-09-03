local helpers = require('test.unit.helpers')(nil)

local ffi = helpers.ffi
local kvi_new = helpers.kvi_new
local kvi_init = helpers.kvi_init

local function new_pstate(strings)
  local strings_idx = 0
  local function get_line(_, ret_pline)
    strings_idx = strings_idx + 1
    local str = strings[strings_idx]
    local data, size
    if type(str) == 'string' then
      data = str
      size = #str
    elseif type(str) == 'nil' then
      data = nil
      size = 0
    elseif type(str) == 'table' then
      data = str.data
      size = str.size
    elseif type(str) == 'function' then
      data, size = str()
      size = size or 0
    end
    ret_pline.data = data
    ret_pline.size = size
    ret_pline.allocated = false
  end
  local pline_init = {
    data = nil,
    size = 0,
    allocated = false,
  }
  local state = {
    reader = {
      get_line = get_line,
      cookie = nil,
      conv = {
        vc_type = 0,
        vc_factor = 1,
        vc_fail = false,
      },
    },
    pos = { line = 0, col = 0 },
    colors = kvi_new('ParserHighlight'),
    can_continuate = false,
  }
  local ret = ffi.new('ParserState', state)
  kvi_init(ret.reader.lines)
  kvi_init(ret.stack)
  return ret
end

local function intchar2lua(ch)
  ch = tonumber(ch)
  return (20 <= ch and ch < 127) and ('%c'):format(ch) or ch
end

local function pline2lua(pline)
  return ffi.string(pline.data, pline.size)
end

local function pstate_str(pstate, start, len)
  local str = nil
  local err = nil
  if start.line < pstate.reader.lines.size then
    local pstr = pline2lua(pstate.reader.lines.items[start.line])
    if start.col >= #pstr then
      err = 'start.col >= #pstr'
    else
      str = pstr:sub(tonumber(start.col) + 1, tonumber(start.col + len))
    end
  else
    err = 'start.line >= pstate.reader.lines.size'
  end
  return str, err
end

local function pstate_set_str(pstate, start, len, ret)
  ret = ret or {}
  ret.start = {
    line = tonumber(start.line),
    col = tonumber(start.col)
  }
  ret.len = tonumber(len)
  ret.str, ret.error = pstate_str(pstate, start, len)
  return ret
end

return {
  pline2lua = pline2lua,
  pstate_str = pstate_str,
  new_pstate = new_pstate,
  intchar2lua = intchar2lua,
  pstate_set_str = pstate_set_str,
}
