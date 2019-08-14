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
local nvim_util = require('nvim.util')
local util = require('lsp.util')
local protocol = require('lsp.protocol')
local errorCodes = protocol.errorCodes

local QuickFix = require('nvim.quickfix_list')
local LocationList = require('nvim.location_list')
local handle_completion = require('lsp.handle.completion')
local handle_workspace = require('lsp.handle.workspace')

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
BuiltinCallbacks['textDocument/publishDiagnostics']= {
  callback = function(self, data)
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
        util.get_filename(data.uri),
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
  end,
  options = { auto_list = false, use_quickfix = false, },
}

-- textDocument/completion
BuiltinCallbacks['textDocument/completion'] = {
  callback = function(self, data)
    if data == nil then
      print(self)
      return
    end

    return handle_completion.getLabels(data)
  end,
  options = {}
}

-- textDocument/references
BuiltinCallbacks['textDocument/references'] = {
  callback = function(self, data)
    local locations = data
    local loclist = {}

    for _, loc in ipairs(locations) do
      -- TODO: URL parsing here?
      local start = loc.range.start
      local line = start.line + 1
      local character = start.character + 1

      local path = nvim_util.handle_uri(loc["uri"])
      local text = util.get_line_from_path(path, line)

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
        if not nvim_util.is_loclist_open() then
          vim.api.nvim_command('lopen')
          vim.api.nvim_command('wincmd p')
        end
      else
        vim.api.nvim_command('lclose')
      end
    end

    return result
  end,
  options = { auto_location_list = true },
}

-- textDocument/rename
BuiltinCallbacks['textDocument/rename'] = {
  callback = function(self, data)
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
BuiltinCallbacks['textDocument/hover'] = {
  callback = function(self, data)
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
      if nvim_util.is_array(data.contents) == true then
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
  end,
  options = {}
}

-- textDocument/definition
BuiltinCallbacks['textDocument/definition'] = {
  callback = function(self, data)
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

    local data_file = util.get_filename(data.uri)

    if data_file ~= util.get_uri(current_file) then
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
BuiltinCallbacks['window/showMessage'] = {
  callback = function(self, data)
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
