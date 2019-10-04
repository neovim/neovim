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

local text_document_handler = require('vim.lsp.handler.text_document')
local workspace_handler = require('vim.lsp.handler.workspace')

-- {
--    method_name = {
--      callback = function,
--      options = table
--    }
-- }
local BuiltinCallbacks = {}

-- nvim/error_callback
BuiltinCallbacks['nvim/error_callback'] = {
  callback = function(self, data, method_name)
    logger.debug('callback:nvim/error_callback ', method_name, ' ', data, ' ', self)

    local message = ''
    if data.message ~= nil and type(data.message) == 'string' then
      message = data.message
    elseif rawget(errorCodes, data.code) ~= nil then
      message = string.format('[%s] %s',
        data.code, errorCodes[data.code]
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
  callback = function(self, data)
    logger.debug('callback:textDocument/publishDiagnostics ', data, ' ', self)
    logger.debug('Not implemented textDocument/publishDiagnostics callback')
  end,
  options = {},
}

-- textDocument/completion
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
BuiltinCallbacks['textDocument/completion'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/completion ', data, ' ', self)

    if not data or vim.tbl_isempty(data) then
      return
    end

    local matches = text_document_handler.completion_list_to_matches(data)
    local corsol = vim.api.nvim_call_function('col', { '.' })
    local line_to_cursor = vim.api.nvim_call_function(
      'strpart', {
        vim.api.nvim_call_function(
          'getline', { '.' }
        ),
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
  callback = function(self, data)
    logger.debug('textDocument/signatureHelp ', data, ' ', self)

    if data == nil or vim.tbl_isempty(data) then
      return
    end

    if not vim.tbl_isempty(data.signatures) then
      local contents = {}
      local activeSignature = 1

      if data.activeSignature then
        activeSignature = data.activeSignature + 1
      end
      local signature = data.signatures[activeSignature]

      for _, line in pairs(vim.split(signature.label, '\n')) do
        table.insert(contents, line)
      end

      if not (signature.documentation == nil) then
        if type(signature.documentation) == 'table' then
          for _, line in pairs(vim.split(signature.documentation.value, '\n')) do
            table.insert(contents, line)
          end
        else
          for _, line in pairs(vim.split(signature.documentation, '\n')) do
            table.insert(contents, line)
          end
        end
        table.insert(contents, signature.documentation)
      end

      util.ui:open_floating_preview(contents)
    end
  end,
  options = {},
}

-- textDocument/references
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_references
BuiltinCallbacks['textDocument/references'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/references ', data, ' ', self)
    logger.debug('Not implemented textDocument/publishDiagnostics callback')
  end,
  options = {},
}

-- textDocument/rename
BuiltinCallbacks['textDocument/rename'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/rename ', data, ' ', self)

    if not data then
      return nil
    end

    vim.api.nvim_set_var('text_document_rename', data)

    workspace_handler.apply_WorkspaceEdit(data)
  end,
  options = {}
}

-- textDocument/hover
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_hover
-- @params MarkedString | MarkedString[] | MarkupContent
BuiltinCallbacks['textDocument/hover'] = {
  callback = function(self, data)
    logger.debug('textDocument/hover ', data, ' ', self)

    if not data or vim.tbl_isempty(data) then
      return
    end

    if data.contents ~= nil then
      local contents = {}
      local contents_type = util.get_hover_contents_type(data.contents)

      if contents_type == 'MarkedString[]' and not vim.tbl_isempty(data.contents) then
        for _, item in ipairs(data.contents) do
          if type(item) == 'table' then
            table.insert(contents, '```'..item.language)
            for _, line in pairs(vim.split(item.value, '\n')) do
              table.insert(contents, line)
            end
            table.insert(contents, '```')
          elseif item == nil then
            table.insert(contents, '')
          else
            for _, line in pairs(vim.split(item, '\n')) do
              table.insert(contents, line)
            end
          end
        end
      elseif contents_type == 'MarkupContent' and not vim.tbl_isempty(data.contents) then
        -- MarkupContent
        if data.contents.kind ~= nil then
          for _, line in pairs(vim.split(data.contents.value, '\n')) do
            table.insert(contents, line)
          end
        -- { language: string; value: string }
        elseif data.contents.language ~= nil then
          table.insert(contents, '```'..data.contents.language)
          for _, line in pairs(vim.split(data.contents.value, '\n')) do
            table.insert(contents, line)
          end
          table.insert(contents, '```')
        else
          for _, line in pairs(vim.split(data.contents, '\n')) do
            table.insert(contents, line)
          end
        end
      elseif contents_type == 'string' and data.contents ~= '' then
        for _, line in pairs(vim.split(data.contents, '\n')) do
          table.insert(contents, line)
        end
      end

      if contents[1] == '' or contents[1] == nil then
        table.insert(contents, 'LSP [textDocument/hover]: No information available')
      end

      util.ui:open_floating_preview(contents, 'markdown')
    end
  end,
  options = {}
}

-- textDocument/declaration
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_declaration
BuiltinCallbacks['textDocument/declaration'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/definiton ', data, ' ', self)

    if not data or data == {} then
      logger.info('No declaration found')
      return nil
    end

    util.handle_location(data)

    return true
  end,
  options = {}
}

-- textDocument/definition
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_definition
BuiltinCallbacks['textDocument/definition'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/definiton ', data, ' ', self)

    if not data or data == {} then
      logger.info('No definition found')
      return nil
    end

    util.handle_location(data)

    return true
  end,
  options = {}
}

-- textDocument/typeDefinition
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_typeDefinition
BuiltinCallbacks['textDocument/typeDefinition'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/typeDefiniton ', data, ' ', self)

    if not data or data == {} then
      logger.info('No type definition found')
      return nil
    end

    util.handle_location(data)

    return true
  end,
  options = {}
}

-- textDocument/implementation
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_implementation
BuiltinCallbacks['textDocument/implementation'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/implementation ', data, ' ', self)

    if not data or data == {} then
      logger.info('No implementation found')
      return nil
    end

    util.handle_location(data)

    return true
  end,
  options = {}
}

-- window/showMessage
-- https://microsoft.github.io/language-server-protocol/specification#window_showMessage
BuiltinCallbacks['window/showMessage'] = {
  callback = function(self, data)
    logger.debug('callback:window/showMessage ', data, ' ', self)

    if not data or type(data) ~= 'table' then
      print(self)
      return nil
    end

    local message_type = data['type']
    local message = data['message']

    if message_type == protocol.MessageType.Error then
      -- Might want to not use err_writeln,
      -- but displaying a message with red highlights or something
      vim.api.nvim_err_writeln(message)
    else
      vim.api.nvim_out_write(message .. "\n")
    end

    return data
  end,
  options = {}
}

return BuiltinCallbacks
