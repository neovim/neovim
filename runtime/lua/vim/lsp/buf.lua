local validate = vim.validate
local api = vim.api
local vfn = vim.fn
local util = require 'vim.lsp.util'
local protocol = require 'vim.lsp.protocol'
local log = require 'vim.lsp.log'

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

local function request(method, params, callback)
	--	TODO(ashkan) enable this.
	--	callback = vim.lsp.default_callback[method] or callback
	validate {
		method = {method, 's'};
		callback = {callback, 'f'};
	}
	return vim.lsp.buf_request(0, method, params, function(err, _, result, client_id)
		if err then error(tostring(err)) end
		return callback(err, method, result, client_id)
	end)
end

local function focusable_preview(method, params, fn)
	if npcall(api.nvim_win_get_var, 0, method) then
		return api.nvim_command("wincmd p")
	end

	local bufnr = api.nvim_get_current_buf()
	do
		local win = find_window_by_var(method, bufnr)
		if win then
			return api.nvim_set_current_win(win)
		end
	end
	return request(method, params, function(_, _, result, _)
			-- TODO(ashkan) could show error in preview...
		local lines, filetype, opts = fn(result)
		if lines then
			local _, winnr = util.open_floating_preview(lines, filetype, opts)
			api.nvim_win_set_var(winnr, method, bufnr)
		end
	end)
end

function M.hover()
	local params = protocol.make_text_document_position_params()
	focusable_preview('textDocument/hover', params, function(result)
		if not (result and result.contents) then return end

		local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
		markdown_lines = util.trim_empty_lines(markdown_lines)
		if vim.tbl_isempty(markdown_lines) then
			return { 'No information available' }
		end
		return markdown_lines, util.try_trim_markdown_code_blocks(markdown_lines)
	end)
end

function M.peek_definition()
	local params = protocol.make_text_document_position_params()
	request('textDocument/peekDefinition', params, function(_, _, result, _)
		if not (result and result[1]) then return end
		local loc = result[1]
		local bufnr = vim.uri_to_bufnr(loc.uri) or error("couldn't find file "..tostring(loc.uri))
		local start = loc.range.start
		local finish = loc.range["end"]
		util.open_floating_peek_preview(bufnr, start, finish, { offset_x = 1 })
		local headbuf = util.open_floating_preview({"Peek:"}, nil, {
			offset_y = -(finish.line - start.line);
			width = finish.character - start.character + 2;
		})
		-- TODO(ashkan) change highlight group?
		api.nvim_buf_add_highlight(headbuf, -1, 'Keyword', 0, -1)
	end)
end


local function update_tagstack()
  local bufnr = api.nvim_get_current_buf()
  local line = vfn.line('.')
  local col = vfn.col('.')
  local tagname = vfn.expand('<cWORD>')
  local item = { bufnr = bufnr, from = { bufnr, line, col, 0 }, tagname = tagname }
  local winid = vfn.win_getid()
  local tagstack = vfn.gettagstack(winid)
  local action
  if tagstack.length == tagstack.curidx then
    action = 'r'
    tagstack.items[tagstack.curidx] = item
  elseif tagstack.length > tagstack.curidx then
    action = 'r'
    if tagstack.curidx > 1 then
      tagstack.items = table.insert(tagstack.items[tagstack.curidx - 1], item)
    else
      tagstack.items = { item }
    end
  else
    action = 'a'
    tagstack.items = { item }
  end
  tagstack.curidx = tagstack.curidx + 1
  vfn.settagstack(winid, tagstack, action)
end
local function handle_location(result)
  -- We can sometimes get a list of locations, so set the first value as the
  -- only value we want to handle
  -- TODO(ashkan) was this correct^? We could use location lists.
  if result[1] ~= nil then
    result = result[1]
  end
  if result.uri == nil then
    api.nvim_err_writeln('[LSP] Could not find a valid location')
    return
  end
  local result_file = vim.uri_to_fname(result.uri)
  local bufnr = vfn.bufadd(result_file)
  update_tagstack()
  api.nvim_set_current_buf(bufnr)
  local start = result.range.start
  api.nvim_win_set_cursor(0, {start.line + 1, start.character})
  return true
end
local function location_callback(_, method, result)
  if result == nil or vim.tbl_isempty(result) then
    local _ = log.info() and log.info(method, 'No location found')
    return nil
  end
  return handle_location(result)
end

function M.declaration()
	local params = protocol.make_text_document_position_params()
	request('textDocument/declaration', params, location_callback)
end

function M.definition()
	local params = protocol.make_text_document_position_params()
	request('textDocument/definition', params, location_callback)
end

function M.type_definition()
	local params = protocol.make_text_document_position_params()
	request('textDocument/typeDefinition', params, location_callback)
end

function M.implementation()
	local params = protocol.make_text_document_position_params()
	request('textDocument/implementation', params, location_callback)
end

function M.signature_help()
	local params = protocol.make_text_document_position_params()
	request('textDocument/signatureHelp', params, location_callback)
end

-- TODO(ashkan) ?
function M.completion(context)
	local params = protocol.make_text_document_position_params()
	params.context = context
	return request('textDocument/completion', params, function(_, _, result)
		if vim.tbl_isempty(result or {}) then return end
		local row, col = unpack(api.nvim_win_get_cursor(0))
		local line = assert(api.nvim_buf_get_lines(0, row-1, row, false)[1])
		local line_to_cursor = line:sub(col+1)

		local matches = util.text_document_completion_list_to_complete_items(result, line_to_cursor)
		vim.fn.complete(col, matches)
	end)
end

function M.range_formatting()
end

return M
