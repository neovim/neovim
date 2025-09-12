-- Basic shim for LuaJIT's stringbuffer.
-- Note this does not implement the full API.
-- This is intentionally internal-only. If we want to expose it, we should
-- reimplement this a userdata and ship it as `string.buffer`
-- (minus the FFI stuff) for Lua 5.1.
local M = {}

local has_strbuffer, strbuffer = pcall(require, 'string.buffer')

if has_strbuffer then
  M.new = strbuffer.new

  -- Lua 5.1 does not have __len metamethod so we need to provide a len()
  -- function to use instead.

  --- @param buf vim._stringbuffer
  --- @return integer
  function M.len(buf)
    return #buf
  end

  return M
end

--- @class vim._stringbuffer
--- @field private buf string[]
--- @field package len integer absolute length of the `buf`
--- @field package skip_ptr integer
local StrBuffer = {}
StrBuffer.__index = StrBuffer

--- @return string
function StrBuffer:tostring()
  if #self.buf > 1 then
    self.buf = { table.concat(self.buf) }
  end

  -- assert(self.len == #(self.buf[1] or ''), 'len mismatch')

  if self.skip_ptr > 0 then
    if self.buf[1] then
      self.buf[1] = self.buf[1]:sub(self.skip_ptr + 1)
      self.len = self.len - self.skip_ptr
    end
    self.skip_ptr = 0
  end

  -- assert(self.len == #(self.buf[1] or ''), 'len mismatch')

  return self.buf[1] or ''
end

StrBuffer.__tostring = StrBuffer.tostring

--- @private
--- Efficiently peak at the first `n` characters of the buffer.
--- @param n integer
--- @return string
function StrBuffer:_peak(n)
  local skip, buf1 = self.skip_ptr, self.buf[1]
  if buf1 and (n + skip) < #buf1 then
    return buf1:sub(skip + 1, skip + n)
  end
  return self:tostring():sub(1, n)
end

--- @param chunk string
function StrBuffer:put(chunk)
  local s = tostring(chunk)
  self.buf[#self.buf + 1] = s
  self.len = self.len + #s
  return self
end

--- @param str string
function StrBuffer:set(str)
  return self:reset():put(str)
end

--- @param n integer
--- @return string
function StrBuffer:get(n)
  local r = self:_peak(n)
  self:skip(n)
  return r
end

--- @param n integer
function StrBuffer:skip(n)
  self.skip_ptr = math.min(self.len, self.skip_ptr + n)
  return self
end

function StrBuffer:reset()
  self.buf = {}
  self.skip_ptr = 0
  self.len = 0
  return self
end

function M.new()
  return setmetatable({}, StrBuffer):reset()
end

--- @param buf vim._stringbuffer
function M.len(buf)
  return buf.len - buf.skip_ptr
end

return M
