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

local nvim_util = require('neovim.util')
local structures = require('lsp.structures')

local requests = {
  textDocument = {},
}

-- luacheck: no unused args

-- TODO: Determine what to do if it's not really a request, just a notification
requests.textDocument.publishDiagnosticss = function(client, params)
  return {}
end

-- TODO: Determine if we ever really need to pass client
requests.textDocument.references = function(client, params)
  return structures.ReferenceParams(params)
end

requests.textDocument.didOpen = function(client, params)
  return structures.DidOpenTextDocumentParams(params)
end

requests.textDocument.didSave = function(client, params)
  return structures.DidSaveTextDocumentParams(params)
end

requests.textDocument.completion = function(client, params)
  return structures.CompletionParams(params)
end

requests.textDocument.hover = function(client, params)
  return structures.TextDocumentPositionParams(params)
end

requests.textDocument.definition = function(client, params)
  return structures.TextDocumentPositionParams(params)
end

requests.textDocument.signatureHelp = function(client, params)
  return structures.TextDocumentPositionParams(params)
end

requests.textDocument.documentHighlight = function(client, params)
  return structures.TextDocumentPositionParams(params)
end

-- @name: get_request_function
--  Get a function to transform a client and default parameters into valid parameters for a request
-- @param method (string): The method name
-- @returns (function): The function to call to get the request parameters
local get_request_function = function(method)
  local method_table
  if type(method) == 'string' then
    method_table = nvim_util.split(method, '/')
  elseif type(method) == 'table' then
    method_table = method
  else
    return nil
  end

  local request_func = requests
  for _, key in ipairs(method_table) do
    request_func = request_func[key]

    if request_func == nil then
      break
    end
  end

  return request_func
end

return {
  requests = requests,
  get_request_function = get_request_function
}
