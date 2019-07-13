-- Register requests
-- Default requests
-- Override requests
-- Delete requests
--
-- Supported Requests for Neovim.
--
-- All requests are in the format of:
--  requests.method_name.method_name_1.<...>(client, params)
--      Where:
--          method_name, method_name_1, etc. are the names of the method split on "/"
--          For example, 'textDocument/references' -> requests.textDocument.references
--
--          @param client: The client object that the request will be sent to
--          @param params: The parameters to override for the request
--
--          @returns (table): The resulting params for the request

local shared = require('vim.shared')
local structures = require('lsp.structures')

local notifications = {
  textDocument = {},
}

-- luacheck: no unused args

notifications.initialized = function(client, params)
  return {}, true
end

notifications.textDocument.publishDiagnosticss = function(client, params)
  return {}, true
end

notifications.textDocument.didOpen = function(client, params)
  return structures.DidOpenTextDocumentParams(params), true
end

notifications.textDocument.willSave = function(client, params)
  if not client.capabilities.synchronization.willSave then
    return nil, false
  end

  return structures.WillSaveTextDocumentParams(params), true
end

notifications.textDocument.didSave = function(client, params)
  if not client.capabilities.synchronization.didSave then
    return nil, false
  end

  return structures.DidSaveTextDocumentParams(params), true
end

notifications.textDocument.didChange = function(client, params)
  return structures.DidChangeTextDocumentParams(params), true
end

-- @name: get_request_function
--  Get a function to transform a client and default parameters into valid parameters for a request
-- @param method (string): The method name
-- @returns (function): The function to call to get the request parameters
local get_notification_function = function(method)
  local method_table
  if type(method) == 'string' then
    method_table = shared.split(method, '/', true)
  elseif type(method) == 'table' then
    method_table = method
  else
    return nil
  end

  local notification_func = notifications
  for _, key in ipairs(method_table) do
    notification_func = notification_func[key]

    if notification_func == nil then
      break
    end
  end

  return notification_func
end

return {
  notifications = notifications,
  get_notification_function = get_notification_function
}
