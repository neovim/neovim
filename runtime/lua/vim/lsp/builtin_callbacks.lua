--- Implements the following default callbacks:
--
-- TODO: textDocument/publishDiagnostics
-- textDocument/completion
-- TODO: completionItem/resolve
-- textDocument/hover
-- textDocument/signatureHelp
-- textDocument/declaration
-- textDocument/definition
-- textDocument/typeDefinition
-- textDocument/implementation
-- TODO: textDocument/references
-- TODO: textDocument/documentHighlight
-- TODO: textDocument/documentSymbol
-- TODO: textDocument/formatting
-- TODO: textDocument/rangeFormatting
-- TODO: textDocument/onTypeFormatting
-- textDocument/definition
-- TODO: textDocument/codeAction
-- TODO: textDocument/codeLens
-- TODO: textDocument/documentLink
-- TODO: textDocument/rename
-- TODO: codeLens/resolve
-- TODO: documentLink/resolve

local logger = require('vim.lsp.logger')
local util = require('vim.lsp.util')
local protocol = require('vim.lsp.protocol')
local errorCodes = protocol.errorCodes

local text_document_handler = require('vim.lsp.handler').text_document
local workspace_handler = require('vim.lsp.handler').workspace

-- {
--    method_name = {
--      callback = function,
--      options = table
--    }
-- }
local BuiltinCallbacks = {}

-- nvim/error_callback
BuiltinCallbacks['nvim/error_callback'] = {
  callback = function(self, result, method_name)
    logger.debug('callback:nvim/error_callback ', method_name, ' ', result, ' ', self)

    local message = ''
    if result.message ~= nil and type(result.message) == 'string' then
      message = result.message
    elseif rawget(errorCodes, result.code) ~= nil then
      message = string.format('[%s] %s',
        result.code, errorCodes[result.code]
      )
    end

    vim.api.nvim_err_writeln(string.format('[LSP:%s] Error: %s', method_name, message))

    return
  end,
  options = {}
}

-- textDocument/publishDiagnostics
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_publishDiagnostics
BuiltinCallbacks['textDocument/publishDiagnostics']= {
  callback = function(self, result)
    logger.debug('callback:textDocument/publishDiagnostics ', result, ' ', self)
    logger.debug('Not implemented textDocument/publishDiagnostics callback')
  end,
  options = {},
}

-- textDocument/completion
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
BuiltinCallbacks['textDocument/completion'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/completion ', result, ' ', self)

    if not result or vim.tbl_isempty(result) then
      return
    end

    local matches = text_document_handler.CompletionList_to_matches(result)
    local corsol = vim.api.nvim_call_function('col', { '.' })
    local line_to_cursor = vim.api.nvim_call_function(
      'strpart', {
        vim.api.nvim_call_function('getline', { '.' }),
        0,
        corsol - 1,
      }
    )
    local position = vim.api.nvim_call_function('matchstrpos', { line_to_cursor, '\\k\\+$' })

    vim.api.nvim_call_function('complete', { corsol - (position[2] - position[3]), matches })
  end,
  options = {}
}

-- textDocument/signatureHelp
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_signatureHelp
BuiltinCallbacks['textDocument/signatureHelp'] = {
  callback = function(self, result)
    logger.debug('textDocument/signatureHelp ', result, ' ', self)

    if result == nil or vim.tbl_isempty(result) then
      return
    end

    if not vim.tbl_isempty(result.signatures) then
      util.ui:open_floating_preview(text_document_handler.SignatureHelp_to_preview_contents(result))
    end
  end,
  options = {},
}

-- textDocument/references
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_references
BuiltinCallbacks['textDocument/references'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/references ', result, ' ', self)
    logger.debug('Not implemented textDocument/publishDiagnostics callback')
  end,
  options = {},
}

-- textDocument/rename
BuiltinCallbacks['textDocument/rename'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/rename ', result, ' ', self)

    if not result then
      return nil
    end

    vim.api.nvim_set_var('text_document_rename', result)

    workspace_handler.apply_WorkspaceEdit(result)
  end,
  options = {}
}

-- textDocument/hover
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_hover
-- @params MarkedString | MarkedString[] | MarkupContent
BuiltinCallbacks['textDocument/hover'] = {
  callback = function(self, result)
    logger.debug('textDocument/hover ', result, ' ', self)

    if not result or vim.tbl_isempty(result) then
      return
    end

    if result.contents ~= nil then
      util.ui:open_floating_preview(text_document_handler.HoverContents_to_preview_contents(result), 'markdown')
    end
  end,
  options = {}
}

-- textDocument/declaration
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_declaration
BuiltinCallbacks['textDocument/declaration'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/definiton ', result, ' ', self)

    if not result or result == {} then
      logger.info('No declaration found')
      return nil
    end

    util.handle_location(result)

    return true
  end,
  options = {}
}

-- textDocument/definition
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_definition
BuiltinCallbacks['textDocument/definition'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/definiton ', result, ' ', self)

    if not result or result == {} then
      logger.info('No definition found')
      return nil
    end

    util.handle_location(result)

    return true
  end,
  options = {}
}

-- textDocument/typeDefinition
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_typeDefinition
BuiltinCallbacks['textDocument/typeDefinition'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/typeDefiniton ', result, ' ', self)

    if not result or result == {} then
      logger.info('No type definition found')
      return nil
    end

    util.handle_location(result)

    return true
  end,
  options = {}
}

-- textDocument/implementation
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_implementation
BuiltinCallbacks['textDocument/implementation'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/implementation ', result, ' ', self)

    if not result or result == {} then
      logger.info('No implementation found')
      return nil
    end

    util.handle_location(result)

    return true
  end,
  options = {}
}

-- window/showMessage
-- https://microsoft.github.io/language-server-protocol/specification#window_showMessage
BuiltinCallbacks['window/showMessage'] = {
  callback = function(self, result)
    logger.debug('callback:window/showMessage ', result, ' ', self)

    if not result or type(result) ~= 'table' then
      print(self)
      return nil
    end

    local message_type = result['type']
    local message = result['message']

    if message_type == protocol.MessageType.Error then
      -- Might want to not use err_writeln,
      -- but displaying a message with red highlights or something
      vim.api.nvim_err_writeln(message)
    else
      vim.api.nvim_out_write(message .. "\n")
    end

    return result
  end,
  options = {}
}

return BuiltinCallbacks
