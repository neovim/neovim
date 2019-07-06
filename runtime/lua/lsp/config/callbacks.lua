local callbacks = require('lsp.callbacks')

local configure = {}

--- Configure the error callback used to print or display errors
-- @param new_error_cb  (required)  The function reference to call instead of the default error_callback
configure.error_callback = function(new_error_cb)
  callbacks.set_default_callback('nvim/error_callback', new_error_cb)
end

--- Add a callback that will be called whenever method is handled
-- @param method                    (required)  The name of the method to associate with the callback
-- @param cb                        (required)  The callback to execute (or nil to disable -- probably)
-- @param override_default_callback (optional)  Use this as the default callback for method, overrides filetype
-- @param filetype                  (optional)  Use this to only have a callback executed for certain filetypes
configure.add_callback = function(method, cb, filetype)
  callbacks.add_callback(method, cb, filetype)
end

--- Set a callback that will be called whenever method is handled.
--- If the callbacks have already been defined, those are overrided by this callback.
-- @param method                    (required)  The name of the method to associate with the callback
-- @param cb                        (required)  The callback to execute (or nil to disable -- probably)
-- @param override_default_callback (optional)  Use this as the default callback for method, overrides filetype
-- @param filetype                  (optional)  Use this to only have a callback executed for certain filetypes
configure.set_callback = function(method, cb, filetype)
  callbacks.set_callback(method, cb, filetype)
end

configure.set_option = function(method, option, value)
  callbacks.set_option(method, option, value)
end

return configure
