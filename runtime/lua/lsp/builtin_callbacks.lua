-- luacheck: globals vim
-- Implements the following default callbacks:
--  textDocument/publishDiagnostics

--  IN PROGRESS: textDocument/completion
--  TODO: completionItem/resolve

--  textDocument/hover
--  TODO: textDocument/signatureHelp
--  textDocument/references
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

local log = require('lsp.log')
local protocol = require('lsp.protocol')
local errorCodes = protocol.errorCodes

local QuickFix = require('nvim.quickfix_list')
local LocationList = require('nvim.location_list')
local handle_completion = require('lsp.handle.completion')
local handle_workspace = require('lsp.handle.workspace')


-- Callback definition section
local add_callback = function(callback_mapping, callback_object, name, callback, options)
  callback_object_instance = callback_object.new(name, options)
  callback_object_instance:add_callback(callback)
  callback_mapping[name] = callback_object_instance
end

-- 3 nvim/error_callback
local add_nvim_error_callback = function(callback_mapping, callback_object)
  add_callback(callback_mapping, callback_object, 'nvim/error_callback', function(original, error_message)
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
  end)
end

-- 3 textDocument/publishDiagnostics
local add_text_document_publish_diagnostics_callback = function(callback_mapping, callback_object)
  add_callback(callback_mapping, callback_object, 'textDocument/publishDiagnostics', function(self, data)
    local diagnostic_list
    if self.options.use_quickfix then
      diagnostic_list = QuickFix:new('Language Server Diagnostics')
    else
      diagnostic_list = LocationList:new('Language Server Diagnostics')
    end

    for _, diagnostic in ipairs(data.diagnostics) do
      local range = diagnostic.range
      local severity = diagnostic.severity or protocol.DiagnosticSeverity.Information

      local message_type
      if severity == protocol.DiagnosticSeverity.Error then
        message_type = 'E'
      elseif severity == protocol.DiagnosticSeverity.Warning then
        message_type = 'W'
      else
        message_type = 'I'
      end

      -- local code = diagnostic.code
      local source = diagnostic.source or 'lsp'
      local message = diagnostic.message

      diagnostic_list:add(
        range.start.line + 1,
        range.start.character + 1,
        '[' .. source .. ']' .. message,
        lsp_util.get_filename(data.uri),
        message_type
      )
    end

    diagnostic_list:set()

    if diagnostic_list:len() == 0 then
      diagnostic_list:close()
    elseif self.options.auto_list then
      diagnostic_list:open()
    end

    return
  end, {
    auto_list = false,
    use_quickfix = false,
  })
end

-- 3 textDocument/completion
local add_text_document_completion_callback = function(callback_mapping, callback_object)
  add_callback(callback_mapping, callback_object, 'textDocument/completion', function(self, data)
    if data == nil then
      print(self)
      return
    end

    return handle_completion.getLabels(data)
  end)
end

-- 3 textDocument/references
local add_text_document_references_callback = function(callback_mapping, callback_object)
  add_callback(callback_mapping, callback_object, 'textDocument/references', function(self, data)
    local locations = data
    local loclist = {}

    for _, loc in ipairs(locations) do
      -- TODO: URL parsing here?
      local start = loc.range.start
      local line = start.line + 1
      local character = start.character + 1

      local path = util.handle_uri(loc["uri"])
      local text = lsp_util.get_line_from_path(path, line)

      table.insert(loclist, {
          filename = path,
          lnum = line,
          col = character,
          text = text,
      })
    end

    local result = vim.api.nvim_call_function('setloclist', {0, loclist, ' ', 'Language Server textDocument/references'})

    if self.options.auto_location_list then
      if loclist ~= {} then
        if not util.is_loclist_open() then
          vim.api.nvim_command('lopen')
          vim.api.nvim_command('wincmd p')
        end
      else
        vim.api.nvim_command('lclose')
      end
    end

    return result
  end, { auto_location_list = true })
end

-- 3 textDocument/rename
local add_text_document_rename_callback = function(callback_mapping, callback_object)
  add_callback(callback_mapping, callback_object, 'textDocument/rename', function(self, data)
    if data == nil then
      print(self)
      return nil
    end

    vim.api.nvim_set_var('textDocument_rename', data)

    handle_workspace.apply_WorkspaceEdit(data)
  end, { })
end

-- 3 textDocument/hover
local add_text_document_hover_callback = function(callback_mapping, callback_object)
  add_callback(callback_mapping, callback_object, 'textDocument/hover', function(self, data)
    log.trace('textDocument/hover', data, self)

    if data.range ~= nil then
      -- Doesn't handle multi-line highlights
      local _ = vim.api.nvim_buf_add_highlight(0,
        -1,
        'Error',
        data.range.start.line,
        data.range.start.character,
        data.range['end'].character
      )
    end

    -- TODO: Use floating windows when they become available
    local long_string = ''
    if data.contents ~= nil then
      if util.is_array(data.contents) == true then
        for i, item in ipairs(data.contents) do
          local value
          if type(item) == 'table' then
            value = item.value
          elseif item == nil then
            value = ''
          else
            value = item
          end

          if i == 1 then
            long_string = value
          else
            long_string = long_string .. "\n" .. value
          end
        end

        log.debug('Hover: ', long_string)
      elseif type(data.contents) == 'table' then
        long_string = long_string .. (data.contents.value or '')
      else
        long_string = data.contents
      end

      if long_string == '' then
        long_string = 'LSP: No information available'
      end

      vim.api.nvim_out_write(long_string .. '\n')
      return long_string
    end
  end)
end

-- 3 textDocument/definition
local add_text_document_definition_callback = function(callback_mapping, callback_object)
  add_callback(callback_mapping, callback_object, 'textDocument/definition', function(self, data)
    log.trace('callback:textDocument/definiton', data, self)

    if data == nil or data == {} then
      log.info('No definition found')
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

    local data_file = lsp_util.get_filename(data.uri)

    if data_file ~= lsp_util.get_uri(current_file) then
      vim.api.nvim_command('silent edit ' .. data_file)
    end

    vim.api.nvim_command(
      string.format('normal! %sG%s|'
        , data.range.start.line + 1
        , data.range.start.character + 1
      )
    )

    return true
  end)
end

-- 2 window
-- 3 window/showMessage
local add_window_show_message_callback = function(callback_mapping, callback_object)
  add_callback(callback_mapping, callback_object, 'window/showMessage', function(self, data)
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
  end, { })
end

-- 3 window/showMessageRequest
-- TODO: Should probably find some unique way to handle requests from server -> client
local add_window_show_message_request_callback = function(callback_mapping, callback_object)
  add_callback(callback_mapping, callback_object, 'window/showMessageRequest', function(self, data)
    if data == nil or type(data) ~= 'table' then
      print(self)
      return nil
    end

    local message_type = data['type']
    local message = data['message']
    local actions = data['actions']

    print(message_type, message, actions)
  end, { })
end

local add_all_builtin_callbacks = function(callback_mapping, callback_object)
  add_nvim_error_callback(callback_mapping, callback_object)
  add_text_document_publish_diagnostics_callback(callback_mapping, callback_object)
  add_text_document_completion_callback(callback_mapping, callback_object)
  add_text_document_references_callback(callback_mapping, callback_object)
  add_text_document_rename_callback(callback_mapping, callback_object)
  add_text_document_hover_callback(callback_mapping, callback_object)
  add_text_document_definition_callback(callback_mapping, callback_object)
  add_window_show_message_callback(callback_mapping, callback_object)
  add_window_show_message_request_callback(callback_mapping, callback_object)
end

-- 2 workspace
-- 3 workspace/symbol
-- TODO: Find a server that supports this request, and also figure out workspaces :)
-- add_callback('workspace/symbol', function(self, data)
--   print(self, data)
-- end, { })

return {
  -- Adding default callback functions
  add_all_builtin_callbacks = add_all_builtin_callbacks,
  add_nvim_error_callback = add_nvim_error_callback,
  add_text_document_publish_diagnostics_callback = add_text_document_publish_diagnostics_callback,
  add_text_document_completion_callback = add_text_document_completion_callback,
  add_text_document_references_callback = add_text_document_references_callback,
  add_text_document_rename_callback = add_text_document_rename_callback,
  add_text_document_hover_callback = add_text_document_hover_callback,
  add_text_document_definition_callback = add_text_document_definition_callback,
  add_window_show_message_callback = add_window_show_message_callback,
  add_window_show_message_request_callback = add_window_show_message_request_callback,
}
