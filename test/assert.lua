--- @class test.assert
local M = {}

local FORMAT_DEPTH = 100

--- @param value any
--- @return string
local function format_value(value)
  if type(value) == 'string' then
    return string.format('%q', value)
  end

  local ok, inspected = pcall(vim.inspect, value, { depth = FORMAT_DEPTH })
  if ok then
    return inspected
  end

  return tostring(value)
end

--- @param condition boolean
--- @param value any
--- @param context any
--- @param fallback string
local function assert_value(condition, value, context, fallback)
  if not condition then
    local message = context ~= nil and tostring(context) or fallback
    error(message, 0)
  end
  return value
end

--- @param expected any
--- @param actual any
--- @param comparator string
--- @return string
local function comparison_message(expected, actual, comparator)
  return ('Expected values to be %s.\nExpected:\n%s\nActual:\n%s'):format(
    comparator,
    format_value(expected),
    format_value(actual)
  )
end

--- @param expected any
--- @param actual any
--- @param context? any
--- @return any
function M.eq(expected, actual, context)
  return assert_value(
    vim.deep_equal(expected, actual),
    actual,
    context,
    comparison_message(expected, actual, 'equal')
  )
end

--- @param expected any
--- @param actual any
--- @param context? any
--- @return any
function M.neq(expected, actual, context)
  return assert_value(
    not vim.deep_equal(expected, actual),
    actual,
    context,
    ('Expected values to differ.\nValue:\n%s'):format(format_value(actual))
  )
end

--- @param value any
--- @param context? any
--- @return any
function M.is_true(value, context)
  return M.eq(true, value, context)
end

--- @param value any
--- @param context? any
--- @return any
function M.is_false(value, context)
  return M.eq(false, value, context)
end

-- TODO(lewis6991): remove these aliases
M.True = M.is_true
M.False = M.is_false
M.equals = M.eq
M.Equal = M.eq

return setmetatable(M, {
  --- @param condition any
  --- @param message? string
  --- @param level? integer
  __call = function(_, condition, message, level, ...)
    if condition then
      return condition, message, level, ...
    end

    error(message or 'assertion failed!', (type(level) == 'number' and level or 1) + 1)
  end,
})
