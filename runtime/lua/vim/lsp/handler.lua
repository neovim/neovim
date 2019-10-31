local COMPLETION_ITEM_KIND = require('vim.lsp.protocol').CompletionItemKind

local split = vim.split
local function split_lines(value)
	return split(value, '\n', true)
end

local TextDocument = {}

--- Apply the TextEdit response.
-- @params TextEdit [table] see https://microsoft.github.io/language-server-protocol/specification
local function apply_text_edit(text_edit)
  local range = text_edit.range
	local start = range.start
	local finish = range['end']
	local new_lines = split_lines(text_edit.newText)
	if start.character == 0 and finish.character == 0 then
		vim.api.nvim_buf_set_lines(0, start.line, finish.line, false, new_lines)
		return
	end
	vim.api.nvim_err_writeln('apply_TextEdit currently only supports character ranges starting at 0')
	return
	-- 	TODO test and finish this.
-- 	local lines = vim.api.nvim_buf_get_lines(0, start.line, finish.line + 1, false)
-- 	local suffix = lines[#lines]:sub(finish.character+2)
-- 	local prefix = lines[1]:sub(start.character+2)
-- 	new_lines[#new_lines] = new_lines[#new_lines]..suffix
-- 	new_lines[1] = prefix..new_lines[1]
-- 	vim.api.nvim_buf_set_lines(0, start.line, finish.line, false, new_lines)
end

--- Apply the TextDocumentEdit response.
-- @params TextDocumentEdit [table] see https://microsoft.github.io/language-server-protocol/specification
function TextDocument.apply_TextDocumentEdit(text_document_edit)
  local text_document = text_document_edit.textDocument
	local text_document_version = text_document.version
	-- TODO use text_document_version

	-- TODO technically, you could do this without doing multiple buf_get/set
	-- by getting the full region (smallest line and largest line) and doing
	-- the edits on the buffer, and then applying the buffer at the end.
	-- I'm not sure if that's better.
  for _, text_edit in ipairs(text_document_edit.edits) do
    apply_text_edit(text_edit)
  end
end

-- TODO see if we can improve this algorithm.
local function remove_prefix(prefix, word)
	local max_prefix_length = math.min(#prefix, #word)
	local prefix_length = 0
	for i = 1, max_prefix_length do
		local current_line_suffix = prefix:sub(-i)
		local word_prefix = word:sub(1, i)
		if current_line_suffix == word_prefix then
			prefix_length = i
		end
	end
	return word:sub(prefix_length + 1)
end

-- textDocument/completion response returns one of CompletionItem[], CompletionList or null.
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
local function extract_completion_items(result)
  if type(result) == 'table' and result.items then
		return result.items
  elseif result ~= nil then
    return result
  else
    return {}
  end
end

local function get_current_line_to_cursor()
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = assert(vim.api.nvim_buf_get_lines(0, pos[1]-1, pos[1], false)[1])
	return line:sub(pos[2]+1)
end

--- Getting vim complete-items with incomplete flag.
-- @params CompletionItem[], CompletionList or nil (https://microsoft.github.io/language-server-protocol/specification#textDocument_completion)
-- @return { matches = complete-items table, incomplete = boolean  }
function TextDocument.completion_list_to_complete_items(result, line_prefix)
  local items = extract_completion_items(result)
	if vim.tbl_isempty(items) then
		return {}
	end
	-- Only initialize if we have some items.
	if not line_prefix then
		line_prefix = get_current_line_to_cursor()
	end

  local matches = {}

  for _, completion_item in ipairs(items) do
    local info = ' '
    local documentation = completion_item.documentation
    if documentation then
      if type(documentation) == 'string' and documentation ~= '' then
        info = documentation
      elseif type(documentation) == 'table' and type(documentation.value) == 'string' then
        info = documentation.value
			else
				-- TODO(ashkan) Validation handling here?
      end
    end

    local word = completion_item.insertText or completion_item.label

		-- Ref: `:h complete-items`
    table.insert(matches, {
      word = remove_prefix(line_prefix, word),
      abbr = completion_item.label,
      kind = COMPLETION_ITEM_KIND[completion_item.kind] or '',
      menu = completion_item.detail or '',
      info = info,
      icase = 1,
      dup = 0,
      empty = 1,
    })
  end

  return matches
end

local Workspace = {}

-- @params WorkspaceEdit [table] see https://microsoft.github.io/language-server-protocol/specification
function Workspace.apply_WorkspaceEdit(WorkspaceEdit)
  if WorkspaceEdit.documentChanges ~= nil then
    for _, textDocumentEdit in ipairs(WorkspaceEdit.documentChanges) do
      TextDocument.apply_TextDocumentEdit(textDocumentEdit)
    end
    return
  end

  -- TODO: handle (deprecated) changes
  local changes = WorkspaceEdit.changes

  if changes == nil or #changes == 0 then
    return
  end

end

return {
	workspace = Workspace;
	text_document = TextDocument;
}
