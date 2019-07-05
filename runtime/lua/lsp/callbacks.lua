-- luacheck: globals vim

local log = require('lsp.log')
local util = require('nvim.util')
local BuiltinCallbacks = require('lsp.builtin_callbacks').BuiltinCallbacks

-- {
--   method_name = CallbackObject
-- }
local CallbackMapping = setmetatable({}, {})

-- {
--   common = { CallbackObject },
--   filetype = { CallbackObject }.
-- }
local CallbackObject = {}

CallbackObject.__index = function(self, key)
  if CallbackObject[key] ~= nil then
    return CallbackObject[key]
  end

  return rawget(self, key)
end

-- Operation function for CallbackMapping and CallbackObject section
local get_callback_object_by_method = function(method)
  if type(method) ~= 'string' then
    return nil
  end

  if CallbackMapping[method] == nil then
    CallbackMapping[method] = CallbackObject.new(method)
  end

  return CallbackMapping[method]
end

-- @params method
-- @params success
-- @params data
-- @params filetype

-- @return callback result
local call_callbacks_for_method = function(method, success, data, filetype)
  local cb = get_callback_object_by_method(method)

  if cb:has_no_callbacks(filetype) then
    log.debug('Unsupported method:', method)
    return
  end

  return cb(success, data, filetype)
end

-- CallbackObject section
CallbackObject.__call = function(self, success, data, filetype)
  if self.name ~= 'nvim/error_callback' and not success then
    call_callbacks_for_method('nvim/error_callback', data)
  end

  if not filetype and util.table.is_empty(self.common) then
      log.trace('Request: "', self.method, '" had no registered callbacks')
    return nil
  end

  local callback_list = self:get_list_of_callbacks(filetype)
  local results = { }

  for _, cb in ipairs(callback_list) do
    local current_result = cb(self, data)

    if current_result ~= nil then
      table.insert(results, current_result)
    end
  end

  return unpack(results)
end

CallbackObject.new = function(method, options)
  options = options or {}

  local object = setmetatable({
    method = method,
    options = setmetatable(options, {
      __index = function(_, key)
        error(string.format('Cannot get option (%s) for "%s"', key, method))
      end,

      __newindex = function(_, key, value)
        error(string.format('Cannot set option (%s) for "%s" to value [%s]', key, method, value))
      end,
    }),

    common = {},
    filetype = {},
  }, CallbackObject)

  return object
end

CallbackObject.has_no_callbacks = function(self, filetype)
  return #self:get_list_of_callbacks(filetype) == 0
end

CallbackObject.add_callback = function(self, new_callback)
  table.insert(self.common, new_callback)
end

CallbackObject.add_filetype_callback = function(self, new_callback, filetype)
  if self.filetype[filetype] == nil then
    self.filetype[filetype] = {}
  end

  table.insert(self.filetype[filetype], new_callback)
end

CallbackObject.get_list_of_callbacks = function(self, filetype)
  local callback_list = {}

  for _, value in ipairs(self.common) do
    table.insert(callback_list, value)
  end

  if filetype ~= nil then
    if self.filetype[filetype] == nil then
      self.filetype[filetype] = {}
    end

    for _, value in ipairs(self.filetype[filetype]) do
      table.insert(callback_list, value)
    end
  end

  return callback_list
end

local call_callbacks = function(callback_list, success, params)
  local results = {}

  for key, callback in ipairs(callback_list) do
    results[key] = callback(success, params)
  end

  return unpack(results)
end

local add_callback = function(method, new_callback)
  get_callback_object_by_method(method):add_callback(new_callback)
end

local add_filetype_callback = function(method, new_callback, filetype)
  get_callback_object_by_method(method):add_filetype_callback(new_callback, filetype)
end

local set_option = function(method, option, value)
  get_callback_object_by_method(method).options[option] = value
end

--- Get a list of callbacks for a particular circumstance
-- @param method                (required) The name of the method to get the callbacks for
-- @param filetype              (optional) If passed, will execute filetype specific callbacks as well
local get_list_of_callbacks = function(method, filetype)
  local cb = get_callback_object_by_method(method)

  if cb == nil then return {} end

  return cb:get_list_of_callbacks(filetype)
end

--- Set a builtin callback to CallbackMapping
-- @param method               (required) The name of the lsp method to set a callback to
local set_builtin_callback = function(method)
  local builtin_callback = BuiltinCallbacks[method]
  local callback_object = CallbackObject.new(method, builtin_callback['options'])
  callback_object:add_callback(builtin_callback['callback'])
  CallbackMapping[method] = callback_object
end

--- Set the all builtin callbacks to CallbackMapping
local set_all_builtin_callbacks = function()
  for method_name in pairs(BuiltinCallbacks) do
    set_builtin_callback(method_name)
  end
end

return {
  -- Calling configured callback objects
  call_callbacks_for_method = call_callbacks_for_method,

  -- Configuring callback objects
  add_callback = add_callback,
  add_filetype_callback = add_filetype_callback,
  set_option = set_option,

  -- Adding builtin callback functions
  set_all_builtin_callbacks = set_all_builtin_callbacks,
  set_builtin_callback = set_builtin_callback,

  -- Generally private functions
  _callback_mapping = CallbackMapping,
  _callback_object = CallbackObject,
  _get_list_of_callbacks = get_list_of_callbacks,
  _call_callbacks = call_callbacks,
}
