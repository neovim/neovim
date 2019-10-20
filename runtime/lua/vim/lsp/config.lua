local callbacks = require('vim.lsp.callbacks')
local BuiltinCallbacks = require('vim.lsp.builtin_callbacks')

local config = {}

--- Configure the error callback used to print or display errors
-- @param new_error_cb  (required)  The function reference to call instead of the default error_callback
config.error_callback = function(new_error_cb)
  callbacks.set_default_callback('nvim/error_callback', new_error_cb)
end

--- Add a callback that will be called whenever method is handled
-- @param method                    (required)  The name of the method to associate with the callback
-- @param cb                        (required)  The callback to execute (or nil to disable -- probably)
-- @param override_default_callback (optional)  Use this as the default callback for method, overrides filetype
-- @param filetype                  (optional)  Use this to only have a callback executed for certain filetypes
config.add_callback = function(method, cb, filetype)
  callbacks.add_callback(method, cb, filetype)
end

--- Set a callback that will be called whenever method is handled.
--- If the callbacks have already been defined, those are overrided by this callback.
-- @param method                    (required)  The name of the method to associate with the callback
-- @param cb                        (required)  The callback to execute (or nil to disable -- probably)
-- @param override_default_callback (optional)  Use this as the default callback for method, overrides filetype
-- @param filetype                  (optional)  Use this to only have a callback executed for certain filetypes
config.set_callback = function(method, cb, filetype)
  callbacks.set_callback(method, cb, filetype)
end

config.set_option = function(method, option, value)
  callbacks.set_option(method, option, value)
end

--- Set a builtin callback to CallbackMapping
-- @param method                   (required) The name of the lsp method to set a callback to
config.set_builtin_callback = function(method)
  local builtin_callback = BuiltinCallbacks[method]
  if builtin_callback == nil then
    error(string.format('the method "%s" is not implemented' , method), 2)
  end
  local callback_object = callbacks._callback_object.new(method, builtin_callback['options'])
  callback_object:set_callback(builtin_callback['callback'])
  callbacks._callback_mapping[method] = callback_object
end

--- Set a builtin callback to CallbackMapping
-- @param methods                   (required) The table of name of the lsp method to set a callback to
config.set_builtin_callbacks = function(methods)
  for _, method in ipairs(methods) do
    config.set_builtin_callback(method)
  end
end

--- Set a builtin error callback to CallbackMapping
config.set_builtin_error_callback = function()
  config.set_builtin_callback('nvim/error_callback')
end

--- Set the all builtin callbacks to CallbackMapping
config.set_all_builtin_callbacks = function()
  for method_name in pairs(BuiltinCallbacks) do
    config.set_builtin_callback(method_name)
  end
end

return config
