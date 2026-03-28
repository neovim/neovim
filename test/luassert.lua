--- @class test.luassert
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
    error(message, 3)
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
--- @return boolean
local function equal(expected, actual)
  return expected == actual or vim.deep_equal(expected, actual)
end

--- @param predicate fun(expected: any, actual: any): boolean
--- @param expected any
--- @param actual any
--- @param context any
--- @param comparator string
--- @return any
local function assert_comparison(predicate, expected, actual, context, comparator)
  return assert_value(
    predicate(expected, actual),
    actual,
    context,
    comparison_message(expected, actual, comparator)
  )
end

--- @param expected any
--- @param actual any
--- @param context? any
--- @return any
function M.eq(expected, actual, context)
  return assert_comparison(equal, expected, actual, context, 'equal')
end

M.same = M.eq
M.equals = M.eq
M.Equal = M.eq

--- @param value any
--- @param context? any
--- @return any
function M.True(value, context)
  return M.eq(true, value, context)
end

--- @param value any
--- @param context? any
--- @return any
function M.is_false(value, context)
  return M.eq(false, value, context)
end

M.is_true = M.True
M.False = M.is_false

--- @param expected any
--- @param actual any
--- @param context? any
--- @return any
function M.neq(expected, actual, context)
  return assert_value(
    not equal(expected, actual),
    actual,
    context,
    ('Expected values to differ.\nValue:\n%s'):format(format_value(actual))
  )
end

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
