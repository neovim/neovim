-- luacheck: globals vim

local log = require('lsp.log')
local util = require('nvim.util')
local lsp_util = require('lsp.util')
local builtin_callbacks = require('lsp.builtin_callbacks')

-- {
--   'method_name' : CallbackObject
-- }
local CallbackMapping = setmetatable({}, {})

-- {
--   'default': CallbackObject,
--   'generic': CallbackObject,
--   'filetype': CallbackObject.
-- }
local CallbackObject = {}

CallbackObject.__index = function(self, key)
  if CallbackObject[key] ~= nil then
    return CallbackObject[key]
  end

  return rawget(self, key)
end

-- CallbackObject section
CallbackObject.__call = function(self, success, data, default_only, filetype)
  if self.name ~= 'nvim/error_callback' and not success then
    call_callbacks_for_method('nvim/error_callback', false, data)
  end

  if util.table.is_empty(self.default) then
      log.trace('Request: "', self.method, '" had no registered callbacks')
    return nil
  end

  local callback_list = self:get_list_of_callbacks(default_only, filetype)
  local results = { }

  for _, cb in ipairs(callback_list) do
    local current_result = cb(self, data)

    if current_result ~= nil then
      table.insert(results, current_result)
    end
  end

  return unpack(results)
end

CallbackObject.new = function(method, default_callback, options)
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

    default = {},
    generic = {},
    filetype = {},
  }, CallbackObject)

  if default_callback ~= nil then
    if type(default_callback) == 'string' then
      default_callback = function(self, data)
        return vim.api.nvim_call_function(default_callback, {
          { method = self.method, options = unpack(options) },
          data
        })
      end
    end

    object:set_default_callback(default_callback)
  end

  return object
end

CallbackObject.set_default_callback = function(self, default_callback)
  self.default = { default_callback }
end

CallbackObject.add_callback = function(self, new_callback)
  table.insert(self.generic, new_callback)
end

CallbackObject.add_default_callback = function(self, new_callback)
  table.insert(self.default, new_callback)
end

CallbackObject.add_filetype_callback = function(self, new_callback, filetype)
  if self.filetype[filetype] == nil then
    self.filetype[filetype] = {}
  end

  table.insert(self.filetype[filetype], new_callback)
end

CallbackObject.get_list_of_callbacks = function(self, default_only, filetype)
  local callback_list = {}

  for _, value in ipairs(self.default) do
    table.insert(callback_list, value)
  end

  if default_only then
    return callback_list
  end

  for _, value in ipairs(self.generic) do
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

-- Operation function for CallbackMapping and CallbackObject section
local get_callback_object_by_method = function(method, create_new)
  if type(method) ~= 'string' then
    return nil
  end

  if CallbackMapping[method] == nil and create_new then
    CallbackMapping[method] = CallbackObject.new(method)
  end

  return CallbackMapping[method]
end

local call_callbacks = function(callback_list, success, params)
  local results = {}

  for key, callback in ipairs(callback_list) do
    results[key] = callback(success, params)
  end

  return unpack(results)
end

-- @params method
-- @params success
-- @params data
-- @params default_only
-- @params filetype

-- @return callback result
local call_callbacks_for_method = function(method, success, data, default_only, filetype)
  local cb = get_callback_object_by_method(method, false)

  if cb == nil then
    log.debug('Unsupported method:', method)
    return
  end

  return cb(success, data, default_only, filetype)
end

local set_default_callback = function(method, new_default_callback)
  get_callback_object_by_method(method, true):set_default_callback(new_default_callback)
end

local add_callback = function(method, new_callback)
  get_callback_object_by_method(method, true):add_callback(new_callback)
end

local add_filetype_callback = function(method, new_callback, filetype)
  get_callback_object_by_method(method, true):add_filetype_callback(new_callback, filetype)
end

local set_option = function(method, option, value)
  get_callback_object_by_method(method).options[option] = value
end

--- Get a list of callbacks for a particular circumstance
-- @param method                (required) The name of the method to get the callbacks for
-- @param default_only          (optional) If passed, will only execute the default. Overridden by callback_parameter
-- @param filetype              (optional) If passed, will execute filetype specific callbacks as well
local get_list_of_callbacks = function(method, default_only, filetype)
  local cb = get_callback_object_by_method(method)

  if cb == nil then return {} end

  return cb:get_list_of_callbacks(default_only, filetype)
end

local add_all_default_callbacks = function()
  builtin_callbacks.add_all_default_callbacks(CallbackMapping, CallbackObject)
end

local add_nvim_error_callback = function()
  builtin_callbacks.add_nvim_error_callback(CallbackMapping, CallbackObject)
end

local add_text_document_publish_diagnostics_callback = function()
  builtin_callbacks.add_text_document_publish_diagnostics_callback(CallbackMapping, CallbackObject)
end

local add_text_document_completion_callback = function()
  builtin_callbacks.add_text_document_completion_callback(CallbackMapping, CallbackObject)
end

local add_text_document_references_callback = function()
  builtin_callbacks.add_text_document_references_callback(CallbackMapping, CallbackObject)
end

local add_text_document_rename_callback = function()
  builtin_callbacks.add_text_document_rename_callback(CallbackMapping, CallbackObject)
end

local add_text_document_hover_callback = function()
  builtin_callbacks.add_text_document_hover_callback(CallbackMapping, CallbackObject)
end

local add_text_document_definition_callback = function()
  builtin_callbacks.add_text_document_definition_callback(CallbackMapping, CallbackObject)
end

local add_window_show_message_callback = function()
  builtin_callbacks.add_window_show_message_callback(CallbackMapping, CallbackObject)
end

local add_window_show_message_request_callback = function()
  builtin_callbacks.add_window_show_message_request_callback(CallbackMapping, CallbackObject)
end

return {
  -- Calling configured callback objects
  call_callbacks_for_method = call_callbacks_for_method,

  -- Configuring callback objects
  set_default_callback = set_default_callback,
  add_callback = add_callback,
  add_filetype_callback = add_filetype_callback,
  set_option = set_option,

  -- Adding default callback functions
  add_all_default_callbacks = add_all_default_callbacks,
  add_nvim_error_callback = add_nvim_error_callback,
  add_text_document_publish_diagnostics_callback = add_text_document_publish_diagnostics_callback,
  add_text_document_completion_callback = add_text_document_completion_callback,
  add_text_document_references_callback = add_text_document_references_callback,
  add_text_document_rename_callback = add_text_document_rename_callback,
  add_text_document_hover_callback = add_text_document_hover_callback,
  add_text_document_definition_callback = add_text_document_definition_callback,
  add_window_show_message_callback = add_window_show_message_callback,
  add_window_show_message_request_callback = add_window_show_message_request_callback,

  -- Generally private functions
  _callback_mapping = CallbackMapping,
  _callback_object = CallbackObject,
  _get_list_of_callbacks = get_list_of_callbacks,
  _call_callbacks = call_callbacks,
}
