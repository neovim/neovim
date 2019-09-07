local log = require('lsp.log')

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
    call_callbacks_for_method('nvim/error_callback', data, filetype)
  end

  if not filetype and vim.tbl_isempty(self.common) then
      log.debug('Request: "', self.method, '" had no registered callbacks')
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
  return vim.tbl_isempty(self:get_list_of_callbacks(filetype))
end

CallbackObject.add_callback = function(self, new_callback, filetype)
  if filetype then
    self:add_filetype_callback(new_callback, filetype)
  else
    self:add_common_callback(new_callback)
  end
end

CallbackObject.add_filetype_callback = function(self, new_callback, filetype)
  if not self.filetype[filetype] then
    self.filetype[filetype] = {}
  end

  table.insert(self.filetype[filetype], new_callback)
end

CallbackObject.add_common_callback = function(self, new_callback)
  table.insert(self.common, new_callback)
end

CallbackObject.set_callback = function(self, new_callback, filetype)
  if filetype then
    self:set_filetype_callback(new_callback, filetype)
  else
    self:set_common_callback(new_callback)
  end
end

CallbackObject.set_filetype_callback = function(self, new_callback, filetype)
  self.filetype[filetype] = {}
  table.insert(self.filetype[filetype], new_callback)
end

CallbackObject.set_common_callback = function(self, new_callback)
  self.common = {}
  table.insert(self.common, new_callback)
end

--- Get list of callbacks.
--- If filetype argument is present and there are specific filetype callbacks, it returns only specific filetype callbacks.
--- But if filetype argument is present and there aren't any specific filetype callbacks, it returns common callbacks.
-- @params (optional) filetype string
CallbackObject.get_list_of_callbacks = function(self, filetype)
  local callback_list = {}

  if filetype then
    if self.filetype[filetype] == nil then
      self.filetype[filetype] = {}
    end

    for _, value in ipairs(self.filetype[filetype]) do
      table.insert(callback_list, value)
    end
  end

  if not filetype or (filetype and callback_list and vim.tbl_isempty(callback_list)) then
    for _, value in ipairs(self.common) do
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

local add_callback = function(method, new_callback, filetype)
  get_callback_object_by_method(method):add_callback(new_callback, filetype)
end

local set_callback = function(method, new_callback, filetype)
  get_callback_object_by_method(method):set_callback(new_callback, filetype)
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

return {
  -- Calling configured callback objects
  call_callbacks_for_method = call_callbacks_for_method,

  -- Configuring callback objects
  add_callback = add_callback,
  set_callback = set_callback,
  set_option = set_option,

  -- Generally private functions
  _callback_mapping = CallbackMapping,
  _callback_object = CallbackObject,
  _get_list_of_callbacks = get_list_of_callbacks,
  _call_callbacks = call_callbacks,
}
