local callbacks = require('lsp.callbacks')

local configure = {}

--- Configure the error callback used to print or display errors
-- @param new_error_cb  (required)  The function reference to call instead of the default error_callback
configure.error_callback = function(new_error_cb)
  callbacks.set_default_callback('neovim/error_callback', new_error_cb)
end

--- Add a callback that will be called whenever method is handled
-- @param method                    (required)  The name of the method to associate with the callback
-- @param cb                        (required)  The callback to execute (or nil to disable -- probably)
-- @param override_default_callback (optional)  Use this as the default callback for method, overrides filetype
-- @param filetype_specific         (optional)  Use this to only have a callback executed for certain filetypes
--
-- @returns another
configure.add_callback = function(method, cb, override_default_callback, filetype_specific)
  if override_default_callback then
    callbacks.set_default_callback(method, cb)
  elseif filetype_specific ~= nil then
    callbacks.add_filetype_callback(method, cb, filetype_specific)
  else
    callbacks.add_callback(method, cb)
  end
end

configure.set_option = function(method, option, value)
  callbacks.set_option(method, option, value)
end

configure.disable_default_callback = function(method)
  configure.add_callback(method, nil, true)
end

return configure
