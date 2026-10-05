--- @class test.assert
local M = {}

local FORMAT_DEPTH = 100

--- @param value any
--- @return string
local function fmt(value)
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
--- @param message string
local function assert_value(condition, value, context, message)
  if not condition then
    error((context ~= nil and tostring(context) .. ': ' or '') .. message, 0)
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
    fmt(expected),
    fmt(actual)
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

--- Checks the supplied fields recursively, ignoring other record fields.
--- Lists must have the same length and order; their records may have extra fields.
--- Does not check the non-existence of a field.
---
--- Examples:
--- ```lua
--- local result = { id = 1, opts = { enabled = false, priority = 10 } }
--- eq_partial({ opts = { enabled = false } }, result) -- Passes.
--- eq(nil, result.missing) -- Check that a field is absent.
---
--- eq_partial({ { id = 1 } }, { { id = 1, name = 'test' } }) -- Passes.
--- eq_partial({ { id = 1 } }, { { id = 1 }, { id = 2 } }) -- Fails: extra list item.
--- ```
---
--- @param expected any
--- @param actual any
--- @param context? any
--- @return any
function M.eq_partial(expected, actual, context)
  local seen = {} --- @type table<table, table<table, boolean>>
  local prefix = context ~= nil and tostring(context) .. ': ' or ''

  --- @param want any
  --- @param got any
  --- @param path string
  local function compare(want, got, path)
    if type(want) ~= 'table' or type(got) ~= 'table' or next(want) == nil then
      M.eq(want, got, prefix .. path)
      return
    end

    if vim.islist(want) then
      assert_value(vim.islist(got), got, prefix .. path, 'Expected a list.\nActual:\n' .. fmt(got))
      M.eq(#want, #got, prefix .. path .. ' (length)')
    end

    if seen[want] and seen[want][got] then
      return
    end
    seen[want] = seen[want] or {}
    seen[want][got] = true

    for key, value in pairs(want) do
      local field = type(key) == 'string' and key:match('^[%a_][%w_]*$') and '.' .. key
        or '[' .. fmt(key) .. ']'
      compare(value, got[key], path .. field)
    end
  end

  compare(expected, actual, 'actual')
  return actual
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
    ('Expected values to differ.\nValue:\n%s'):format(fmt(actual))
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
