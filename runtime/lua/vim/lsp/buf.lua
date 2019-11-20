local validate = vim.validate
local api = vim.api
local util = require 'vim.lsp.util'
local protocol = require 'vim.lsp.protocol'

local M = {}

local function resolve_bufnr(bufnr)
  validate { bufnr = { bufnr, 'n', true } }
  if bufnr == nil or bufnr == 0 then
    return api.nvim_get_current_buf()
  end
  return bufnr
end

local function ok_or_nil(status, ...)
	if not status then return end
	return ...
end
local function npcall(fn, ...)
	return ok_or_nil(pcall(fn, ...))
end

local function find_window_by_var(name, value)
	for _, win in ipairs(api.nvim_list_wins()) do
		if npcall(api.nvim_win_get_var, win, name) == value then
			return win
		end
	end
end

local hover_window_tag = 'lsp_hover'
function M.hover(bufnr)
	if npcall(api.nvim_win_get_var, 0, hover_window_tag) then
		api.nvim_command("wincmd p")
		return
	end

	bufnr = resolve_bufnr(bufnr)
	do
		local win = find_window_by_var(hover_window_tag, bufnr)
		if win then
			api.nvim_set_current_win(win)
			return
		end
	end
	local params = protocol.make_text_document_position_params()
	vim.lsp.buf_request(bufnr, 'textDocument/hover', params, function(_, _, result, _)
		if result == nil or vim.tbl_isempty(result) then
			return
		end

		if result.contents ~= nil then
			local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
			markdown_lines = util.trim_empty_lines(markdown_lines)
			if vim.tbl_isempty(markdown_lines) then
				markdown_lines = { 'No information available' }
			end
			local filetype = util.try_trim_markdown_code_blocks(markdown_lines)
			local _, winnr = util.open_floating_preview(markdown_lines, filetype)
			api.nvim_win_set_var(winnr, hover_window_tag, bufnr)
		end
	end)
end

function M.signature_help()
end

function M.declaration()
end

function M.type_definition()
end

function M.implementation()
end

-- TODO(ashkan) ?
function M.completion()
end

function M.range_formatting()
end

return M
