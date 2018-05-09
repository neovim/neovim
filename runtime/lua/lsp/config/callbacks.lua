local callbacks = require('lsp.callbacks')

local configure = {}

configure.error_callback = function(cb)
  callbacks.set_default_callback

  -- TODO: Pick up here

end

--- Add a callback that will be called whenever method is handled
-- @param method                    (required)  The name of the method to associate with the callback
-- @param cb                        (required)  The callback to execute (or nil to disable -- probably)
-- @param override_default_callback (optional)  Use this as the default callback for method, overrides filetype
-- @param filetype_specific         (optional)  Use t his to only have a callback executed for certain filetypes
--
-- @returns another
configure.add_callback = function(method, cb, override_default_callback, filetype_specific)
  if override_default_callback then
    callbacks.set_default_callback(method, cb)
  else
    callbacks.add_callback(method, cb, filetype_specific)
  end
end

configure.disable_default_callback = function(method)
  configure.add_callback(method, nil, true)
end

return configure
