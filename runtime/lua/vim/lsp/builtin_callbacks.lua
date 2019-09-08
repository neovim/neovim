--- Implements the following default callbacks:
--
--  TODO: textDocument/publishDiagnostics
--  textDocument/completion
--  TODO: completionItem/resolve
--  textDocument/hover
--  textDocument/signatureHelp
--  TODO: textDocument/references
--  TODO: textDocument/documentHighlight
--  TODO: textDocument/documentSymbol
--  TODO: textDocument/formatting
--  TODO: textDocument/rangeFormatting
--  TODO: textDocument/onTypeFormatting
--  textDocument/definition
--  TODO: textDocument/codeAction
--  TODO: textDocument/codeLens
--  TODO: textDocument/documentLink
--  TODO: textDocument/rename
--  TODO: codeLens/resolve
--  TODO: documentLink/resolve

local logger = require('vim.lsp.logger')
local util = require('vim.lsp.util')
local protocol = require('vim.lsp.protocol')
local errorCodes = protocol.errorCodes

local handle_completion = require('vim.lsp.handle.completion')
local handle_workspace = require('vim.lsp.handle.workspace')

-- {
--    method_name = {
--      callback = function,
--      options = table
--    }
-- }
local BuiltinCallbacks = {}

-- nvim/error_callback
BuiltinCallbacks['nvim/error_callback'] = {
  callback = function(original, error_message)
    logger.debug('callback:nvim/error_callback', original, error_message)

    local message = ''
    if error_message.message ~= nil and type(error_message.message) == 'string' then
      message = error_message.message
    elseif rawget(errorCodes, error_message.code) ~= nil then
      message = string.format('[%s] %s',
        error_message.code, errorCodes[error_message.code]
      )
    end

    vim.api.nvim_err_writeln(string.format('[LSP:%s] Error: %s', original.method, message))

    return
  end,
  options = {}
}

-- textDocument/publishDiagnostics
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_publishDiagnostics
BuiltinCallbacks['textDocument/publishDiagnostics']= {
  callback = function(self, data)
    logger.debug('callback:textDocument/publishDiagnostics', data, self)
    logger.debug('Not implemented textDocument/publishDiagnostics callback')
  end,
  options = {},
}

-- textDocument/completion
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
BuiltinCallbacks['textDocument/completion'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/completion', data, self)

    if data == nil or vim.tbl_isempty(data) then
      return
    end

    local matches = handle_completion.getMatches(data).matches
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
    logger.debug('textDocument/signatureHelp', data, self)

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
    logger.debug('callback:textDocument/references', data, self)
    logger.debug('Not implemented textDocument/publishDiagnostics callback')
  end,
  options = {},
}

-- textDocument/rename
BuiltinCallbacks['textDocument/rename'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/rename', data, self)

    if data == nil then
      print(self)
      return nil
    end

    vim.api.nvim_set_var('textDocument_rename', data)

    handle_workspace.apply_WorkspaceEdit(data)
  end,
  options = {}
}

-- textDocument/hover
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_hover
-- @params MarkedString | MarkedString[] | MarkupContent
BuiltinCallbacks['textDocument/hover'] = {
  callback = function(self, data)
    logger.debug('textDocument/hover', data, self)

    if data == nil or vim.tbl_isempty(data) then
      return
    end

    if data.contents ~= nil then
      local contents = {}

      if vim.tbl_islist(data.contents) == true then
        -- MarkedString[]
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
      elseif type(data.contents) == 'table' then
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
      -- string
      else
        for _, line in pairs(vim.split(data.contents, '\n')) do
          table.insert(contents, line)
        end
      end

      if contents[1] == '' or contents[1] == nil then
        vim.api.nvim_command("echo 'LSP [textDocument/hover]: No information available'")
      else
        util.ui:open_floating_preview(contents, 'markdown')
      end
    end
  end,
  options = {}
}

-- textDocument/definition
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_definition
BuiltinCallbacks['textDocument/definition'] = {
  callback = function(self, data)
    logger.debug('callback:textDocument/definiton', data, self)

    if data == nil or data == {} then
      logger.info('No definition found')
      return nil
    end

    local current_file = vim.api.nvim_call_function('expand', {'%'})

    -- We can sometimes get a list of locations,
    -- so set the first value as the only value we want to handle
    if data[1] ~= nil then
      data = data[1]
    end

    if data.uri == nil then
      vim.api.nvim_err_writeln('[LSP] Could not find a valid definition')
      return
    end

    if type(data.uri) ~= 'string' then
      vim.api.nvim_err_writeln('Invalid uri')
      return
    end

    local data_file = vim.uri_to_fname(data.uri)

    if data_file ~= vim.fname_to_uri(current_file) then
      vim.api.nvim_command('silent edit ' .. data_file)
    end

    vim.api.nvim_command(
      string.format('normal! %sG%s|'
        , data.range.start.line + 1
        , data.range.start.character + 1
      )
    )

    return true
  end,
  options = {}
}

-- window/showMessage
-- https://microsoft.github.io/language-server-protocol/specification#window_showMessage
BuiltinCallbacks['window/showMessage'] = {
  callback = function(self, data)
    logger.debug('callback:window/showMessage', data, self)

    if data == nil or type(data) ~= 'table' then
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

return {
  BuiltinCallbacks = BuiltinCallbacks
}
