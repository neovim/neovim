-- luacheck: globals vim

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

local server_config = require('lsp.server')
local structures = require('lsp.structures')

local requests = {
  textDocument = {},
}

-- luacheck: no unused args

requests.initialize = function(client, params)
  return {
    -- Get neovim's process ID
    processId = vim.api.nvim_call_function('getpid', {}),

    -- TODO(tjdevries): Give the user a way to specify this by filetype
    rootUri = server_config.get_callback(client.ft, 'root_uri')(),

    capabilities = {
      textDocument = {
        synchronization = {
          -- TODO(tjdevries): What is this?
          dynamicRegistration = nil,

          -- Send textDocument/willSave before saving (BufWritePre)
          willSave = true,

          -- TODO(tjdevries): Implement textDocument/willSaveWaitUntil
          willSaveWaitUntil = false,

          -- Send textDocument/didSave after saving (BufWritePost)
          didSave = true,
        },

        -- Capabilities relating to textDocument/completion
        completion = {
          -- TODO(tjdevries): What is this?
          dynamicRegistration = nil,

          -- base/completionItem
          completionItem = {
            -- TODO(tjdevries): Is it possible to implement this in plain lua?
            snippetSupport = false,

            -- TODO(tjdevries): What is this?
            commitCharactersSupport = nil,

            -- TODO(tjdevries): What is this?
            documentationFormat = nil,
          },

          -- TODO(tjdevries): Handle different completion item kinds differently
          -- completionItemKind = {
          --   valueSet = nil
          -- },

          -- TODO(tjdevries): Implement this
          contextSupport = false,
        },

        -- textDocument/hover
        hover = {
          -- TODO(tjdevries): What is this?
          dynamicRegistration = nil,

          -- Currently only support plaintext
          --    In the future, if we have floating windows or display in a preview window,
          --    we could say markdown
          contentFormat = {'plaintext'},
        },

        -- textDocument/signatureHelp
        signatureHelp = {
          dynamicRegistration = nil,

          signatureInformation = {
            documentationFormat = {'plaintext'}
          },
        },

        -- textDocument/references
        -- references = {
        --   dynamicRegistration = nil,
        -- },

        -- textDocument/highlight
        -- documentHighlight = {
        --   dynamicRegistration = nil,
        -- },

        -- textDocument/symbol
        -- TODO(tjdevries): Implement

        -- TODO(tjdevries): Finish these...
      },
    },
  }, true
end

-- TODO: Determine what to do if it's not really a request, just a notification
requests.textDocument.publishDiagnosticss = function(client, params)
  return {}, true
end

-- TODO: Determine if we ever really need to pass client
requests.textDocument.references = function(client, params)
  return structures.ReferenceParams(params), true
end

requests.textDocument.didOpen = function(client, params)
  return structures.DidOpenTextDocumentParams(params), true
end

requests.textDocument.willSave = function(client, params)
  if not client.capabilities.synchronization.willSave then
    return nil, false
  end

  return structures.WillSaveTextDocumentParams(params), true
end

requests.textDocument.didSave = function(client, params)
  if not client.capabilities.synchronization.didSave then
    return nil, false
  end

  return structures.DidSaveTextDocumentParams(params), true
end

requests.textDocument.didChange = function(client, params)
  return structures.DidChangeTextDocumentParams(params), true
end

requests.textDocument.completion = function(client, params)
  if not client.capabilities.completionProvider then
    return nil, false
  end

  return structures.CompletionParams(params), true
end

requests.textDocument.hover = function(client, params)
  if not client.capabilities.hoverProvider then
    return nil, false
  end

  return structures.TextDocumentPositionParams(params), true
end

requests.textDocument.definition = function(client, params)
  if not client.capabilities.definitionProvider then
    return nil, false
  end

  return structures.TextDocumentPositionParams(params), true
end

requests.textDocument.rename = function(client, params)
  return structures.RenameParams(params)
end

requests.textDocument.signatureHelp = function(client, params)
  return structures.TextDocumentPositionParams(params), true
end

requests.textDocument.documentHighlight = function(client, params)
  return structures.TextDocumentPositionParams(params), true
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
