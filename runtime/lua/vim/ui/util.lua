local vim = vim
local validate = vim.validate
local api = vim.api
local list_extend = vim.list_extend

local M = {}

local default_border = {
	{ "", "NormalFloat" },
	{ "", "NormalFloat" },
	{ "", "NormalFloat" },
	{ " ", "NormalFloat" },
	{ "", "NormalFloat" },
	{ "", "NormalFloat" },
	{ "", "NormalFloat" },
	{ " ", "NormalFloat" },
}

function M.get_val_or_default(val, default)
	if val ~= nil then
		return val
	end

	return default
end

--@private
-- Check the border given by opts or the default border for the additional
-- size it adds to a float.
--@returns size of border in height and width
local function get_border_size(opts)
	local border = M.get_val_or_default(opts.border, default_border)
	local height = 0
	local width = 0

	if type(border) == "string" then
		local border_size = {
			none = { 0, 0 },
			single = { 2, 2 },
			double = { 2, 2 },
			rounded = { 2, 2 },
			solid = { 2, 2 },
			shadow = { 1, 1 },
		}
		if border_size[border] == nil then
			error(
				"floating preview border is not correct. Please refer to the docs |vim.api.nvim_open_win()|"
					.. vim.inspect(border)
			)
		end
		height, width = unpack(border_size[border])
	else
		local function border_width(id)
			if type(border[id]) == "table" then
				-- border specified as a table of <character, highlight group>
				return vim.fn.strdisplaywidth(border[id][1])
			elseif type(border[id]) == "string" then
				-- border specified as a list of border characters
				return vim.fn.strdisplaywidth(border[id])
			end
			error(
				"floating preview border is not correct. Please refer to the docs |vim.api.nvim_open_win()|"
					.. vim.inspect(border)
			)
		end
		local function border_height(id)
			if type(border[id]) == "table" then
				-- border specified as a table of <character, highlight group>
				return #border[id][1] > 0 and 1 or 0
			elseif type(border[id]) == "string" then
				-- border specified as a list of border characters
				return #border[id] > 0 and 1 or 0
			end
			error(
				"floating preview border is not correct. Please refer to the docs |vim.api.nvim_open_win()|"
					.. vim.inspect(border)
			)
		end
		height = height + border_height(2) -- top
		height = height + border_height(6) -- bottom
		width = width + border_width(4) -- right
		width = width + border_width(8) -- left
	end

	return { height = height, width = width }
end

--@private
local function split_lines(value)
	return vim.split(value, "\n", true)
end

--- Converts any of `MarkedString` | `MarkedString[]` | `MarkupContent` into
--- a list of lines containing valid markdown. Useful to populate the hover
--- window for `textDocument/hover`, for parsing the result of
--- `textDocument/signatureHelp`, and potentially others.
---
--@param input (`MarkedString` | `MarkedString[]` | `MarkupContent`)
--@param contents (table, optional, default `{}`) List of strings to extend with converted lines
--@returns {contents}, extended with lines of converted markdown.
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover
function M.convert_input_to_markdown_lines(input, contents)
	contents = contents or {}
	-- MarkedString variation 1
	if type(input) == "string" then
		list_extend(contents, split_lines(input))
	else
		assert(type(input) == "table", "Expected a table for Hover.contents")
		-- MarkupContent
		if input.kind then
			-- The kind can be either plaintext or markdown.
			-- If it's plaintext, then wrap it in a <text></text> block

			-- Some servers send input.value as empty, so let's ignore this :(
			local value = input.value or ""

			if input.kind == "plaintext" then
				-- wrap this in a <text></text> block so that stylize_markdown
				-- can properly process it as plaintext
				value = string.format("<text>\n%s\n</text>", value)
			end

			-- assert(type(value) == 'string')
			list_extend(contents, split_lines(value))
			-- MarkupString variation 2
		elseif input.language then
			-- Some servers send input.value as empty, so let's ignore this :(
			-- assert(type(input.value) == 'string')
			table.insert(contents, "```" .. input.language)
			list_extend(contents, split_lines(input.value or ""))
			table.insert(contents, "```")
			-- By deduction, this must be MarkedString[]
		else
			-- Use our existing logic to handle MarkedString
			for _, marked_string in ipairs(input) do
				M.convert_input_to_markdown_lines(marked_string, contents)
			end
		end
	end
	if (contents[1] == "" or contents[1] == nil) and #contents == 1 then
		return {}
	end
	return contents
end

--- Converts the table of conents into one which has the padding applied
---
--@param padding   table with numbers, defining the padding
--                 above/right/below/left of the popup (similar to CSS).
--                 An empty list uses a padding of 1 all around.  The
--                 padding goes around the text, inside any border.
--                 Padding uses the 'wincolor' highlight.
--                 Example: [1, 2, 1, 3] has 1 line of padding above, 2
--                 columns on the right, 1 line below and 3 columns on
--                 the left.
--@param contents  table with strings of content of each line that has to be
--                 padded
--@returns (table) content with padding
function M.apply_padding_to_content(padding, contents)
	validate({
		padding = { padding, "t" },
	})

	local pad_top, pad_right, pad_below, pad_left
	if vim.tbl_isempty(padding) then
		pad_top = 1
		pad_right = 1
		pad_below = 1
		pad_left = 1
	else
		pad_top = padding[1] or 0
		pad_right = padding[2] or 0
		pad_below = padding[3] or 0
		pad_left = padding[4] or 0
	end

	local left_padding = string.rep(" ", pad_left)
	local right_padding = string.rep(" ", pad_right)
	for index = 1, #contents do
		contents[index] = string.format("%s%s%s", left_padding, contents[index], right_padding)
	end

	for _ = 1, pad_top do
		table.insert(contents, 1, "")
	end

	for _ = 1, pad_below do
		table.insert(contents, "")
	end

	return contents
end

--- Creates a table with sensible default options for a floating window. The
--- table can be passed to |nvim_open_win()|.
---
--@param width (number) window width (in character cells)
--@param height (number) window height (in character cells)
--@param opts (table, optional)
--@returns (table) Options
function M.make_floating_popup_options(width, height, opts)
	validate({
		opts = { opts, "t", true },
	})
	opts = opts or {}
	validate({
		["opts.offset_x"] = { opts.offset_x, "n", true },
		["opts.offset_y"] = { opts.offset_y, "n", true },
	})

	local anchor = ""
	local row, col

	local lines_above = vim.fn.winline() - 1
	local lines_below = vim.fn.winheight(0) - lines_above

	if lines_above < lines_below then
		anchor = anchor .. "N"
		height = math.min(lines_below, height)
		row = 1
	else
		anchor = anchor .. "S"
		height = math.min(lines_above, height)
		row = -get_border_size(opts).height
	end

	if vim.fn.wincol() + width <= api.nvim_get_option("columns") then
		anchor = anchor .. "W"
		col = 0
	else
		anchor = anchor .. "E"
		col = 1
	end

	return {
		anchor = anchor,
		col = col + (opts.offset_x or 0),
		height = height,
		focusable = opts.focusable,
		relative = "cursor",
		row = row + (opts.offset_y or 0),
		style = "minimal",
		width = width,
		border = opts.border or default_border,
		zindex = opts.zindex or 50,
	}
end

-- Generates a table mapping markdown code block lang to vim syntax,
-- based on g:markdown_fenced_languages
-- @return a table of lang -> syntax mappings
-- @private
local function get_markdown_fences()
	local fences = {}
	for _, fence in pairs(vim.g.markdown_fenced_languages or {}) do
		local lang, syntax = fence:match("^(.*)=(.*)$")
		if lang then
			fences[lang] = syntax
		end
	end
	return fences
end

--- Converts markdown into syntax highlighted regions by stripping the code
--- blocks and converting them into highlighted code.
--- This will by default insert a blank line separator after those code block
--- regions to improve readability.
---
--- This method configures the given buffer and returns the lines to set.
---
--- If you want to open a popup with fancy markdown, use `vim.ui.popup` instead
---
---@param contents table of lines to show in window
---@param opts dictionary with optional fields
---  - height    of floating window
---  - width     of floating window
---  - wrap_at   character to wrap at for computing height
---  - max_width  maximal width of floating window
---  - max_height maximal height of floating window
---  - pad_left   number of columns to pad contents at left
---  - pad_right  number of columns to pad contents at right
---  - pad_top    number of lines to pad contents at top
---  - pad_bottom number of lines to pad contents at bottom
---  - separator insert separator after code block
---@returns width,height size of float
function M.stylize_markdown(bufnr, contents, opts)
	validate({
		contents = { contents, "t" },
		opts = { opts, "t", true },
	})
	opts = opts or {}

	-- table of fence types to {ft, begin, end}
	-- when ft is nil, we get the ft from the regex match
	local matchers = {
		block = { nil, "```+([a-zA-Z0-9_]*)", "```+" },
		pre = { "", "<pre>", "</pre>" },
		code = { "", "<code>", "</code>" },
		text = { "plaintex", "<text>", "</text>" },
	}

	local match_begin = function(line)
		for type, pattern in pairs(matchers) do
			local ret = line:match(string.format("^%%s*%s%%s*$", pattern[2]))
			if ret then
				return {
					type = type,
					ft = pattern[1] or ret,
				}
			end
		end
	end

	local match_end = function(line, match)
		local pattern = matchers[match.type]
		return line:match(string.format("^%%s*%s%%s*$", pattern[3]))
	end

	-- Clean up
	contents = vim.lsp.util._trim(contents, opts)

	local stripped = {}
	local highlights = {}
	-- keep track of lnums that contain markdown
	local markdown_lines = {}
	do
		local i = 1
		while i <= #contents do
			local line = contents[i]
			local match = match_begin(line)
			if match then
				local start = #stripped
				i = i + 1
				while i <= #contents do
					line = contents[i]
					if match_end(line, match) then
						i = i + 1
						break
					end
					table.insert(stripped, line)
					i = i + 1
				end
				table.insert(highlights, {
					ft = match.ft,
					start = start + 1,
					finish = #stripped,
				})
			else
				table.insert(stripped, line)
				markdown_lines[#stripped] = true
				i = i + 1
			end
		end
	end

	-- Compute size of float needed to show (wrapped) lines
	opts.wrap_at = opts.wrap_at or (vim.wo["wrap"] and api.nvim_win_get_width(0))
	local width, height = M._make_floating_popup_size(stripped, opts)

	local sep_line = string.rep("─", math.min(width, opts.wrap_at or width))

	for l in pairs(markdown_lines) do
		if stripped[l]:match("^---+$") then
			stripped[l] = sep_line
		end
	end

	-- Insert blank line separator after code block
	local insert_separator = opts.separator
	if insert_separator == nil then
		insert_separator = true
	end
	if insert_separator then
		local offset = 0
		for _, h in ipairs(highlights) do
			h.start = h.start + offset
			h.finish = h.finish + offset
			-- check if a seperator already exists and use that one instead of creating a new one
			if h.finish + 1 <= #stripped then
				if stripped[h.finish + 1] ~= sep_line then
					table.insert(stripped, h.finish + 1, sep_line)
					offset = offset + 1
					height = height + 1
				end
			end
		end
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, stripped)

	local idx = 1
	--@private
	-- keep track of syntaxes we already inlcuded.
	-- no need to include the same syntax more than once
	local langs = {}
	local fences = get_markdown_fences()
	local function apply_syntax_to_region(ft, start, finish)
		if ft == "" then
			vim.cmd(
				string.format(
					"syntax region markdownCode start=+\\%%%dl+ end=+\\%%%dl+ keepend extend",
					start,
					finish + 1
				)
			)
			return
		end
		ft = fences[ft] or ft
		local name = ft .. idx
		idx = idx + 1
		local lang = "@" .. ft:upper()
		if not langs[lang] then
			-- HACK: reset current_syntax, since some syntax files like markdown won't load if it is already set
			pcall(vim.api.nvim_buf_del_var, bufnr, "current_syntax")
			if not pcall(vim.cmd, string.format("syntax include %s syntax/%s.vim", lang, ft)) then
				return
			end
			langs[lang] = true
		end
		vim.cmd(
			string.format(
				"syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s keepend",
				name,
				start,
				finish + 1,
				lang
			)
		)
	end

	-- needs to run in the buffer for the regions to work
	api.nvim_buf_call(bufnr, function()
		-- we need to apply lsp_markdown regions speperately, since otherwise
		-- markdown regions can "bleed" through the other syntax regions
		-- and mess up the formatting
		local last = 1
		for _, h in ipairs(highlights) do
			if last < h.start then
				apply_syntax_to_region("ui_markdown", last, h.start - 1)
			end
			apply_syntax_to_region(h.ft, h.start, h.finish)
			last = h.finish + 1
		end
		if last <= #stripped then
			apply_syntax_to_region("ui_markdown", last, #stripped)
		end
	end)

	return stripped
end

--- Creates autocommands to close a preview window when events happen.
---
--@param events (table) list of events
--@param winnr (number) window id of preview window
--@see |autocmd-events|
function M.close_preview_autocmd(events, winnr)
	if #events > 0 then
		api.nvim_command(
			"autocmd "
				.. table.concat(events, ",")
				.. " <buffer> ++once lua pcall(vim.api.nvim_win_close, "
				.. winnr
				.. ", true)"
		)
	end
end

--@internal
--- Computes size of float needed to show contents (with optional wrapping)
---
--@param contents table of lines to show in window
--@param opts dictionary with optional fields
--             - height  of floating window
--             - width   of floating window
--             - wrap_at character to wrap at for computing height
--             - max_width  maximal width of floating window
--             - max_height maximal height of floating window
--@returns width,height size of float
function M._make_floating_popup_size(contents, opts)
	validate({
		contents = { contents, "t" },
		opts = { opts, "t", true },
	})
	opts = opts or {}

	local width = opts.width
	local height = opts.height
	local wrap_at = opts.wrap_at
	local max_width = opts.max_width
	local max_height = opts.max_height
	local line_widths = {}

	if not width then
		width = 0
		for i, line in ipairs(contents) do
			-- TODO(ashkan) use nvim_strdisplaywidth if/when that is introduced.
			line_widths[i] = vim.fn.strdisplaywidth(line)
			width = math.max(line_widths[i], width)
		end
	end

	local border_width = get_border_size(opts).width
	local screen_width = api.nvim_win_get_width(0)
	width = math.min(width, screen_width)

	-- make sure borders are always inside the screen
	if width + border_width > screen_width then
		width = width - (width + border_width - screen_width)
	end

	if wrap_at and wrap_at > width then
		wrap_at = width
	end

	if max_width then
		width = math.min(width, max_width)
		wrap_at = math.min(wrap_at or max_width, max_width)
	end

	if not height then
		height = #contents
		if wrap_at and width >= wrap_at then
			height = 0
			if vim.tbl_isempty(line_widths) then
				for _, line in ipairs(contents) do
					local line_width = vim.fn.strdisplaywidth(line)
					height = height + math.ceil(line_width / wrap_at)
				end
			else
				for i = 1, #contents do
					height = height + math.max(1, math.ceil(line_widths[i] / wrap_at))
				end
			end
		end
	end
	if max_height then
		height = math.min(height, max_height)
	end

	return width, height
end

return M
-- vim:sw=2 ts=2 et
