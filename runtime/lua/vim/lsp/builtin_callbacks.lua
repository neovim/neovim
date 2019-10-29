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

local split = vim.split
local function split_lines(value)
	return split(value, '\n', true)
end

-- Append all the items from `b` to `a`
local function list_extend(a, b)
	for _, v in ipairs(b) do
		table.insert(a, v)
	end
	return a
end

local function get_floating_window_option(width, height)
  local anchor = ''
  local row, col

  if vim.fn.winline() <= height then
    anchor = anchor..'N'
    row = 1
  else
    anchor = anchor..'S'
    row = 0
  end

  if vim.fn.wincol() + width <= vim.api.nvim_get_option('columns') then
		anchor = anchor..'W'
		col = 0
  else
    anchor = anchor..'E'
    col = 1
  end

  return {
    anchor = anchor,
    col = col,
    height = height,
    relative = 'cursor',
    row = row,
    style = 'minimal',
    width = width,
  }
end

local function open_floating_preview(contents, filetype)
  local width = 0
  local height = #contents

  for _, line in ipairs(contents) do
		-- TODO(ashkan) use nvim_strdisplaywidth if/when that is introduced.
    local line_width = vim.fn.strdisplaywidth(line)
		width = math.max(line_width, width)
  end
  -- Add right margin
  width = width + 1

  local floating_bufnr = vim.api.nvim_create_buf(false, true)
  if filetype then
		if not (type(filetype) == 'string') then
			error(("Invalid filetype for open_floating_preview: %q"):format(filetype))
		end
    vim.api.nvim_buf_set_var(floating_bufnr, 'filetype', filetype)
  end

  local float_option = get_floating_window_option(width, height)
  local floating_winnr = vim.api.nvim_open_win(floating_bufnr, true, float_option)

  vim.api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)

	-- TODO is this necessary?
  local floating_win = vim.fn.win_id2win(floating_winnr)

  vim.api.nvim_command("wincmd p")
	-- TODO should this have a <buffer> target?
  vim.api.nvim_command("autocmd CursorMoved <buffer> ++once :"..floating_win.."wincmd c")
end

--- Convert Hover response to preview contents.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_hover
local function hover_contents_to_markdown_lines(input, contents)
  contents = contents or {}
	-- MarkedString variation 1
	if type(input) == 'string' then
		list_extend(contents, split_lines(input))
	else
		assert(type(input) == 'table', "Expected a table for Hover.contents. Please file an issue on neovim/neovim")
		-- MarkupContent
		if input.kind then
			-- The kind can be either plaintext or markdown. However, either way we
			-- will just be rendering markdown, so we handle them both the same way.
			-- TODO these can have escaped/sanitized html codes in markdown. We
			-- should make sure we handle this correctly.
			assert(type(input.value) == 'string')
			list_extend(contents, split_lines(input.value))
		-- MarkupString variation 2
		elseif input.language then
			assert(type(input.value) == 'string')
			list_extend(contents, vim.tbl_flatten {
				"```"..input.language;
				split_lines(input.value);
				"```";
			})
		-- By deduction, this must be MarkedString[]
		else
			-- Use our existing logic to handle MarkedString
			for _, marked_string in ipairs(input) do
				hover_contents_to_markdown_lines(marked_string, contents)
			end
		end
	end
	-- TODO are we sure about this?
  if contents[1] == '' or contents[1] == nil then
    return {'LSP [textDocument/hover]: No information available'}
  end
	return contents
end

--- Convert SignatureHelp response to preview contents.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_signatureHelp
local function signature_help_to_preview_contents(input)
  local contents = {}
	local signature
	-- If the activeSignature is inside the valid range, then use it.
	if input.activeSignature and input.activeSignature < #input.signatures then
		signature = input.signatures[input.activeSignature + 1]
	else
		-- Otherwise, default to the first element
		signature = input.signatures[1]
	end
	list_extend(contents, split_lines(signature.label))
	if signature.documentation then
		hover_contents_to_markdown_lines(signature.documentation, contents)
	end
  return contents
end

-- {
--    method_name = {
--      callback = function,
--      options = table
--    }
-- }
local BUILTIN_CALLBACKS = {}

-- nvim/error_callback
BUILTIN_CALLBACKS['nvim/error_callback'] = {
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
BUILTIN_CALLBACKS['textDocument/publishDiagnostics'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/publishDiagnostics ', result, ' ', self)
    logger.debug('Not implemented textDocument/publishDiagnostics callback')
  end,
  options = {},
}

-- textDocument/completion
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
BUILTIN_CALLBACKS['textDocument/completion'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/completion ', result, ' ', self)

    if not result or vim.tbl_isempty(result) then
      return
    end

		local pos = vim.api.nvim_win_get_cursor(0)
		local row, col = pos[1], pos[2]
		local line = assert(vim.api.nvim_buf_get_lines(0, row-1, row, false)[1])
    local line_to_cursor = line:sub(col+1)

    local matches = text_document_handler.completion_list_to_complete_items(result, line_to_cursor)
    local match_result = vim.fn.matchstrpos(line_to_cursor, '\\k\\+$')
		local match_start, match_finish = match_result[2], match_result[3]

		vim.fn.complete(pos[2] + 1 - (match_finish - match_start), matches)
  end,
  options = {}
}

-- textDocument/references
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_references
BUILTIN_CALLBACKS['textDocument/references'] = {
  callback = function(self, result)
    logger.debug('callback:textDocument/references ', result, ' ', self)
    logger.debug('Not implemented textDocument/publishDiagnostics callback')
  end,
  options = {},
}

-- textDocument/rename
BUILTIN_CALLBACKS['textDocument/rename'] = {
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
BUILTIN_CALLBACKS['textDocument/hover'] = {
  callback = function(self, result)
    logger.debug('textDocument/hover ', result, ' ', self)

    if result == nil or vim.tbl_isempty(result) then
      return
    end

    if result.contents ~= nil then
			local markdown_lines = hover_contents_to_markdown_lines(result.contents)
      open_floating_preview(markdown_lines, 'markdown')
    end
  end,
  options = {}
}

-- textDocument/signatureHelp
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_signatureHelp
BUILTIN_CALLBACKS['textDocument/signatureHelp'] = {
  callback = function(self, result)
    logger.debug('textDocument/signatureHelp ', result, ' ', self)

    if result == nil or vim.tbl_isempty(result) then
      return
    end

		-- TODO show empty popup when signatures is empty?
    if #result.signatures > 0 then
			local markdown_lines = signature_help_to_preview_contents(result)
			open_floating_preview(markdown_lines, 'markdown')
    end
  end,
  options = {},
}

local location_callback_object = {
  callback = function(self, result)
    -- logger.debug('callback:textDocument/definiton ', result, ' ', self)
    if result == nil or vim.tbl_isempty(result) then
      logger.info('No declaration found')
      return nil
    end
    util.handle_location(result)
    return true
  end,
  options = {}
}

local location_callbacks = {
	-- https://microsoft.github.io/language-server-protocol/specification#textDocument_declaration
	'textDocument/declaration';
	-- https://microsoft.github.io/language-server-protocol/specification#textDocument_definition
	'textDocument/definition';
	-- https://microsoft.github.io/language-server-protocol/specification#textDocument_implementation
	'textDocument/implementation';
	-- https://microsoft.github.io/language-server-protocol/specification#textDocument_typeDefinition
	'textDocument/typeDefinition';
}

for _, location_callback in ipairs(location_callbacks) do
	BUILTIN_CALLBACKS[location_callback] = location_callback_object
end

-- window/showMessage
-- https://microsoft.github.io/language-server-protocol/specification#window_showMessage
BUILTIN_CALLBACKS['window/showMessage'] = {
  callback = function(self, result)
    logger.debug('callback:window/showMessage ', result, ' ', self)

    if not result or type(result) ~= 'table' then
			-- TODO eh?
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

return BUILTIN_CALLBACKS
